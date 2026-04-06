class pcie_init2_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_init1_seq)

    function new(string name = "pcie_init2_seq");
        super.new(name);
    endfunction //new()

    task body();
        start_from_INIT2();
    endtask

endclass //pcie_init1_seq extends pcie_base_seq