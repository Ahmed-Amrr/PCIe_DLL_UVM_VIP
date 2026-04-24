class pcie_inactive_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_inactive_seq)

    function new(string name = "pcie_inactive_seq");
        super.new(name);
    endfunction //new()

    task body();
        wait (p_sequencer.state != DL_INACTIVE);      
    endtask

endclass //pcie_inactive_seq extends pcie_base_seq