`ifndef PCIE_VIP_SCOREBOARD
`define PCIE_VIP_SCOREBOARD

class pcie_vip_scoreboard extends uvm_component;

/*-------------------------------------------------------------------------------
-- UVM Factory register
-------------------------------------------------------------------------------*/
	// Provide implementations of virtual methods such as get_type_name and create
	`uvm_component_utils(pcie_vip_scoreboard)

/*-------------------------------------------------------------------------------
-- Interface, port, fields
-------------------------------------------------------------------------------*/
	uvm_analysis_export #(pcie_dllp_seq_item) sb_export_tx;		//getting the data from tx monitor
	uvm_tlm_analysis_fifo #(pcie_dllp_seq_item) sb_fifo_tx;

	pcie_dllp_seq_item seq_item_tx;

	uvm_analysis_export #(pcie_dllp_seq_item) sb_export_rx;		//getting the data from rx monitor
	uvm_tlm_analysis_fifo #(pcie_dllp_seq_item) sb_fifo_rx;

	pcie_dllp_seq_item seq_item_rx;

	uvm_analysis_export #(pcie_state_seq_item) sb_export_state;		//getting the data from state machine
	uvm_tlm_analysis_fifo #(pcie_state_seq_item) sb_fifo_state;
	pcie_state_seq_item state_seq_item;

	pcie_vip_config cfg;										//to get the configuration registers
/*-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------*/
	// Constructor
	function new(string name = "pcie_vip_scoreboard", uvm_component parent=null);
		super.new(name, parent);
	endfunction : new

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// Get the configuration object to access the configuration registers
	    if(!uvm_config_db #(pcie_vip_config)::get(this,"","CFG_ENV",cfg))
	      `uvm_fatal("build_phase","unable to get configuration object in sb")

	  	sb_export_tx=new("sb_export_tx",this);
		sb_fifo_tx=new("sb_fifo_tx",this);

		sb_export_rx=new("sb_export_rx",this);
		sb_fifo_rx=new("sb_fifo_rx",this);

		sb_export_state=new("sb_export_state",this);
		sb_fifo_state=new("sb_fifo_state",this);

	endfunction : build_phase

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		sb_export_tx.connect(sb_fifo_tx.analysis_export);
		sb_export_rx.connect(sb_fifo_rx.analysis_export);
		sb_export_state.connect(sb_fifo_state.analysis_export);
	endfunction : connect_phase

	task run_phase(uvm_phase phase);
		super.run_phase(phase);
		end
	endtask : run_phase
endclass : pcie_vip_scoreboard

`endif