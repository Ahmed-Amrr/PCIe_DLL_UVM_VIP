#!/usr/bin/env bash
# =============================================================================
#  PCIe UVM Regression Script
#  Usage: ./regression.sh [--jobs N] [--test TESTNAME] [--seed N]
#                         [--grace N] [--no-flit] [--dry-run]
#                         [--fail <run_name>]
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Tunables
# ─────────────────────────────────────────────────────────────────────────────
JOBS=4
TEST="pcie_top_test_base"
VERBOSITY="UVM_MEDIUM"
SEED=1
DRY_RUN=0
MAKE="make"
CB_GRACE_NS=500       # ns added after last deregister timestamp
RUN_FLIT=1            # 1 = flit + non-flit  |  0 = non-flit only

# ─────────────────────────────────────────────────────────────────────────────
# Error-mode behaviour tables
#
#  NO_DEREG_ERR_MODES — no deregister marker printed; cb_end = 2 * cb_start
#  ECC_MODES          — flit-only; errors correctable; own Group C section
# ─────────────────────────────────────────────────────────────────────────────
NO_DEREG_ERR_MODES=("out_of_order_fc_err" "dropped_fc_err")
ECC_MODES=("flit_ecc_cb")

# ─────────────────────────────────────────────────────────────────────────────
# Detection patterns
#
# ERR_MSG_PAT   — UVM_ERROR/FATAL message lines (have file path + timestamp)
#                 e.g.  UVM_ERROR ./../foo.sv(282) @ 101250: reporter ...
#                 NOT   UVM_ERROR :    3            (summary line, no path)
#
# ILLEGAL_BIN_PAT — VCS functional-coverage illegal bin hit header
#                   e.g.  Error-[FCIBH] Illegal bin hit
# ─────────────────────────────────────────────────────────────────────────────
ERR_MSG_PAT='UVM_(ERROR|FATAL)[[:space:]]+[^[:space:]:]+\([0-9]+\)[[:space:]]*@'
ILLEGAL_BIN_PAT='Error-\[FCIBH\]'
# Scoreboard final verdict line — excluded from error counting in injection
# runs because it fires at end-of-sim (always outside callback window)
SB_VERDICT_PAT='\[DLL_SB\].*DLL TEST FAILED'

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────
INSPECT_RUN=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --jobs)    JOBS="$2";        shift 2 ;;
    --test)    TEST="$2";        shift 2 ;;
    --seed)    SEED="$2";        shift 2 ;;
    --dry-run) DRY_RUN=1;        shift   ;;
    --fail)    INSPECT_RUN="$2"; shift 2 ;;
    --grace)   CB_GRACE_NS="$2"; shift 2 ;;
    --no-flit) RUN_FLIT=0;       shift   ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────────────
# --fail mode: inspect a specific run's log
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
  echo "--- UVM summary lines ---"
  grep -iE 'UVM_(ERROR|FATAL|WARNING)\s*:\s*[0-9]' "$log" || echo "  (none)"
  echo ""
  echo "--- UVM error/fatal message lines ---"
  grep -E "$ERR_MSG_PAT" "$log" || echo "  (none)"
  echo ""
  echo "--- Illegal bin errors ---"
  grep -A5 -E "$ILLEGAL_BIN_PAT" "$log" || echo "  (none)"
  echo ""
  echo "--- Callback window markers ---"
  grep -E '\[TEST_CB\]' "$log" || echo "  (no TEST_CB markers found)"
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

# Flit-only error modes — only ever run with flit=1
FLIT_ONLY_ERR_MODES=(
  "flit_ecc_cb"
)
FLIT_ONLY_RUNS_PER_MODE=10   # 5 U-side + 5 D-side per mode

# ─────────────────────────────────────────────────────────────────────────────
# Build the test matrix
# RUN_KEYS format: "u_vip|d_vip|u_err|d_err[|flit_only]"
# ─────────────────────────────────────────────────────────────────────────────
DEFAULT_VIP="default"
declare -a RUN_KEYS=()
NUM_VIP=${#VIP_MODES[@]}

add_run() {
  local key="${1}|${2}|${3}|${4}"
  for k in "${RUN_KEYS[@]+"${RUN_KEYS[@]}"}"; do
    [[ "$k" == "$key" ]] && return
  done
  RUN_KEYS+=("$key")
}

# 1. Each VIP on U-side, default on D
for vip in "${VIP_MODES[@]}"; do add_run "$vip" "$DEFAULT_VIP" "" ""; done
# 2. Each VIP on D-side, default on U
for vip in "${VIP_MODES[@]}"; do add_run "$DEFAULT_VIP" "$vip" "" ""; done
# 3. Baseline
add_run "$DEFAULT_VIP" "$DEFAULT_VIP" "" ""
# 4. VIP diagonal
for (( i=0; i<NUM_VIP; i++ )); do
  add_run "${VIP_MODES[$i]}" "${VIP_MODES[$(( (i+1) % NUM_VIP ))]}" "" ""
done
# 5. VIP cross
HALF=$(( NUM_VIP / 2 ))
for (( i=0; i<HALF; i++ )); do
  for (( j=HALF; j<NUM_VIP; j++ )); do
    add_run "${VIP_MODES[$i]}" "${VIP_MODES[$j]}" "" ""
    add_run "${VIP_MODES[$j]}" "${VIP_MODES[$i]}" "" ""
  done
done
# 6. Error injection runs
err_idx=0
for err in "${ERR_MODES[@]}"; do
  u_vip="${VIP_MODES[$(( err_idx % NUM_VIP ))]}"
  d_vip="${VIP_MODES[$(( (err_idx + 1) % NUM_VIP ))]}"
  add_run "$u_vip"       "$DEFAULT_VIP" "$err" ""
  add_run "$DEFAULT_VIP" "$d_vip"       ""     "$err"
  err_idx=$(( err_idx + 1 ))
done
# 7. Flit-only error runs (10 per mode: 5 U-side + 5 D-side)
if [[ "$RUN_FLIT" -eq 1 ]]; then
  for err in "${FLIT_ONLY_ERR_MODES[@]}"; do
    for (( i=0; i<FLIT_ONLY_RUNS_PER_MODE; i++ )); do
      if (( i % 2 == 0 )); then
        u_vip="${VIP_MODES[$(( (i/2) % NUM_VIP ))]}"
        RUN_KEYS+=("${u_vip}|${DEFAULT_VIP}|${err}||flit_only")
      else
        d_vip="${VIP_MODES[$(( (i/2) % NUM_VIP ))]}"
        RUN_KEYS+=("${DEFAULT_VIP}|${d_vip}||${err}|flit_only")
      fi
    done
  done
fi

# Calculate TOTAL
_normal=0; _flit_only=0
for _k in "${RUN_KEYS[@]}"; do
  if [[ "$_k" == *"|flit_only" ]]; then
    _flit_only=$(( _flit_only + 1 ))
  else
    _normal=$(( _normal + 1 ))
  fi
done
if [[ "$RUN_FLIT" -eq 1 ]]; then
  TOTAL=$(( _normal * 2 + _flit_only ))
else
  TOTAL=$_normal
fi

# ─────────────────────────────────────────────────────────────────────────────
# Colours & formatting
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

banner() { echo -e "${CYAN}${BOLD}$*${RESET}"; }
pass()   { echo -e "  ${GREEN}[PASS]${RESET} $*"; }
fail()   { echo -e "  ${RED}[FAIL]${RESET} $*"; }

declare -a RESULTS=()
record() { RESULTS+=("$1"); }

# ─────────────────────────────────────────────────────────────────────────────
# Helper functions
# ─────────────────────────────────────────────────────────────────────────────

# is_in_list <value> <item...>  — safe with empty lists
is_in_list() {
  local val="$1"; shift || true
  [[ $# -eq 0 ]] && return 1
  for item in "$@"; do [[ "$val" == "$item" ]] && return 0; done
  return 1
}

# log_has_any_errors <log>
# Returns 0 if log has any UVM_ERROR/FATAL message lines
log_has_any_errors() {
  local log="$1"
  [[ ! -f "$log" ]] && return 1
  grep -qE "$ERR_MSG_PAT" "$log" 2>/dev/null
}

# log_has_any_errors_injection <log>
# Same as log_has_any_errors but excludes the scoreboard final verdict
# line [DLL_SB] DLL TEST FAILED which fires at end-of-sim and is not
# a real error for injection runs.
log_has_any_errors_injection() {
  local log="$1"
  [[ ! -f "$log" ]] && return 1
  # Extract all UVM error/fatal message lines, strip the scoreboard final
  # verdict line, then check if anything remains.
  local filtered
  filtered=$(grep -E "$ERR_MSG_PAT" "$log" 2>/dev/null              | grep -vE "$SB_VERDICT_PAT")
  [[ -n "$filtered" ]]
}

# log_has_illegal_bin <log>
# Returns 0 if log has any Error-[FCIBH] illegal bin hit
log_has_illegal_bin() {
  local log="$1"
  [[ ! -f "$log" ]] && return 1
  grep -qE "$ILLEGAL_BIN_PAT" "$log" 2>/dev/null
}

# log_has_errors_outside_window <log> <cb_start> <cb_end>
# Returns 0 (true) if any UVM error timestamp falls outside [cb_start, cb_end]
# Returns 1 (false) if all errors are inside the window or there are none
log_has_errors_outside_window() {
  local log="$1" cb_start="$2" cb_end="$3"
  [[ ! -f "$log" ]] && return 1

  while IFS= read -r line; do
    # Skip scoreboard final verdict — it fires at end-of-sim, not a real error
    echo "$line" | grep -qE "$SB_VERDICT_PAT" && continue
    local ts
    ts=$(echo "$line" | grep -oE '@[[:space:]]*[0-9]+' | grep -oE '[0-9]+' | head -1)
    [[ -z "$ts" ]] && continue
    if [[ "$ts" -lt "$cb_start" || "$ts" -gt "$cb_end" ]]; then
      return 0   # error outside window → true
    fi
  done < <(grep -E "$ERR_MSG_PAT" "$log" 2>/dev/null || true)

  return 1   # all errors inside window → false
}

# parse_cb_window <log> <u_err> <d_err>
# Outputs two integers to stdout: "<cb_start> <cb_end>"
# All debug/warn messages go to stderr only
parse_cb_window() {
  local log="$1" u_err="$2" d_err="$3"

  local no_dereg=0
  if is_in_list "$u_err" "${NO_DEREG_ERR_MODES[@]}" 2>/dev/null || \
     is_in_list "$d_err" "${NO_DEREG_ERR_MODES[@]}" 2>/dev/null; then
    no_dereg=1
  fi

  # Collect all "registered" timestamps — stdout only from grep/sort
  local reg_times
  reg_times=$(grep -E '\[TEST_CB\].*[Cc]allback registered' "$log" 2>/dev/null \
              | grep -oE '@[[:space:]]*[0-9]+' \
              | grep -oE '[0-9]+' \
              | sort -n) || reg_times=""

  if [[ -z "$reg_times" ]]; then
    echo "-1 -1"
    return 0
  fi

  local cb_start cb_end
  cb_start=$(echo "$reg_times" | head -1)

  if [[ "$no_dereg" -eq 1 ]]; then
    cb_end=$(( cb_start * 2 ))
    echo "  [DBG] window (no-dereg): cb_start=${cb_start} cb_end=${cb_end}" >&2
  else
    local dereg_times
    dereg_times=$(grep -E '\[TEST_CB\].*[Cc]allback deregistered' "$log" 2>/dev/null \
                  | grep -oE '@[[:space:]]*[0-9]+' \
                  | grep -oE '[0-9]+' \
                  | sort -n) || dereg_times=""

    if [[ -n "$dereg_times" ]]; then
      cb_end=$(( $(echo "$dereg_times" | tail -1) + CB_GRACE_NS ))
    else
      echo "  [WARN] no deregister marker — falling back to last reg + grace" >&2
      cb_end=$(( $(echo "$reg_times" | tail -1) + CB_GRACE_NS ))
    fi
    echo "  [DBG] window: cb_start=${cb_start} cb_end=${cb_end} (grace=${CB_GRACE_NS}ns)" >&2
  fi

  # Only these two numbers go to stdout — nothing else
  echo "$cb_start $cb_end"
}

# classify_injection_run <log> <u_err> <d_err>
# Outputs a single status string to stdout
classify_injection_run() {
  local log="$1" u_err="$2" d_err="$3"

  # Illegal bin is always an immediate failure
  if log_has_illegal_bin "$log"; then
    echo "FAIL_ILLEGAL_BIN"
    return 0
  fi

  # Parse window — stdout is only "cb_start cb_end"
  local cb_window
  cb_window=$(parse_cb_window "$log" "$u_err" "$d_err")
  local cb_start cb_end
  read -r cb_start cb_end <<< "$cb_window"

  if [[ "$cb_start" -eq -1 ]]; then
    echo "  [WARN] no TEST_CB markers in: $log" >&2
    if log_has_any_errors "$log"; then
      echo "FAIL_NO_WINDOW"
    else
      echo "PASS"
    fi
    return 0
  fi

  if log_has_errors_outside_window "$log" "$cb_start" "$cb_end"; then
    echo "FAIL"
  elif log_has_any_errors_injection "$log"; then
    echo "PASS_CB"
  else
    echo "PASS"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Run a single simulation
# Result file format: label|status|group|flit
# Groups: A=no injection  B=error injection  C=ECC injection
# ─────────────────────────────────────────────────────────────────────────────
TMPDIR_REG=$(mktemp -d /tmp/pcie_reg_XXXXXX)
trap 'rm -rf "$TMPDIR_REG"' EXIT

run_one() {
  local idx="$1" u_vip="$2" d_vip="$3" u_err="$4" d_err="$5" flit="$6"

  local label="${u_vip}__${d_vip}"
  [[ -n "$u_err" ]] && label+="__uerr_${u_err}"
  [[ -n "$d_err" ]] && label+="__derr_${d_err}"
  [[ "$flit" -eq 1 ]] && label+="__flit"

  {
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "${label}|DRY|A|${flit}" > "${TMPDIR_REG}/${idx}"
      return 0
    fi

    local make_args=(
      "test=${TEST}"
      "verbosity=${VERBOSITY}"
      "seed=${SEED}"
      "u_vip_mode=${u_vip}"
      "d_vip_mode=${d_vip}"
      "u_err_mode=${u_err}"
      "d_err_mode=${d_err}"
      "flit_mode=${flit}"
    )

    $MAKE run "${make_args[@]}" >/dev/null 2>&1 || true

    # Log path mirrors Makefile RUN_NAME logic exactly
    local run_name="${u_vip}_u_${d_vip}_d"
    [[ -n "$u_err" ]] && run_name+="_${u_err}_u"
    [[ -n "$d_err" ]] && run_name+="_${d_err}_d"
    [[ "$flit" -eq 1 ]] && run_name+="_flit"
    run_name+="_seed_${SEED}"
    local log="./runs/${run_name}/simv.log"
    echo "  [DBG] log: $log" >&2

    local status group

    if [[ -z "$u_err" && -z "$d_err" ]]; then
      # ── Group A: no injection ─────────────────────────────────────────────
      group="A"
      if log_has_illegal_bin "$log"; then
        status="FAIL_ILLEGAL_BIN"
      elif log_has_any_errors "$log"; then
        status="FAIL"
      else
        status="PASS"
      fi

    elif is_in_list "$u_err" "${ECC_MODES[@]}" 2>/dev/null || \
         is_in_list "$d_err" "${ECC_MODES[@]}" 2>/dev/null; then
      # ── Group C: ECC injection ────────────────────────────────────────────
      group="C"
      if log_has_illegal_bin "$log"; then
        status="FAIL_ILLEGAL_BIN"
      else
        local cb_window
        cb_window=$(parse_cb_window "$log" "$u_err" "$d_err")
        local cb_start cb_end
        read -r cb_start cb_end <<< "$cb_window"

        if [[ "$cb_start" -eq -1 ]]; then
          echo "  [WARN] no TEST_CB markers in: $log" >&2
          if log_has_any_errors "$log"; then
            status="FAIL_NO_WINDOW"
          else
            status="PASS_ECC_CLEAN"
          fi
        elif log_has_errors_outside_window "$log" "$cb_start" "$cb_end"; then
          status="FAIL"
        elif log_has_any_errors_injection "$log"; then
          status="PASS_ECC_CORRECTED"
        else
          status="PASS_ECC_CLEAN"
        fi
      fi

    else
      # ── Group B: error injection ──────────────────────────────────────────
      group="B"
      status=$(classify_injection_run "$log" "$u_err" "$d_err")
    fi

    echo "${label}|${status}|${group}|${flit}" > "${TMPDIR_REG}/${idx}"
    return 0

  } || {
    echo "${label}|ERROR|A|${flit}" > "${TMPDIR_REG}/${idx}"
  }
}

export -f run_one log_has_any_errors log_has_any_errors_injection \
          log_has_illegal_bin log_has_errors_outside_window \
          parse_cb_window classify_injection_run is_in_list
export MAKE TEST VERBOSITY SEED DRY_RUN TMPDIR_REG CB_GRACE_NS RUN_FLIT
export NO_DEREG_ERR_MODES ECC_MODES ERR_MSG_PAT ILLEGAL_BIN_PAT SB_VERDICT_PAT

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
echo ""
banner "======================================================================="
banner "  PCIe UVM Regression  —  $(date '+%Y-%m-%d %H:%M:%S')"
banner "======================================================================="
echo -e "  Test       : ${BOLD}${TEST}${RESET}"
echo -e "  Seed       : ${SEED}"
echo -e "  Jobs       : ${JOBS} parallel"
echo -e "  Total      : ${TOTAL} runs"
echo -e "  CB grace   : ${CB_GRACE_NS} ns"
echo -e "  Flit mode  : $( [[ $RUN_FLIT -eq 1 ]] && echo "flit + non-flit" || echo "non-flit only" )"
[[ "$DRY_RUN" -eq 1 ]] && echo -e "  ${YELLOW}DRY RUN${RESET}"
echo ""

# ── Step 1: Compile ───────────────────────────────────────────────────────────
banner "[ 1/3 ]  Compiling..."
if [[ "$DRY_RUN" -eq 0 ]]; then
  if ! $MAKE compile; then
    echo -e "${RED}${BOLD}COMPILATION FAILED — aborting.${RESET}"
    exit 1
  fi
  echo -e "  ${GREEN}Compilation successful.${RESET}"
else
  echo -e "  ${YELLOW}(skipped — dry run)${RESET}"
fi
echo ""

# ── Step 2: Run simulations ───────────────────────────────────────────────────
banner "[ 2/3 ]  Running simulations..."
echo ""

active=0
idx=0
for key in "${RUN_KEYS[@]}"; do
  IFS='|' read -r u_vip d_vip u_err d_err flit_only_flag <<< "$key"
  flit_only_flag="${flit_only_flag:-}"

  if [[ "$flit_only_flag" == "flit_only" ]]; then
    [[ "$RUN_FLIT" -eq 0 ]] && continue
    idx=$(( idx + 1 ))
    printf "  [%3d/%3d]  %-80s\r" "$idx" "$TOTAL" \
      "${u_vip}/${d_vip}${u_err:+ uerr=$u_err}${d_err:+ derr=$d_err} [flit-only]"
    run_one "$idx" "$u_vip" "$d_vip" "$u_err" "$d_err" "1" &
    active=$(( active + 1 ))
  else
    for flit in 0 1; do
      [[ "$flit" -eq 1 && "$RUN_FLIT" -eq 0 ]] && continue
      idx=$(( idx + 1 ))
      printf "  [%3d/%3d]  %-80s\r" "$idx" "$TOTAL" \
        "${u_vip}/${d_vip}${u_err:+ uerr=$u_err}${d_err:+ derr=$d_err}${flit:+ flit=$flit}"
      run_one "$idx" "$u_vip" "$d_vip" "$u_err" "$d_err" "$flit" &
      active=$(( active + 1 ))
    done
  fi

  if [[ "$active" -ge "$JOBS" ]]; then
    wait -n 2>/dev/null || wait
    active=$(( active - 1 ))
  fi
done
wait
printf '%100s\r' ''
echo -e "  All simulations complete."
echo ""

# ── Step 3: Collect results ───────────────────────────────────────────────────
banner "[ 3/3 ]  Collecting results & merging coverage..."
echo ""

PASS_A=0; PASS_B=0; PASS_ECC_CLEAN=0; PASS_ECC_CORRECTED=0
FAIL_COUNT=0; NO_WINDOW_COUNT=0; ERR_COUNT=0

for (( i=1; i<=idx; i++ )); do
  result_file="${TMPDIR_REG}/${i}"
  if [[ -f "$result_file" ]]; then
    IFS='|' read -r label status group flit < "$result_file"
    record "${label}|${status}|${group}|${flit}"
  else
    record "run_${i}|ERROR|A|0"
  fi
done

if [[ "$DRY_RUN" -eq 0 ]]; then
  if $MAKE merge_coverage >/dev/null 2>&1; then
    echo -e "  ${GREEN}Coverage merged successfully.${RESET}"
  else
    echo -e "  ${YELLOW}Warning: coverage merge failed.${RESET}"
  fi
else
  echo -e "  ${YELLOW}(coverage merge skipped — dry run)${RESET}"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Report helpers
# ─────────────────────────────────────────────────────────────────────────────
print_entry() {
  local label="$1" status="$2"
  local col
  col="$(printf '%-90s' "$label")"
  case "$status" in
    PASS)
      pass "${col}  PASSED"
      PASS_A=$(( PASS_A + 1 ))
      ;;
    PASS_CB)
      echo -e "  ${GREEN}[PASS]${RESET} ${col}  PASSED  ${CYAN}(errors contained in callback window)${RESET}"
      PASS_B=$(( PASS_B + 1 ))
      ;;
    PASS_ECC_CLEAN)
      echo -e "  ${GREEN}[PASS]${RESET} ${col}  PASSED  ${GREEN}(ECC corrected — no UVM errors reported)${RESET}"
      PASS_ECC_CLEAN=$(( PASS_ECC_CLEAN + 1 ))
      ;;
    PASS_ECC_CORRECTED)
      echo -e "  ${GREEN}[PASS]${RESET} ${col}  PASSED  ${CYAN}(uncorrectable ECC error — contained in window)${RESET}"
      PASS_ECC_CORRECTED=$(( PASS_ECC_CORRECTED + 1 ))
      ;;
    FAIL_ILLEGAL_BIN)
      fail "${col}  FAILED ← Illegal bin hit (functional coverage violation)"
      FAIL_COUNT=$(( FAIL_COUNT + 1 ))
      ;;
    FAIL)
      fail "${col}  FAILED ← UVM errors found outside callback window"
      FAIL_COUNT=$(( FAIL_COUNT + 1 ))
      ;;
    FAIL_NO_WINDOW)
      fail "${col}  FAILED ← UVM errors found but no TEST_CB markers in log"
      FAIL_COUNT=$(( FAIL_COUNT + 1 ))
      NO_WINDOW_COUNT=$(( NO_WINDOW_COUNT + 1 ))
      ;;
    DRY)
      echo -e "  ${CYAN}[DRY]${RESET}  $label"
      ;;
    ERROR|*)
      echo -e "  ${RED}[ERROR]${RESET}  $label  (run_one crashed — check stderr)"
      ERR_COUNT=$(( ERR_COUNT + 1 ))
      ;;
  esac
}

group_header() {
  echo ""
  echo -e "  ${BOLD}$*${RESET}"
  printf "  %-90s  %s\n" "$(printf '%0.s─' {1..90})" "────────────────"
}

print_section() {
  local title="$1"
  local -n _A="$2" _B="$3" _C="$4"
  local total=$(( ${#_A[@]} + ${#_B[@]} + ${#_C[@]} ))
  echo ""
  echo -e "${CYAN}${BOLD}  ╔══════════════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}${BOLD}  ║  ${title}  (${total} runs)${RESET}"
  echo -e "${CYAN}${BOLD}  ╚══════════════════════════════════════════════════════════════════════╝${RESET}"

  group_header "  Group A — No error injection  (${#_A[@]} runs)"
  for entry in "${_A[@]+"${_A[@]}"}"; do
    IFS='|' read -r lbl st <<< "$entry"; print_entry "$lbl" "$st"
  done

  group_header "  Group B — Error injection, errors expected in window  (${#_B[@]} runs)"
  for entry in "${_B[@]+"${_B[@]}"}"; do
    IFS='|' read -r lbl st <<< "$entry"; print_entry "$lbl" "$st"
  done

  if [[ ${#_C[@]} -gt 0 ]]; then
    group_header "  Group C — ECC injection, errors correctable  (${#_C[@]} runs)"
    for entry in "${_C[@]+"${_C[@]}"}"; do
      IFS='|' read -r lbl st <<< "$entry"; print_entry "$lbl" "$st"
    done
  fi
}

# Split results by flit/non-flit and group
declare -a NF_A=() NF_B=() NF_C=()
declare -a FL_A=() FL_B=() FL_C=()

for entry in "${RESULTS[@]}"; do
  IFS='|' read -r label status group flit <<< "$entry"
  local_flit="${flit:-0}"
  e="${label}|${status}"
  if [[ "$local_flit" -eq 1 ]]; then
    case "$group" in
      B) FL_B+=("$e") ;; C) FL_C+=("$e") ;; *) FL_A+=("$e") ;;
    esac
  else
    case "$group" in
      B) NF_B+=("$e") ;; C) NF_C+=("$e") ;; *) NF_A+=("$e") ;;
    esac
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Print report
# ─────────────────────────────────────────────────────────────────────────────
banner "======================================================================="
banner "  REGRESSION REPORT  —  $(date '+%Y-%m-%d %H:%M:%S')"
banner "======================================================================="

print_section "NON-FLIT MODE"                   NF_A NF_B NF_C
[[ "$RUN_FLIT" -eq 1 ]] && \
  print_section "GEN6 FLIT MODE  (+flit_mode)"  FL_A FL_B FL_C

TOTAL_PASS=$(( PASS_A + PASS_B + PASS_ECC_CLEAN + PASS_ECC_CORRECTED ))
echo ""
banner "======================================================================="
echo -e "  ${GREEN}${BOLD}PASSED                      : ${TOTAL_PASS}${RESET}"
echo -e "  ${GREEN}        Group A  clean       : ${PASS_A}${RESET}"
echo -e "  ${CYAN}        Group B  in-window   : ${PASS_B}${RESET}  (errors contained, design recovered)"
echo -e "  ${GREEN}        Group C  ECC clean   : ${PASS_ECC_CLEAN}${RESET}  (ECC corrected before UVM reported)"
echo -e "  ${CYAN}        Group C  ECC errors  : ${PASS_ECC_CORRECTED}${RESET}  (uncorrectable ECC error contained in window)"
echo -e "  ${RED}${BOLD}FAILED                      : ${FAIL_COUNT}${RESET}"
[[ "$NO_WINDOW_COUNT" -gt 0 ]] && \
  echo -e "  ${YELLOW}        no window markers    : ${NO_WINDOW_COUNT}${RESET}  (TEST_CB not found — check UVM_LOW verbosity)"
[[ "$ERR_COUNT" -gt 0 ]] && \
  echo -e "  ${RED}${BOLD}SCRIPT ERRORS               : ${ERR_COUNT}${RESET}  (run_one crashed — check stderr)"
echo -e "  ${BOLD}TOTAL RUNS                  : ${TOTAL}${RESET}"
banner "======================================================================="
echo ""

if [[ "$FAIL_COUNT" -gt 0 || "$ERR_COUNT" -gt 0 ]]; then
  echo -e "${RED}${BOLD}  ✗  Regression FAILED — see FAILED entries above.${RESET}"
  echo -e "     Tip: re-run with  ./regression.sh --fail <run_name>  to inspect a log."
  echo ""
  exit 1
else
  echo -e "${GREEN}${BOLD}  ✔  Regression PASSED — all unexpected results: 0.${RESET}"
  echo ""
  exit 0
fi
