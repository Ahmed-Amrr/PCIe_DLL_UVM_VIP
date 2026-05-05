`ifndef PCIE_STATE_SEQ_ITEM_SV
`define PCIE_STATE_SEQ_ITEM_SV

class pcie_state_seq_item extends uvm_sequence_item;

	// Randomizable fields
	dl_state_t  vip_state          ;   // Current state of the VIP state machine
	int         DL_Up              ;   // Flag indicating if the data link layer is currently up
	int         DL_Down            ;   // Flag indicating if the data link layer has gone down
	int         surprise_down_event;   // Flag indicating if a surprise down event occurred
	int         scaled_fc_active   ;   // Flag indicating if scaled flow control is active
	int         FI1                ;   // Flag indicating if the INIT1 has done
	int         FI2                ;   // Flag indicating if the INIT2 has done

	//These flags used for getting DLLP with INITFC1 type in order
	bit init1_p_f;				//Posetd
	bit init1_np_f;				//Non-Posted
	bit init1_cpl_f;			//Compeletion		


	`uvm_object_utils_begin(pcie_state_seq_item)
        `uvm_field_enum (dl_state_t, vip_state,           UVM_ALL_ON)
        `uvm_field_int  (DL_Up                ,           UVM_ALL_ON)
        `uvm_field_int  (DL_Down              ,           UVM_ALL_ON)
        `uvm_field_int  (surprise_down_event  ,           UVM_ALL_ON)
        `uvm_field_int  (scaled_fc_active     ,           UVM_ALL_ON)
        `uvm_field_int  (FI1                  ,           UVM_ALL_ON)
        `uvm_field_int  (FI2                  ,           UVM_ALL_ON)
    `uvm_object_utils_end
	

	// Constructor
	function new(string name = "pcie_state_seq_item");
		super.new(name);
	endfunction : new

endclass : pcie_state_seq_item

`endif 





