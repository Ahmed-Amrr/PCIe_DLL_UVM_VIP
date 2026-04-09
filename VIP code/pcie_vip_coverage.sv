`ifndef PCIE_VIP_COVERAGE
`define PCIE_VIP_COVERAGE

class pcie_vip_coverage extends uvm_component;

/*-------------------------------------------------------------------------------
-- UVM Factory register
-------------------------------------------------------------------------------*/
	// Provide implementations of virtual methods such as get_type_name and create
	`uvm_component_utils(pcie_vip_coverage)

/*-------------------------------------------------------------------------------
-- Interface, port, fields
-------------------------------------------------------------------------------*/
	uvm_analysis_export #(pcie_dllp_seq_item) cov_export_tx;		//getting the data from tx monitor
	uvm_tlm_analysis_fifo #(pcie_dllp_seq_item) cov_fifo_tx;

	pcie_dllp_seq_item seq_item_tx;

	uvm_analysis_export #(pcie_dllp_seq_item) cov_export_rx;		//getting the data from rx monitor
	uvm_tlm_analysis_fifo #(pcie_dllp_seq_item) cov_fifo_rx;

	pcie_dllp_seq_item seq_item_rx;

	pcie_vip_config cfg;										//to get the configuration registers
/*-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------*/
	// Constructor
	function new(string name = "pcie_vip_coverage", uvm_component parent=null);
		super.new(name, parent);
	endfunction : new

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// Get the configuration object to access the configuration registers
	    if(!uvm_config_db #(pcie_vip_config)::get(this,"","CFG_ENV",cfg))
	      `uvm_fatal("build_phase","unable to get configuration object in cov")

	  	cov_export_tx=new("cov_export_tx",this);
		cov_fifo_tx=new("cov_fifo_tx",this);

		cov_export_rx=new("cov_export_rx",this);
		cov_fifo_rx=new("cov_fifo_rx",this);

	endfunction : build_phase

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		cov_export_tx.connect(cov_fifo_tx.analysis_export);
		cov_export_rx.connect(cov_fifo_rx.analysis_export);
	endfunction : connect_phase

	task run_phase(uvm_phase phase);
		super.run_phase(phase);
	endtask : run_phase
endclass : pcie_vip_coverage

`endif