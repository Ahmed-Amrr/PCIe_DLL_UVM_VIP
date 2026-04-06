class pcie_inactive_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_init1_seq)

    function new(string name = "pcie_inactive_seq");
        super.new(name);
    endfunction //new()

    task body();
        start_from_INACTIVE();
    endtask

endclass //pcie_inactive_seq extends pcie_base_seq