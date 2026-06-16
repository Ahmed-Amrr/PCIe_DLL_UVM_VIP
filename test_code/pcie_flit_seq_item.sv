`ifndef PCIE_FLIT_SEQ_ITEM
`define PCIE_FLIT_SEQ_ITEM

class pcie_flit_seq_item extends uvm_sequence_item;

    // Randomizable Fields
    logic [7:0] flit [0:255]            ;   // Full flit (256 bytes)
    rand logic              lp_valid    ;   // Link Partner valid flag
    bit                     pl_lnk_up   ;   // Physical link up indicator
    bit                     pl_valid    ;   // Physical layer data valid
    bit                     reset       ;   // Reset flag

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_flit_seq_item");
        super.new(name);
    endfunction

endclass : pcie_flit_seq_item

`endif