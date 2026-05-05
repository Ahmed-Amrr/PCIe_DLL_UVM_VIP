`ifndef PCIE_TOP_ENV_SV
`define PCIE_TOP_ENV_SV

class pcie_top_env extends uvm_env;

    // UVM Factory register
    `uvm_component_utils(pcie_top_env)

    // VIP environments — one per side
    pcie_vip_env u_vip;
    pcie_vip_env d_vip;

    // Top-level components
    glue_logic_agent       gl_agt   ;
    pcie_shared_scoreboard shared_sb;

    // Handle
    pcie_top_cfg top_cfg;

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_top_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    //==========================================================
    // Build Phase - Create all sub-components
    //==========================================================
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Retrieve top cfg from the test
        if(!uvm_config_db #(pcie_top_cfg)::get(this, "", "top_cfg", top_cfg))
            `uvm_fatal("build_phase", "Top env unable to get configuration object")

        u_vip     = pcie_vip_env::type_id::create("u_vip",     this);
        d_vip     = pcie_vip_env::type_id::create("d_vip",     this);
        gl_agt    = glue_logic_agent::type_id::create("gl_agt", this);
        shared_sb = pcie_shared_scoreboard::type_id::create("shared_sb", this);
    endfunction : build_phase

    //==========================================================
    // Connect Phase 
    //==========================================================
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect glue logic agent interfaces
        gl_agt.ds_driver.lpif_vif  = top_cfg.d_lpif_vif;
        gl_agt.us_driver.lpif_vif  = top_cfg.u_lpif_vif;
        gl_agt.ds_monitor.lpif_vif = top_cfg.d_lpif_vif;
        gl_agt.us_monitor.lpif_vif = top_cfg.u_lpif_vif;

        // Connect VIP monitor analysis ports to shared scoreboard FIFOs
        u_vip.tx_agent.tx_agent_ap.connect(shared_sb.upper_tx_fifo.analysis_export);
        u_vip.rx_agent.rx_agent_ap.connect(shared_sb.upper_rx_fifo.analysis_export);
        d_vip.tx_agent.tx_agent_ap.connect(shared_sb.lower_tx_fifo.analysis_export);
        d_vip.rx_agent.rx_agent_ap.connect(shared_sb.lower_rx_fifo.analysis_export);

        // Connect state machine analysis ports to shared scoreboard FIFOs
        u_vip.state_machine.sm_ap.connect(shared_sb.upper_sm_fifo.analysis_export);
        d_vip.state_machine.sm_ap.connect(shared_sb.lower_sm_fifo.analysis_export);

        // Connect TX / RX / SM monitors to each side's passive driver
        u_vip.tx_agent.tx_agent_ap.connect(u_vip.passive_driver.mon_imp_tx);
        u_vip.rx_agent.rx_agent_ap.connect(u_vip.passive_driver.mon_imp_rx);
        u_vip.state_machine.sm_ap.connect(u_vip.passive_driver.mon_imp_sm);

        d_vip.tx_agent.tx_agent_ap.connect(d_vip.passive_driver.mon_imp_tx);
        d_vip.rx_agent.rx_agent_ap.connect(d_vip.passive_driver.mon_imp_rx);
        d_vip.state_machine.sm_ap.connect(d_vip.passive_driver.mon_imp_sm);

        // Connect passive driver interfaces and cfg handles
        u_vip.passive_driver.lpif_vif    = top_cfg.u_lpif_vif;
        d_vip.passive_driver.lpif_vif    = top_cfg.d_lpif_vif;
        u_vip.passive_driver.passive_vif = top_cfg.u_p_vif   ;
        d_vip.passive_driver.passive_vif = top_cfg.d_p_vif   ;
        u_vip.passive_driver.cfg         = u_vip.cfg         ;
        d_vip.passive_driver.cfg         = d_vip.cfg         ;

    endfunction : connect_phase

    //==========================================================
    // Run Phase - Propagate randomized reset to both VIP cfgs
    //==========================================================
    task run_phase(uvm_phase phase);
        super.run_phase(phase);

        forever begin
            @(posedge top_cfg.d_lpif_vif.lclk)
            assert(top_cfg.randomize());
            u_vip.cfg.reset = top_cfg.common_reset;
            d_vip.cfg.reset = top_cfg.common_reset;
        end
    endtask : run_phase

endclass

`endif
