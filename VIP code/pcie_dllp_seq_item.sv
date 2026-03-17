`ifndef PCIE_DLLP_SEQ_ITEM
`define PCIE_DLLP_SEQ_ITEM

class pcie_dllp_seq_item extends uvm_sequence_item;
	`uvm_object_utils(pcie_dllp_seq_item)

	rand logic [47:0] dllp;			// 8 * 6bytes = 48 bits
	rand logic lp_valid;

	logic pl_lnk_up;
	logic pl_valid;

	// Constructor
	function new(string name = "pcie_dllp_seq_item");
		super.new(name);
	endfunction

	// constraint Ack_c {
	// 	dllp [47:40] = 8'b0000_0000;			//type
	// 	dllp [39:28] = {12{1'b0}};				//reserved
	// }

	// // for NOP type no need for constraints as the datapayload is arbitrary value

	// constraint PM_c {
	// 	dllp [47:43] = 5'b0010_0;				//type
	// 	dllp [39:16] = {24{1'b0}};				//reserved
	// }

	// constraint Feature_c {
	// 	dllp [47:40] = 8'b0000_0010;
	// }

	// constraint ready_c {
	// 	ready dist {1:/99, 0:/1};
	// }
endclass : pcie_dllp_seq_item

`endif 


