vlib work
vlog -f src_files.list +cover -covercells
vsim -voptargs=+acc work.pcie_top -classdebug -uvmcontrol=all -cover
run -all