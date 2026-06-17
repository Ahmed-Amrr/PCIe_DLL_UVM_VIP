`ifndef PCIE_VIP_ENV
`define PCIE_VIP_ENV

class pcie_vip_env extends  uvm_env;

// UVM Factory register
	`uvm_component_utils(pcie_vip_env)
	pcie_vip_tx_agent tx_agent;
	pcie_vip_rx_agent rx_agent;
	dll_vip_scoreboard scoreboard;
	pcie_vip_coverage coverage;
	pcie_vip_state_machine state_machine;
	pcie_passive_driver passive_driver;

	pcie_vip_config cfg;


    // Functions
	// Constructor
	function new(string name = "pcie_vip_env", uvm_component parent=null);
		super.new(name, parent);
	endfunction : new

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// Get the shared VIP configuration object used by the scoreboard and state machine.
	    if(!uvm_config_db #(pcie_vip_config)::get(this,"","vip_cfg",cfg))
	      `uvm_fatal("build_phase","unable to get configuration object in VIP ENV")

	  	// Make the same configuration object visible to child components through the UVM config DB.
	  	uvm_config_db#(pcie_vip_config)::set(this, "*", "CFG_ENV", cfg);

		tx_agent = pcie_vip_tx_agent::type_id::create("tx_agent", this);
		rx_agent = pcie_vip_rx_agent::type_id::create("rx_agent", this);
		scoreboard = dll_vip_scoreboard::type_id::create("scoreboard", this);
		coverage = pcie_vip_coverage::type_id::create("coverage", this);
		state_machine = pcie_vip_state_machine::type_id::create("state_machine", this);
		passive_driver = pcie_passive_driver::type_id::create("passive_driver", this);
	endfunction : build_phase

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		tx_agent.tx_agent_ap.connect(coverage.cov_export_tx);	
		tx_agent.tx_agent_ap.connect(scoreboard.tx_mon_export);	
		tx_agent.tx_agent_ap.connect(state_machine.sm_export_tx);
		rx_agent.rx_agent_ap.connect(coverage.cov_export_rx);	
		rx_agent.rx_agent_ap.connect(scoreboard.rx_mon_export);	
		rx_agent.rx_agent_ap.connect(state_machine.sm_export_rx);
		state_machine.sm_ap.connect(coverage.cov_export_sm);
		state_machine.sm_ap.connect(scoreboard.sm_mon_export);
		state_machine.sm_ap.connect(tx_agent.sqr.sqr_export);

		// Bind the shared LPIF interface to the active driver and monitors.
		tx_agent.drv.lpif_vif=cfg.lpif_vif;
		tx_agent.tx_mon.lpif_vif=cfg.lpif_vif;
		rx_agent.rx_mon.lpif_vif=cfg.lpif_vif;

	endfunction : connect_phase

	virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
        	@(posedge cfg.lpif_vif.lclk)
        	assert(cfg.randomize());
        end
    endtask

endclass : pcie_vip_env
`endif
