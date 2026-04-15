`ifndef PCIE_INACTIVE_SEQUENCE_SV
`define PCIE_INACTIVE_SEQUENCE_SV

class pcie_inactive_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_inactive_seq)

    pcie_dllp_seq_item item;
    
    function new(string name = "pcie_inactive_seq");
        super.new(name);
    endfunction

    virtual task body();    
        repeat (10) begin
            item = pcie_dllp_seq_item::type_id::create("item");
            start_item(item);
            assert (seq_item.randomize());
            item.rst_req = 1;
            finish_item(item);
        end
    endtask : body

endclass : pcie_inactive_seq

`endif