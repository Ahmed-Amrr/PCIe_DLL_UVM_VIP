`ifndef VIP_ENV
`define VIP_ENV

class vip_env extends  uvm_env;

/*-------------------------------------------------------------------------------
-- Interface, port, fields
-------------------------------------------------------------------------------*/
	

/*-------------------------------------------------------------------------------
-- UVM Factory register
-------------------------------------------------------------------------------*/
	// Provide implementations of virtual methods such as get_type_name and create
	`uvm_component_utils(vip_env)
	vip_tx_agent tx_agent;
	vip_rx_agent rx_agent;
	vip_scoreboard scoreboard;
	vip_coverage coverage;

/*-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------*/
	// Constructor
	function new(string name = "vip_env", uvm_component parent=null);
		super.new(name, parent);
	endfunction : new

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		tx_agent = vip_tx_agent::type_id::create("tx_agent", this);
		rx_agent = vip_rx_agent::type_id::create("rx_agent", this);
		scoreboard = vip_scoreboard::type_id::create("scoreboard", this);
		coverage = vip_coverage::type_id::create("coverage", this);
	endfunction : build_phase

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		tx_agent.tx_agent_ap.connect(/*coverage.cov_export*/);	//////////
		tx_agent.tx_agent_ap.connect(/*scoreboard.sb_imp*/);	//////////
		rx_agent.rx_agent_ap.connect(/*coverage.cov_export*/);	//////////
		rx_agent.rx_agent_ap.connect(/*scoreboard.sb_imp*/);	//////////
		// na2s connection el State machine 
	endfunction : connect_phase

endclass : vip_env
`endif // End of include guard