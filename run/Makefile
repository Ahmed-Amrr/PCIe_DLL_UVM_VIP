# ==============================================================================
# Default Configuration
# ==============================================================================
test         ?= pcie_top_test
seq_u        ?= pcie_inactive_seq 
seq_d        ?= pcie_inactive_seq 
u_vip_mode   ?=
d_vip_mode   ?=
seed         ?= 1
verbosity    ?= UVM_MEDIUM
uvm_ver       = uvm-1.2


# ==============================================================================
# Paths
# ==============================================================================

package_path   = ./../packages
vip_path       = ./../VIP_code
test_code_path = ./../test_code
run_base_path  = ./
FILELIST = $(run_base_path)/src_file.list

TOP_MODULE   ?= ${test_code_path}/pcie_top.sv

uvm_defines = UVM_NO_DEPRECATED+UVM_OBJECT_MUST_HAVE_CONSTRUCTOR

# ==============================================================================
# Run Name  
# =============================================================================

# Append VIP modes only if defined
ifneq ($(u_vip_mode),)
    RUN_NAME_BASE := $(RUN_NAME_BASE)_$(u_vip_mode)u
endif

ifneq ($(d_vip_mode),)
    RUN_NAME_BASE := $(RUN_NAME_BASE)_$(d_vip_mode)d
endif

RUN_NAME = $(RUN_NAME_BASE)


# ==============================================================================
# Run directory
# ==============================================================================

# Compile-time coverage (shared, contains design info)
COMPILE_COV_DIR = ${run_base_path}/coverage_db/pcie_top

# Runtime coverage (per run, contains test results)
RUN_DIR      = ${run_base_path}/runs/${RUN_NAME}
LOG_FILE     = ${RUN_DIR}/simv.log
COV_DIR      = ${RUN_DIR}/coverage

RUN_NAME_BASE = ${seq_u}_up_${seq_d}_down


# ==============================================================================
# Compilation Options
# ==============================================================================
COMPILE_OPTS = -sverilog                        \
                -full64                         \
                -lca                            \
                -debug_access+all               \
                -debug_region+class             \
                +vcs+flush+all                  \
                -kdb                            \
                +vcs+vcdpluson                  \
                -timescale="1ns/100ps"          \
                -l $(run_base_path)/compile.log \
                -Mdir=$(run_base_path)/csrc     \
                -o $(run_base_path)/simv        \
                -ntb_opts ${uvm_ver}            \
                -cm line+tgl+cond+branch+assert \
                -cm_dir ${COMPILE_COV_DIR}      \
                +define+${uvm_defines}          


# ==============================================================================
# Runtime Options
# ==============================================================================
RUN_OPTS =  -l ${LOG_FILE}                          \
            +UVM_TESTNAME=${test}                   \
            +UVM_VERBOSITY=${verbosity}             \
            +SEQ_U=${seq_u}                         \
            +SEQ_D=${seq_d}                         \
            +U_VIP_MODE=${u_vip_mode}               \
            +D_VIP_MODE=${d_vip_mode}               \
            -cm line+tgl+cond+branch+assert         \
            -cm_name ${RUN_NAME}                    \
            -cm_dir ${COV_DIR}/simv.vdb             \
            +vpdfile+${RUN_DIR}/vcdplus.vpd         \
            +fsdbfile+${RUN_DIR}/dump.fsdb



# ==============================================================================
# Main Targets
# ==============================================================================

.PHONY: all compile run run_random setup check_simv        \
        cover verdi_cov merge_coverage verdi_cov_merged    \
        dve dve_i verdi verdi_i verdi_uvm                  \
        list_runs log cov_report cov_merged                \
        clean_runs clean_all help

all: setup compile run

setup:
    @mkdir -p ${RUN_DIR}
    @mkdir -p ${COV_DIR}
    @mkdir -p ${COMPILE_COV_DIR}
    @echo "Created run directory  : ${RUN_DIR}"
    @echo "Created cov directory  : ${COV_DIR}"


compile:
    @echo "========================================"
    @echo " Compiling phase"
    @echo "========================================"

        vcs $(COMPILE_OPTS) -f $(FILELIST)

    @echo "Compilation complete."

run: setup check_simv
    @echo "========================================"
    @echo " Running  : ${RUN_NAME}"
    @echo " Test     : ${test}"
    @echo " Seed     : ${seed}"
    @echo " SEQ_U    : ${seq_u}"
    @echo " SEQ_D    : ${seq_d}"
    @echo " U_MODE   : ${u_vip_mode}"
    @echo " D_MODE   : ${d_vip_mode}"
    @echo " Log      : ${LOG_FILE}"
    @echo "========================================"
        ${run_base_path}/simv +ntb_random_seed=${seed} ${RUN_OPTS}
    @echo "======================================================"
    @echo " DONE — check log: ${LOG_FILE}"
    @echo "======================================================"

run_random: setup check_simv
    @echo "========================================"
    @echo " Running with RANDOM seed"
    @echo " Test     : ${test}"
    @echo " SEQ_U    : ${seq_u}"
    @echo " SEQ_D    : ${seq_d}"
    @echo " Log      : ${LOG_FILE}"
    @echo "========================================"
        ${run_base_path}/simv +ntb_random_seed_automatic ${RUN_OPTS}
    @echo "========================================"
    @echo " DONE — check log: ${LOG_FILE}"
    @echo "========================================"


check_simv:
    @test -f ${run_base_path}/simv || \
      (echo "ERROR: simv not found — run 'make compile' first" && exit 1)


# ==============================================================================
# Coverage
# ==============================================================================

# Generate coverage report for a specific run
cover:
    @echo "Generating coverage for ${RUN_NAME}..."
    urg -full64 \
        -dir ${COMPILE_COV_DIR} \
        -dir ${COV_DIR}/simv.vdb \
        -dbname ${RUN_NAME} \
        -report ${COV_DIR}/report
    @echo "Coverage report: ${COV_DIR}/report/index.html"

# Open coverage in Verdi for a specific run
verdi_cov:
    @echo "Opening coverage for ${RUN_NAME} in Verdi..."
    verdi -cov \
          -covdir ${COMPILE_COV_DIR} \
          -covdir ${COV_DIR}/simv.vdb \
          -nologo &

# Merge all runs coverage databases into a single .vdb
merge_coverage:
    @echo "Merging all coverage databases..."
    @find ${run_base_path}/runs -name "simv.vdb" -type d > ${run_base_path}/runs/vdb_list.txt
    @if [ ! -s ${run_base_path}/runs/vdb_list.txt ]; then \
        echo "ERROR: No coverage databases found under runs/"; \
        echo "Run some simulations first!"; \
        exit 1; \
    fi
    @echo "Found databases:"; cat ${run_base_path}/runs/vdb_list.txt
    @mkdir -p ${run_base_path}/runs/merged_coverage
    urg -full64 \
        -dir ${COMPILE_COV_DIR} \
        $(shell cat ${run_base_path}/runs/vdb_list.txt | sed 's/^/-dir /') \
        -dbname ${run_base_path}/runs/merged_coverage/merged.vdb \
        -format both \
        -report ${run_base_path}/runs/merged_coverage
    @echo "Merge complete."
    @echo "  HTML report : ${run_base_path}/runs/merged_coverage/index.html"
    @echo "  VDB         : ${run_base_path}/runs/merged_coverage/merged.vdb"

# View merged coverage in Verdi
verdi_cov_merged:
    @if [ ! -d ${run_base_path}/runs/merged_coverage/merged.vdb ]; then \
        echo "ERROR: Merged coverage database not found."; \
        echo "Run 'make merge_coverage' first."; \
        exit 1; \
    fi
    @echo "Opening merged coverage in Verdi..."
    verdi -cov \
          -covdir ${run_base_path}/runs/merged_coverage/merged.vdb \
          -nologo &

# ==============================================================================
# Waveform Viewers
# ==============================================================================

# DVE — view waveform for a specific run
dve:
    @if [ ! -f ${RUN_DIR}/vcdplus.vpd ]; then \
        echo "ERROR: Waveform not found at ${RUN_DIR}/vcdplus.vpd"; \
        echo "Available runs:"; ls -1 ${run_base_path}/runs/; \
        exit 1; \
    fi
    dve -full64 -vpd ${RUN_DIR}/vcdplus.vpd &

# DVE — interactive (run simv and open DVE GUI together)
dve_i: setup check_simv
    @echo "Launching interactive DVE..."
    ${run_base_path}/simv -gui=dve ${RUN_OPTS}

# Verdi — view waveform for a specific run
verdi:
    @if [ ! -f ${RUN_DIR}/dump.fsdb ]; then \
        echo "ERROR: FSDB not found at ${RUN_DIR}/dump.fsdb"; \
        echo "Available runs:"; ls -1 ${run_base_path}/runs/; \
        exit 1; \
    fi
    verdi -ssf ${RUN_DIR}/dump.fsdb -nologo &

# Verdi — interactive (run simv and open Verdi GUI together)
verdi_i: setup check_simv
    @echo "Launching interactive Verdi..."
    ${run_base_path}/simv -gui=verdi \
                          +UVM_VERDI_TRACE \
                          ${RUN_OPTS}

# Verdi — UVM debug mode
verdi_uvm:
    @if [ ! -f ${RUN_DIR}/dump.fsdb ]; then \
        echo "ERROR: FSDB not found at ${RUN_DIR}/dump.fsdb"; \
        exit 1; \
    fi
    verdi -uvmDebug \
          -ssf ${RUN_DIR}/dump.fsdb \
          -nologo &

# ==============================================================================
# Browse Results
# ==============================================================================

# List all runs (most recent first)
list_runs:
    @echo "Available runs:"
    @ls -1t ${run_base_path}/runs/ | head -20

# Tail the log file for the current run
log:
    @if [ ! -f ${LOG_FILE} ]; then \
        echo "ERROR: Log not found: ${LOG_FILE}"; \
        exit 1; \
    fi
    less ${LOG_FILE}

# Open per-run coverage HTML report in browser
cov_report:
    @if [ ! -f ${COV_DIR}/report/index.html ]; then \
        echo "ERROR: Coverage report not found. Run 'make cover' first."; \
        exit 1; \
    fi
    firefox ${COV_DIR}/report/index.html &

# Open merged coverage HTML report in browser
cov_merged:
    @if [ ! -f ${run_base_path}/runs/merged_coverage/index.html ]; then \
        echo "ERROR: Merged report not found. Run 'make merge_coverage' first."; \
        exit 1; \
    fi
    firefox ${run_base_path}/runs/merged_coverage/index.html &

# ==============================================================================
# Clean Targets
# ==============================================================================

# Clean only run directories (keeps compiled simv)
clean_runs:
    @echo "Cleaning run directories..."
    @rm -rf ${run_base_path}/runs
    @echo "Runs cleaned."

# Clean everything (runs + compiled artifacts)
clean_all:
    @echo "Cleaning everything..."
    @rm -rf ${run_base_path}/runs
    @rm -rf ${run_base_path}/coverage_db
    @rm -rf ${run_base_path}/simv
    @rm -rf ${run_base_path}/simv.daidir
    @rm -rf ${run_base_path}/csrc
    @rm -rf ${run_base_path}/ucli.key
    @rm -rf ${run_base_path}/*.log
    @rm -rf ${run_base_path}/*.vpd
    @rm -rf ${run_base_path}/*.fsdb
    @rm -rf ${run_base_path}/*.vdb
    @echo "Full clean complete."

# ==============================================================================
# Help
# ==============================================================================

help:
    @echo ""
    @echo "========================================================================"
    @echo "                        PCIe VIP Simulation Makefile                    "
    @echo "========================================================================"
    @echo ""
    @echo "  USAGE: make <target> [OPTION=value ...]"
    @echo ""
    @echo "------------------------------------------------------------------------"
    @echo "  MAIN TARGETS"
    @echo "------------------------------------------------------------------------"
    @echo "  all               Setup + compile + run"
    @echo "  setup             Create all required run/coverage directories"
    @echo "  compile           Compile the design with VCS"
    @echo "  run               Run simulation with fixed seed"
    @echo "  run_random        Run simulation with automatic random seed"
    @echo ""
    @echo "------------------------------------------------------------------------"
    @echo "  COVERAGE"
    @echo "------------------------------------------------------------------------"
    @echo "  cover             Generate coverage report for current run"
    @echo "  merge_coverage    Merge all runs coverage databases into one .vdb"
    @echo "  verdi_cov         Open current run coverage in Verdi"
    @echo "  verdi_cov_merged  Open merged coverage in Verdi"
    @echo "  cov_report        Open current run coverage report in Firefox"
    @echo "  cov_merged        Open merged coverage report in Firefox"
    @echo ""
    @echo "------------------------------------------------------------------------"
    @echo "  WAVEFORM VIEWERS"
    @echo "------------------------------------------------------------------------"
    @echo "  dve               Open VPD waveform in DVE for current run"
    @echo "  dve_i             Run simulation and open DVE interactively"
    @echo "  verdi             Open FSDB waveform in Verdi for current run"
    @echo "  verdi_i           Run simulation and open Verdi interactively"
    @echo "  verdi_uvm         Open FSDB in Verdi with UVM debug mode"
    @echo ""
    @echo "------------------------------------------------------------------------"
    @echo "  BROWSE RESULTS"
    @echo "------------------------------------------------------------------------"
    @echo "  list_runs         List the 20 most recent runs"
    @echo "  log               Open current run log file"
    @echo ""
    @echo "------------------------------------------------------------------------"
    @echo "  CLEAN"
    @echo "------------------------------------------------------------------------"
    @echo "  clean_runs        Remove all run directories (keeps compiled simv)"
    @echo "  clean_all         Remove everything including compiled artifacts"
    @echo ""
    @echo "------------------------------------------------------------------------"
    @echo "  PARAMETERS (all optional — defaults shown)"
    @echo "------------------------------------------------------------------------"
    @echo "  test=<name>         UVM test name          (default: ${test})"
    @echo "  seed=<number>       Simulation seed        (default: ${seed})"
    @echo "  verbosity=<level>   UVM verbosity          (default: ${verbosity})"
    @echo "  seq_u=<name>        Upstream sequence      (default: ${seq_u})"
    @echo "  seq_d=<name>        Downstream sequence    (default: ${seq_d})"
    @echo "  u_vip_mode=<mode>   Upstream VIP mode      (default: unset)"
    @echo "  d_vip_mode=<mode>   Downstream VIP mode    (default: unset)"
    @echo ""
    @echo "------------------------------------------------------------------------"
    @echo "  EXAMPLES"
    @echo "------------------------------------------------------------------------"
    @echo "  make compile"
    @echo "  make run"
    @echo "  make run seed=42 verbosity=UVM_HIGH"
    @echo "  make run seq_u=pcie_init_sequence seq_d=pcie_active_sequence"
    @echo "  make run u_vip_mode=active d_vip_mode=passive"
    @echo "  make run_random seq_u=pcie_feature_sequence"
    @echo "  make cover"
    @echo "  make merge_coverage"
    @echo "  make clean_runs"
    @echo "  make clean_all"
    @echo "========================================================================"
    @echo ""