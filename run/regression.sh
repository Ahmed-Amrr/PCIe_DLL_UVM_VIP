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
while [[ $# -gt 0 ]]; do
  case $1 in
    --jobs)    JOBS="$2";    shift 2 ;;
    --test)    TEST="$2";    shift 2 ;;
    --seed)    SEED="$2";    shift 2 ;;
    --dry-run) DRY_RUN=1;    shift   ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

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
# Strategy  (~47 runs)
#
#   DEFAULT = "default"  (Makefile default — no special VIP mode)
#
#   1. Baseline VIP sweep (12 runs)
#      Each VIP mode once on U-side paired with DEFAULT on D, and vice versa.
#      Covers every VIP mode in both positions without the full 6x6 grid.
#
#   2. U-side error sweep (7 runs)
#      Each error mode once: u_err=<mode>, d stays DEFAULT, both VIP DEFAULT.
#
#   3. D-side error sweep (7 runs)
#      Each error mode once: d_err=<mode>, u stays DEFAULT, both VIP DEFAULT.
#
#   4. Error x VIP cross (14 runs)
#      Each error mode paired with feature_cap_off VIP on the same side,
#      DEFAULT on the other — exercises the interaction without explosion.
#        U-side: u_err + u_vip=feature_cap_off, d=DEFAULT  (7 runs)
#        D-side: d_err + d_vip=feature_cap_off, u=DEFAULT  (7 runs)
#
#   5. Both-sides stress (7 runs)
#      Same error on both sides, both VIP DEFAULT.
#
#   Total = 12 + 7 + 7 + 14 + 7 = 47 runs
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

# 1. Baseline VIP sweep — each VIP mode once on each side, other side = default
for vip in "${VIP_MODES[@]}"; do
  add_run "$vip"          "$DEFAULT_VIP" "" ""
  add_run "$DEFAULT_VIP"  "$vip"         "" ""
done

# 2. U-side error sweep — each error mode once, both VIP default
for err in "${ERR_MODES[@]}"; do
  add_run "$DEFAULT_VIP" "$DEFAULT_VIP" "$err" ""
done

# 3. D-side error sweep — each error mode once, both VIP default
for err in "${ERR_MODES[@]}"; do
  add_run "$DEFAULT_VIP" "$DEFAULT_VIP" "" "$err"
done

# 4. Error x VIP cross — each error mode with feature_cap_off VIP on same side
for err in "${ERR_MODES[@]}"; do
  add_run "feature_cap_off" "$DEFAULT_VIP" "$err" ""
  add_run "$DEFAULT_VIP" "feature_cap_off" "" "$err"
done

# 5. Both-sides stress — same error injected on both sides
for err in "${ERR_MODES[@]}"; do
  add_run "$DEFAULT_VIP" "$DEFAULT_VIP" "$err" "$err"
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
# Determine if a run is expected to have errors
# ─────────────────────────────────────────────────────────────────────────────
expects_error() {
  local u_err="$1" d_err="$2"
  [[ -n "$u_err" || -n "$d_err" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Parse a simulation log for UVM errors / fatal messages
# Returns 0 if errors found, 1 if clean
# ─────────────────────────────────────────────────────────────────────────────
log_has_errors() {
  local log="$1"
  [[ ! -f "$log" ]] && return 0          # missing log = failure
  grep -qiE 'UVM_ERROR|UVM_FATAL|\bFAILED\b' "$log" && return 0
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
  if $MAKE run "${make_args[@]}" >/dev/null 2>&1; then
    run_ok=1
  else
    run_ok=0
  fi

  # Determine log path (mirrors Makefile logic)
  local run_name="${u_vip}_u_${d_vip}_d"
  [[ -n "$u_err" ]] && run_name+="_${u_err}_u"
  [[ -n "$d_err" ]] && run_name+="_${d_err}_d"
  local log="./runs/${run_name}/simv.log"

  local status
  if log_has_errors "$log"; then
    # Errors found in log
    if [[ "$expected_err" -eq 1 ]]; then
      status="XFAIL"   # errors expected and present → expected failure
    else
      status="FAIL"    # errors NOT expected but present → real failure
    fi
  else
    # No errors in log
    if [[ "$expected_err" -eq 1 ]]; then
      status="FAIL"    # errors expected but NOT present → suspicious
    else
      status="PASS"
    fi
  fi

  echo "${label}|${status}" > "${TMPDIR_REG}/${idx}"
}

export -f run_one log_has_errors expects_error
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

for entry in "${RESULTS[@]}"; do
  IFS='|' read -r label status <<< "$entry"
  case "$status" in
    PASS)   pass  "$(printf '%-90s' "$label")  PASSED"
            PASS_COUNT=$((PASS_COUNT+1)) ;;
    XFAIL)  xfail "$(printf '%-90s' "$label")  FAILED (expected)"
            XFAIL_COUNT=$((XFAIL_COUNT+1)) ;;
    FAIL)   fail  "$(printf '%-90s' "$label")  FAILED ← UNEXPECTED"
            FAIL_COUNT=$((FAIL_COUNT+1)) ;;
    DRY)    echo -e "  ${CYAN}[DRY-RUN]${RESET}  $label"
            ;;
    *)      echo -e "  ${RED}[ERROR]${RESET}    $label  (could not determine result)"
            ERR_COUNT=$((ERR_COUNT+1)) ;;
  esac
done

echo ""
banner "======================================================================="
echo -e "  ${GREEN}${BOLD}PASSED         : ${PASS_COUNT}${RESET}"
echo -e "  ${YELLOW}${BOLD}FAIL-EXPECTED  : ${XFAIL_COUNT}${RESET}  (error injected → error detected, as designed)"
echo -e "  ${RED}${BOLD}FAILED         : ${FAIL_COUNT}${RESET}  (unexpected failures)"
[[ "$ERR_COUNT" -gt 0 ]] && \
  echo -e "  ${RED}${BOLD}ERRORS         : ${ERR_COUNT}${RESET}  (could not parse results)"
echo -e "  ${BOLD}TOTAL          : ${TOTAL}${RESET}"
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