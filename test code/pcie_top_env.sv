`ifndef PCIE_TOP_ENV
`define PCIE_TOP_ENV

    class pcie_top_env extends uvm_env;

        // Provide implementations of virtual methods 
        `uvm_component_utils(pcie_top_env)

        pcie_vip_env u_vip;
        pcie_vip_env d_vip;

        glue_logic_agent gl_agt;
        pcie_shared_scoreboard shared_sb;

        pcie_top_cfg top_cfg;

        // Constructor
        function new(string name = "pcie_top_env", uvm_component parent=null);
            super.new(name, parent);
        endfunction : new

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            if(!uvm_config_db #(pcie_top_cfg)::get(this,"","top_cfg",top_cfg))
                `uvm_fatal("build_phase","Top env unable to get configuration object")

            u_vip = pcie_top_env::type_id::create("u_vip",this);
            d_vip = pcie_top_env::type_id::create("d_vip",this);
            gl_agt = pcie_top_env::type_id::create("gl_agt",this);
            shared_sb = pcie_top_env::type_id::create("shared_sb",this);

        endfunction : build_phase

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);

            // connect interfaces with the Glue logic
            gl_agt.ds_driver = top_cfg.d_lpif_vif;
            gl_agt.us_driver = top_cfg.u_lpif_vif;
            gl_agt.ds_monitor = top_cfg.d_lpif_vif;
            gl_agt.us_monitor = top_cfg.u_lpif_vif;

            // connect vip monitors with the shared scoreboard
            u_vip.tx_agent.tx_agent_ap.connect(shared_sb.upper_tx_fifo.analysis_export);
            u_vip.rx_agent.rx_agent_ap.connect(shared_sb.upper_rx_fifo.analysis_export);
            d_vip.tx_agent.tx_agent_ap.connect(shared_sb.lower_tx_fifo.analysis_export);
            d_vip.rx_agent.rx_agent_ap.connect(shared_sb.lower_rx_fifo.analysis_export);

            // connect each state machine with the shared scoreboard 
            u_vip.state_machine.sm_ap.connect(shared_sb.upper_sm_fifo.analysis_export);
            d_vip.state_machine.sm_ap.connect(shared_sb.lower_sm_fifo.analysis_export);
        endfunction : connect_phase
    
    endclass 

`endif