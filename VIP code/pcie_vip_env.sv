`ifndef PCIE_VIP_ENV
`define PCIE_VIP_ENV

class pcie_vip_env extends  uvm_env;

/*-------------------------------------------------------------------------------
-- Interface, port, fields
-------------------------------------------------------------------------------*/
	

/*-------------------------------------------------------------------------------
-- UVM Factory register
-------------------------------------------------------------------------------*/
	// Provide implementations of virtual methods such as get_type_name and create
	`uvm_component_utils(pcie_vip_env)
	pcie_vip_tx_agent tx_agent;
	pcie_vip_rx_agent rx_agent;
	pcie_vip_scoreboard scoreboard;
	pcie_vip_coverage coverage;

/*-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------*/
	// Constructor
	function new(string name = "pcie_vip_env", uvm_component parent=null);
		super.new(name, parent);
	endfunction : new

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		tx_agent = pcie_vip_tx_agent::type_id::create("tx_agent", this);
		rx_agent = pcie_vip_rx_agent::type_id::create("rx_agent", this);
		scoreboard = pcie_vip_scoreboard::type_id::create("scoreboard", this);
		coverage = pcie_vip_coverage::type_id::create("coverage", this);
	endfunction : build_phase

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		tx_agent.tx_agent_ap.connect(/*coverage.cov_export*/);	//////////
		tx_agent.tx_agent_ap.connect(/*scoreboard.sb_imp*/);	//////////
		rx_agent.rx_agent_ap.connect(/*coverage.cov_export*/);	//////////
		rx_agent.rx_agent_ap.connect(/*scoreboard.sb_imp*/);	//////////
		// na2s connection el State machine 
	endfunction : connect_phase

endclass : pcie_vip_env
`endif // End of include guard