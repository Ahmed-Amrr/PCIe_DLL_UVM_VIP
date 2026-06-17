`ifndef PCIE_DLLP_SEQ_ITEM
`define PCIE_DLLP_SEQ_ITEM

class pcie_dllp_seq_item extends uvm_sequence_item;

    // Randomizable Fields
    rand logic [47:0] dllp        ;   // Full 48-bit DLLP (6 bytes)
    rand logic        lp_valid    ;   // Link Partner valid flag
	// Field Declarations
    dllp_type_t       dllp_type   ;   // Decoded DLLP type enum
    bit               pl_lnk_up   ;   // Physical link up indicator
    bit               pl_valid    ;   // Physical layer data valid
    bit               reset       ;   // Reset flag
    int unsigned      pkt_id      ;   // Packet ID for tracing and debug

    // UVM Factory register + field automation
    `uvm_object_utils_begin(pcie_dllp_seq_item)
        `uvm_field_int  (dllp,                          UVM_ALL_ON)
        `uvm_field_int  (lp_valid,                      UVM_ALL_ON)
        `uvm_field_enum (dllp_type_t, dllp_type,        UVM_ALL_ON)
        `uvm_field_int  (pl_lnk_up,                     UVM_ALL_ON)
        `uvm_field_int  (pl_valid,                      UVM_ALL_ON)
        `uvm_field_int  (reset,                         UVM_ALL_ON)
        `uvm_field_int  (pkt_id,                        UVM_ALL_ON)
    `uvm_object_utils_end

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_dllp_seq_item");
        super.new(name);
    endfunction

endclass : pcie_dllp_seq_item

`endif