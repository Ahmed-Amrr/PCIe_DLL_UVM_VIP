# Variables
uvm_ver        = uvm-1.2
seed          ?= 567
SRC_FILES_LIST = src_files.list
TOP_MODULE    ?= pcie_top
UVM_TESTNAME  ?= pcie_base_test
SEQ           ?= pcie_inactive_sequence
UVM_VERBOSITY  = UVM_MEDIUM
log            = simv.log

# Directories
PKG_DIR  = ../packages
VIP_DIR  = "../vip code"
TEST_DIR = "../test code"

# Read source files from list
SRC_FILES = $(shell cat $(SRC_FILES_LIST))

# Run Directory
TEST_CASE = ${SEQ}_seed${seed}
RUN_DIR   = ./runs/${TEST_CASE}

compile_switches = -sverilog -full64 -lca -debug_access+all -kdb \
                   -timescale="1ns/100ps" \
                   -l ${RUN_DIR}/compile_${TOP_MODULE}.log \
                   -ntb_opts ${uvm_ver} \
                   +incdir+${PKG_DIR} \
                   +incdir+${VIP_DIR} \
                   +incdir+${TEST_DIR} \
                   -top $(TOP_MODULE) $(SRC_FILES)

runtime_switches = +UVM_TESTNAME=${UVM_TESTNAME} +UVM_VERBOSITY=${UVM_VERBOSITY} +SEQ=${SEQ} \
                   +vpdfile+${RUN_DIR}/vcdplus.vpd -classdebug -uvmcontrol=all \
                   -l ${RUN_DIR}/${log} +fsdbfile+${RUN_DIR}/dump.fsdb

###############################################
all: setup compile run

###############################################
setup:
    @mkdir -p runs
    @mkdir -p ${RUN_DIR}

###############################################
compile: setup
    vcs $(compile_switches)

###############################################
run: setup
    @echo "========================================"
    @echo "Running Test: ${UVM_TESTNAME}   Seq: ${SEQ}   Seed: ${seed}"
    @echo "========================================"
    ./simv +ntb_random_seed=${seed} ${runtime_switches}
    @echo "Simulation complete."

###############################################
clean:
    rm -rf simv* csrc* *.tmp *.vpd *.key *.log* .vcs* *.txt \
           .inter.vpd.uvm .restart* .synopsys* novas.* \
           *.dat *.fsdb verdi* work* vlog* AN.DB flex*

clean_runs:
    rm -rf runs/*

clean_all: clean clean_runs

###############################################
.PHONY: all setup compile run clean clean_runs clean_all


# # Variables
# uvm_ver        = uvm-1.2
# seed          ?= 567
# SRC_FILES_LIST = src_files.list
# TOP_MODULE    ?= pcie_top
# UVM_TESTNAME  ?= pcie_base_test
# SEQ           ?= pcie_inactive_sequence
# UVM_VERBOSITY  = UVM_MEDIUM
# log            = simv.log

# # Read source files from list
# SRC_FILES = $(shell cat $(SRC_FILES_LIST))

# # Run Directory
# TEST_CASE = ${SEQ}_seed${seed}
# RUN_DIR   = ./runs/${TEST_CASE}

# compile_switches = -sverilog -full64 -lca -debug_access+all -kdb \
#                    -timescale="1ns/100ps" -l compile_${TOP_MODULE}.log \
#                    -ntb_opts ${uvm_ver} \
#                    -top $(TOP_MODULE) $(SRC_FILES)

# runtime_switches = +UVM_TESTNAME=${UVM_TESTNAME} +UVM_VERBOSITY=${UVM_VERBOSITY} +SEQ=${SEQ} \
#                    +vpdfile+${RUN_DIR}/vcdplus.vpd -classdebug -uvmcontrol=all \
#                    -l ${RUN_DIR}/${log} +fsdbfile+${RUN_DIR}/dump.fsdb

# ###############################################
# all: setup compile run

# ###############################################
# setup:
#     @mkdir -p runs
#     @mkdir -p ${RUN_DIR}

# ###############################################
# compile:
#     vcs $(compile_switches)

# ###############################################
# run: setup
#     @echo "========================================"
#     @echo "Running Test: ${UVM_TESTNAME}   Seq: ${SEQ}   Seed: ${seed}"
#     @echo "========================================"
#     ./simv +ntb_random_seed=${seed} ${runtime_switches}
#     @echo "Simulation complete."

# ###############################################
# clean:
#     rm -rf simv* csrc* *.tmp *.vpd *.key *.log* .vcs* *.txt \
#            .inter.vpd.uvm .restart* .synopsys* novas.* \
#            *.dat *.fsdb verdi* work* vlog* AN.DB flex*

# clean_runs:
#     rm -rf runs/*

# clean_all: clean clean_runs

# ###############################################
# .PHONY: all setup compile run clean clean_runs clean_all
