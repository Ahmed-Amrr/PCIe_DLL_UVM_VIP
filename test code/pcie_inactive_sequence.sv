class pcie_inactive_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_inactive_seq)

    pcie_dllp_seq_item item;

    function new(string name = "pcie_inactive_seq");
        super.new(name);
    endfunction //new()

    task body();
        start_from_INACTIVE(item);
    endtask

endclass //pcie_inactive_seq extends pcie_base_seq