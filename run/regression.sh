#!/usr/bin/env bash
# =============================================================================
#  PCIe UVM Regression Script
#  Usage: ./regression.sh [--jobs N] [--test TESTNAME] [--dry-run]
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Tunables
# ─────────────────────────────────────────────────────────────────────────────
JOBS=4                          # parallel simulation slots
TEST="pcie_top_test_base"       # UVM test name
VERBOSITY="UVM_MEDIUM"
SEED=1
DRY_RUN=0
MAKE="make"

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────
INSPECT_RUN=""   # run name to inspect with --fail

while [[ $# -gt 0 ]]; do
  case $1 in
    --jobs)    JOBS="$2";       shift 2 ;;
    --test)    TEST="$2";       shift 2 ;;
    --seed)    SEED="$2";       shift 2 ;;
    --dry-run) DRY_RUN=1;       shift   ;;
    --fail)    INSPECT_RUN="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────────────
# --fail mode: inspect a specific run's log and print error lines
# ─────────────────────────────────────────────────────────────────────────────
if [[ -n "$INSPECT_RUN" ]]; then
  log="./runs/${INSPECT_RUN}/simv.log"
  echo ""
  echo -e "\033[1mInspecting log: ${log}\033[0m"
  echo ""
  if [[ ! -f "$log" ]]; then
    echo "ERROR: log not found — check run name."
    echo "Available runs:"
    ls -1 ./runs/ 2>/dev/null || echo "  (no runs directory found)"
    exit 1
  fi
  echo "--- UVM summary ---"
  grep -iE 'UVM_(ERROR|FATAL|WARNING)\s*:' "$log" || echo "  (no UVM summary lines found)"
  echo ""
  echo "--- Error / Fatal lines ---"
  grep -niE 'UVM_ERROR|UVM_FATAL' "$log" | grep -v ':\s*0$' || echo "  (none)"
  echo ""
  echo "--- Simulator fatal errors (Error-[...]) ---"
  grep -nE 'Error-\[' "$log" || echo "  (none)"
  echo ""
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Mode definitions
# ─────────────────────────────────────────────────────────────────────────────
VIP_MODES=(
  "feature_cap_off"
  "feature_disabled"
  "no_support_scale_fc"
  "P_infinite_credits"
  "NP_infinite_credits"
  "CPL_infinite_credits"
)

ERR_MODES=(
  "crc_err"
  "dllp_type_err"
  "feature_ack_bit_err"
  "feature_err"
  "updatefc_scale_err"
  "dropped_fc_err"
  "out_of_order_fc_err"
)

# ─────────────────────────────────────────────────────────────────────────────
# Build the test matrix
# Strategy  (49 runs)
#
#   DEFAULT = "default"  (Makefile default — no special VIP mode)
#
#   1. Each VIP on U-side, DEFAULT on D                    (6 runs)
#   2. Each VIP on D-side, DEFAULT on U                    (6 runs)
#   3. DEFAULT / DEFAULT clean run                         (1 run)
#   4. VIP diagonal — each VIP paired with the next VIP   (6 runs)
#   5. VIP cross    — first 3 VIPs vs last 3 VIPs, both   (12 runs)
#      directions, no error injection
#   6. Error tests  — each of 7 err modes once on U-side  (14 runs)
#      (with a rotating VIP) and once on D-side
#      (with a different rotating VIP), DEFAULT on other side
#
#   Baseline total = 6+6+1+6+12 = 31 ... dedup gives 35
#   Error total    = 14
#   Grand total    = 49
# ─────────────────────────────────────────────────────────────────────────────
DEFAULT_VIP="default"

declare -a RUN_KEYS=()      # "u_vip|d_vip|u_err|d_err"

# Helper: add entry (deduplicates)
add_run() {
  local key="${1}|${2}|${3}|${4}"
  for k in "${RUN_KEYS[@]+"${RUN_KEYS[@]}"}"; do
    [[ "$k" == "$key" ]] && return
  done
  RUN_KEYS+=("$key")
}

# 1. Each VIP on U-side, DEFAULT on D
for vip in "${VIP_MODES[@]}"; do
  add_run "$vip" "$DEFAULT_VIP" "" ""
done

# 2. Each VIP on D-side, DEFAULT on U
for vip in "${VIP_MODES[@]}"; do
  add_run "$DEFAULT_VIP" "$vip" "" ""
done

# 3. Clean DEFAULT/DEFAULT baseline
add_run "$DEFAULT_VIP" "$DEFAULT_VIP" "" ""

# 4. VIP diagonal — each VIP paired with the next (wraps around)
NUM_VIP=${#VIP_MODES[@]}
for (( i=0; i<NUM_VIP; i++ )); do
  u="${VIP_MODES[$i]}"
  d="${VIP_MODES[$(( (i+1) % NUM_VIP ))]}"
  add_run "$u" "$d" "" ""
done

# 5. VIP cross — first half of VIP list vs second half, both directions
HALF=$(( NUM_VIP / 2 ))
for (( i=0; i<HALF; i++ )); do
  for (( j=HALF; j<NUM_VIP; j++ )); do
    add_run "${VIP_MODES[$i]}" "${VIP_MODES[$j]}" "" ""
    add_run "${VIP_MODES[$j]}" "${VIP_MODES[$i]}" "" ""
  done
done

# 6. Error tests — each err mode once on U-side and once on D-side,
#                  always with DEFAULT on both VIP sides
for err in "${ERR_MODES[@]}"; do
  add_run "$DEFAULT_VIP" "$DEFAULT_VIP" "$err" ""
  add_run "$DEFAULT_VIP" "$DEFAULT_VIP" ""     "$err"
done

TOTAL=${#RUN_KEYS[@]}

# ─────────────────────────────────────────────────────────────────────────────
# Colours & formatting
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

banner() { echo -e "${CYAN}${BOLD}$*${RESET}"; }
pass()   { echo -e "  ${GREEN}[PASS]${RESET} $*"; }
fail()   { echo -e "  ${RED}[FAIL]${RESET} $*"; }
xfail()  { echo -e "  ${YELLOW}[FAIL-EXPECTED]${RESET} $*"; }

# ─────────────────────────────────────────────────────────────────────────────
# Result tracking
# ─────────────────────────────────────────────────────────────────────────────
declare -a RESULTS=()          # "<label>|<status>"  status: PASS|FAIL|XFAIL|ERROR

record() { RESULTS+=("$1|$2"); }

# ─────────────────────────────────────────────────────────────────────────────
# Error mode behaviour lists
#
# All error modes are expected to produce UVM errors (XFAIL when errors found).
# PASS_ERR_MODES is intentionally empty — dllp_type_err is NOT a special case.
# ─────────────────────────────────────────────────────────────────────────────
PASS_ERR_MODES=()

# Returns 0 if the run is expected to produce UVM errors, 1 if expected clean
expects_error() {
  local u_err="$1" d_err="$2"
  # No error mode injected → expect clean
  [[ -z "$u_err" && -z "$d_err" ]] && return 1
  # Check if every injected mode is in the always-pass list
  for mode in "$u_err" "$d_err"; do
    [[ -z "$mode" ]] && continue
    local is_pass_mode=0
    for pass_mode in "${PASS_ERR_MODES[@]+"${PASS_ERR_MODES[@]}"}"; do
      [[ "$mode" == "$pass_mode" ]] && is_pass_mode=1 && break
    done
    [[ "$is_pass_mode" -eq 0 ]] && return 0   # at least one error-producing mode
  done
  return 1   # all injected modes are pass-through → expect clean
}

# Returns 0 if this run intentionally injects a pass-through error mode
expects_pass_with_err() {
  local u_err="$1" d_err="$2"
  [[ -z "$u_err" && -z "$d_err" ]] && return 1
  for mode in "$u_err" "$d_err"; do
    [[ -z "$mode" ]] && continue
    for pass_mode in "${PASS_ERR_MODES[@]+"${PASS_ERR_MODES[@]}"}"; do
      [[ "$mode" == "$pass_mode" ]] && return 0
    done
  done
  return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Parse a simulation log for UVM errors / fatal messages
# Returns 0 if errors found, 1 if clean
#
# Also detects simulator-level crashes (e.g. FCIBH illegal bin hit) that abort
# the sim before the UVM summary is ever written.
# ─────────────────────────────────────────────────────────────────────────────
log_has_errors() {
  local log="$1"
  if [[ ! -f "$log" ]]; then
    echo "  WARNING: log not found: $log" >&2
    return 0   # no log = something went wrong = treat as error
  fi

  # Detect simulator abort before UVM summary is written.
  # Anchored to line-start to avoid matching mid-line DUT/testbench prints.
  # Covers both "Error-[...]" (e.g. FCIBH) and "Fatal-[...]" simulator messages.
  if grep -qE '^(Error|Fatal)-\[' "$log"; then
    return 0   # treat as error — sim crashed before UVM summary
  fi

  # Check UVM_ERROR / UVM_FATAL counts — match "UVM_ERROR : <N>" where N > 0
  local err_count fatal_count
  err_count=$(grep -iE 'UVM_ERROR\s*:\s*[0-9]+' "$log"   | grep -oE '[0-9]+$' | awk '{s+=$1} END{print s+0}')
  fatal_count=$(grep -iE 'UVM_FATAL\s*:\s*[0-9]+' "$log" | grep -oE '[0-9]+$' | awk '{s+=$1} END{print s+0}')

  [[ "$err_count" -gt 0 || "$fatal_count" -gt 0 ]] && return 0
  return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Run a single simulation (called in subshell for parallelism)
# Writes result to a temp file: <tmpdir>/<idx>
# ─────────────────────────────────────────────────────────────────────────────
TMPDIR_REG=$(mktemp -d /tmp/pcie_reg_XXXXXX)
trap 'rm -rf "$TMPDIR_REG"' EXIT

run_one() {
  local idx="$1" u_vip="$2" d_vip="$3" u_err="$4" d_err="$5"

  local label="${u_vip}__${d_vip}"
  [[ -n "$u_err" ]] && label+="__uerr_${u_err}"
  [[ -n "$d_err" ]] && label+="__derr_${d_err}"

  local make_args=(
    "test=${TEST}"
    "verbosity=${VERBOSITY}"
    "seed=${SEED}"
    "u_vip_mode=${u_vip}"
    "d_vip_mode=${d_vip}"
    "u_err_mode=${u_err}"
    "d_err_mode=${d_err}"
  )

  local expected_err
  expects_error "$u_err" "$d_err" && expected_err=1 || expected_err=0

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "${label}|DRY" > "${TMPDIR_REG}/${idx}"
    return
  fi

  # Run simulation (compile already done)
  local run_ok
  if $MAKE run "${make_args[@]}" >/dev/null 2>&1; then
    run_ok=1
  else
    run_ok=0
  fi

  # Determine log path — must exactly mirror Makefile RUN_NAME logic:
  #   RUN_NAME_BASE = $(u_vip_mode)_u_$(d_vip_mode)_d
  #   optionally appended: _$(u_err_mode)_u  and/or  _$(d_err_mode)_d
  local run_name="${u_vip}_u_${d_vip}_d"
  [[ -n "$u_err" ]] && run_name+="_${u_err}_u"
  [[ -n "$d_err" ]] && run_name+="_${d_err}_d"
  local log="./runs/${run_name}/simv.log"
  echo "  [DBG] expecting log at: $log" >&2

  local status
  if [[ "$run_ok" -eq 0 ]]; then
    # make run itself failed — check log for extra context but always fail
    # unless it was an expected-error run and the log confirms UVM errors
    if log_has_errors "$log" && [[ "$expected_err" -eq 1 ]]; then
      status="XFAIL"
    else
      status="FAIL"   # sim didn't exit cleanly → real failure regardless of log
    fi
  elif log_has_errors "$log"; then
    # make run exited cleanly but log contains errors
    if [[ "$expected_err" -eq 1 ]]; then
      status="XFAIL"
    else
      status="FAIL"
    fi
  else
    # make run exited cleanly and log is clean
    if [[ "$expected_err" -eq 1 ]]; then
      status="PASS_UNEXP"   # error injected but no errors seen → unexpected
    else
      status="PASS"
    fi
  fi

  echo "${label}|${status}" > "${TMPDIR_REG}/${idx}"
}

export -f run_one log_has_errors expects_error expects_pass_with_err
export PASS_ERR_MODES
export MAKE TEST VERBOSITY SEED DRY_RUN TMPDIR_REG

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

echo ""
banner "======================================================================="
banner "  PCIe UVM Regression  —  $(date '+%Y-%m-%d %H:%M:%S')"
banner "======================================================================="
echo -e "  Test     : ${BOLD}${TEST}${RESET}"
echo -e "  Seed     : ${SEED}"
echo -e "  Jobs     : ${JOBS} parallel"
echo -e "  Total    : ${TOTAL} runs"
[[ "$DRY_RUN" -eq 1 ]] && echo -e "  ${YELLOW}DRY RUN — no simulations will be launched${RESET}"
echo ""

# ── Step 1: Compile once ──────────────────────────────────────────────────────
banner "[ 1/3 ]  Compiling..."
if [[ "$DRY_RUN" -eq 0 ]]; then
  if ! $MAKE compile; then
    echo -e "${RED}${BOLD}COMPILATION FAILED — aborting regression.${RESET}"
    exit 1
  fi
  echo -e "  ${GREEN}Compilation successful.${RESET}"
else
  echo -e "  ${YELLOW}(skipped — dry run)${RESET}"
fi
echo ""

# ── Step 2: Run simulations in parallel ──────────────────────────────────────
banner "[ 2/3 ]  Running simulations..."
echo ""

# Use a simple semaphore via background jobs + wait
active=0
idx=0
for key in "${RUN_KEYS[@]}"; do
  IFS='|' read -r u_vip d_vip u_err d_err <<< "$key"
  idx=$((idx + 1))

  # Progress indicator
  printf "  [%3d/%3d]  %-80s\r" "$idx" "$TOTAL" \
    "${u_vip} / ${d_vip}${u_err:+ uerr=$u_err}${d_err:+ derr=$d_err}"

  run_one "$idx" "$u_vip" "$d_vip" "$u_err" "$d_err" &
  active=$((active + 1))

  if [[ "$active" -ge "$JOBS" ]]; then
    wait -n 2>/dev/null || wait   # wait for any one child to finish
    active=$((active - 1))
  fi
done
wait   # drain remaining jobs
printf '%100s\r' ''   # clear progress line

echo -e "  All simulations complete."
echo ""

# ── Step 3: Collect results ───────────────────────────────────────────────────
banner "[ 3/3 ]  Collecting results & merging coverage..."
echo ""

PASS_COUNT=0; FAIL_COUNT=0; XFAIL_COUNT=0; ERR_COUNT=0

# Read result files in order
for ((i=1; i<=idx; i++)); do
  result_file="${TMPDIR_REG}/${i}"
  if [[ -f "$result_file" ]]; then
    IFS='|' read -r label status < "$result_file"
    record "$label" "$status"
  else
    record "run_${i}" "ERROR"
  fi
done

# ── Merge coverage ────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" -eq 0 ]]; then
  if $MAKE merge_coverage >/dev/null 2>&1; then
    echo -e "  ${GREEN}Coverage merged successfully.${RESET}"
  else
    echo -e "  ${YELLOW}Warning: coverage merge failed (check runs/ directory).${RESET}"
  fi
else
  echo -e "  ${YELLOW}(coverage merge skipped — dry run)${RESET}"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Final report
# ─────────────────────────────────────────────────────────────────────────────
banner "======================================================================="
banner "  REGRESSION REPORT  —  $(date '+%Y-%m-%d %H:%M:%S')"
banner "======================================================================="
echo ""
printf "  %-90s  %s\n" "RUN NAME" "RESULT"
printf "  %-90s  %s\n" "$(printf '%0.s─' {1..90})" "────────────────"

PASS_UNEXP_COUNT=0

for entry in "${RESULTS[@]}"; do
  IFS='|' read -r label status <<< "$entry"
  case "$status" in
    PASS)        pass  "$(printf '%-90s' "$label")  PASSED"
                 PASS_COUNT=$((PASS_COUNT+1)) ;;
    XFAIL)       xfail "$(printf '%-90s' "$label")  FAILED (expected)"
                 XFAIL_COUNT=$((XFAIL_COUNT+1)) ;;
    FAIL)        fail  "$(printf '%-90s' "$label")  FAILED ← UNEXPECTED"
                 FAIL_COUNT=$((FAIL_COUNT+1)) ;;
    PASS_UNEXP)  echo -e "  ${YELLOW}[PASS-UNEXP]${RESET} $(printf '%-90s' "$label")  PASSED UNEXPECTEDLY (error injected but no UVM errors found)"
                 PASS_UNEXP_COUNT=$((PASS_UNEXP_COUNT+1)) ;;
    DRY)         echo -e "  ${CYAN}[DRY-RUN]${RESET}  $label" ;;
    *)           echo -e "  ${RED}[ERROR]${RESET}    $label  (could not determine result)"
                 ERR_COUNT=$((ERR_COUNT+1)) ;;
  esac
done

echo ""
banner "======================================================================="
echo -e "  ${GREEN}${BOLD}PASSED              : ${PASS_COUNT}${RESET}"
echo -e "  ${YELLOW}${BOLD}FAIL-EXPECTED       : ${XFAIL_COUNT}${RESET}  (error injected → error detected, as designed)"
echo -e "  ${YELLOW}${BOLD}PASSED-UNEXPECTEDLY : ${PASS_UNEXP_COUNT}${RESET}  (error injected but simulation showed no UVM errors)"
echo -e "  ${RED}${BOLD}FAILED              : ${FAIL_COUNT}${RESET}  (unexpected failures — no error injected but UVM errors found)"
[[ "$ERR_COUNT" -gt 0 ]] && \
  echo -e "  ${RED}${BOLD}ERRORS              : ${ERR_COUNT}${RESET}  (could not parse results)"
echo -e "  ${BOLD}TOTAL               : ${TOTAL}${RESET}"
banner "======================================================================="
echo ""

if [[ "$FAIL_COUNT" -gt 0 || "$ERR_COUNT" -gt 0 ]]; then
  echo -e "${RED}${BOLD}  ✗  Regression FAILED — see FAILED entries above.${RESET}"
  echo ""
  exit 1
else
  echo -e "${GREEN}${BOLD}  ✔  Regression PASSED — all unexpected results: 0.${RESET}"
  echo ""
  exit 0
fi