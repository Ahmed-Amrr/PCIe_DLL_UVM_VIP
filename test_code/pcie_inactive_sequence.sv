`ifndef PCIE_INACTIVE_SEQUENCE_SV
`define PCIE_INACTIVE_SEQUENCE_SV

class pcie_inactive_seq extends pcie_base_seq;

    // UVM Factory register
    `uvm_object_utils(pcie_inactive_seq)

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_inactive_seq");
        super.new(name);
    endfunction : new

    //==========================================================
    // Body - Drive idle items while in DL_INACTIVE state
    //==========================================================
    // Sends empty sequence items with no payload while the sequencer
    // remains in DL_INACTIVE, keeping the driver occupied without
    // transmitting any meaningful DLLP data
    task body();
        repeat(p_sequencer.state == DL_INACTIVE) begin
            item = pcie_dllp_seq_item::type_id::create("item");
            start_item(item);
            finish_item(item);
        end
    endtask : body

endclass : pcie_inactive_seq

`endif