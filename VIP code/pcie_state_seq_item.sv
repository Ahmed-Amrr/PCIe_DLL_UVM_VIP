`ifndef PCIE_STATE_SEQ_ITEM
`define PCIE_STATE_SEQ_ITEM

class pcie_state_seq_item extends uvm_sequence_item;
	`uvm_object_utils(pcie_state_seq_item)

	dl_state_t vip_state;

	logic DL_Up;
	logic DL_Down;
	logic surprise_down_event;

	// Constructor
	function new(string name = "pcie_state_seq_item");
		super.new(name);
	endfunction

endclass : pcie_state_seq_item

`endif 


