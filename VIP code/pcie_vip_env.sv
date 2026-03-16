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
	pcie_state_machine state_machine;

	pcie_vip_config cfg;

/*-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------*/
	// Constructor
	function new(string name = "pcie_vip_env", uvm_component parent=null);
		super.new(name, parent);
	endfunction : new

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// Get interface to assign it to the driver and the monitor's virtual interface
	    if(!uvm_config_db #(pcie_vip_config)::get(this,"","CFG",cfg))
	      `uvm_fatal("build_phase","unable to get configuration object in VIP ENV")

	  	//setting the configuration object to get the configuration registers in the scoreboard and State machine components
	  	uvm_config_db#(pcie_vip_config)::set(this, "*", "CFG_ENV", cfg);

		tx_agent = pcie_vip_tx_agent::type_id::create("tx_agent", this);
		rx_agent = pcie_vip_rx_agent::type_id::create("rx_agent", this);
		scoreboard = pcie_vip_scoreboard::type_id::create("scoreboard", this);
		coverage = pcie_vip_coverage::type_id::create("coverage", this);
		state_machine = pcie_state_machine::type_id::create("state_machine", this);
	endfunction : build_phase

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		tx_agent.tx_agent_ap.connect(/*coverage.cov_export*/);	//////////
		tx_agent.tx_agent_ap.connect(/*scoreboard.sb_imp*/);	//////////
		tx_agent.tx_agent_ap.connect(state_machine.sm_export_tx);
		rx_agent.rx_agent_ap.connect(/*coverage.cov_export*/);	//////////
		rx_agent.rx_agent_ap.connect(/*scoreboard.sb_imp*/);	//////////
		rx_agent.rx_agent_ap.connect(state_machine.sm_export_rx);

		//connecting interface to the divers and monitors of each agent
		tx_agent.drv.lpif_vif=cfg.lpif_vif;
		tx_agent.tx_mon.lpif_vif=cfg.lpif_vif;
		rx_agent.rx_mon.lpif_vif=cfg.lpif_vif;
	endfunction : connect_phase

endclass : pcie_vip_env
`endif // End of include guard