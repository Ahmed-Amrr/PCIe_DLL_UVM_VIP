`ifndef PCIE_PASSIVE_DRIVER
`define PCIE_PASSIVE_DRIVER 

    class pcie_passive_driver extends uvm_driver #(pcie_dllp_seq_item);

        `uvm_component_utils(pcie_passive_driver)

        virtual passive_interface passive_vif;
        virtual lpif_if    lpif_vif;
        pcie_vip_config    cfg;

        pcie_dllp_seq_item s_item_rx;
        pcie_dllp_seq_item s_item_tx;
        pcie_state_seq_item  s_item_sm;

        uvm_tlm_analysis_fifo #(pcie_dllp_seq_item) fifo_mon_rx;
        uvm_tlm_analysis_fifo #(pcie_dllp_seq_item) fifo_mon_tx;
        uvm_tlm_analysis_fifo #(pcie_state_seq_item) fifo_mon_sm;

        function new(string name = "pcie_passive_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction //new()

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            fifo_mon_rx = new("fifo_mon_rx", this);
            fifo_mon_tx = new("fifo_mon_tx", this);
            fifo_mon_sm = new("fifo_mon_sm", this);
            // Retreving the cfg object from the vip config
            if(!uvm_config_db #(pcie_vip_config)::get(this, "", "vip_cfg", cfg))
                `uvm_fatal("CFG", "Passive Driver couldn't get config object ")

            if(!uvm_config_db #(virtual passive_interface)::get(this, "", "passive_vif", passive_vif))
                `uvm_fatal("CFG", "Passive Driver couldn't get passive_vif")

            if(!uvm_config_db #(virtual lpif_if)::get(this, "", "lpif_vif", lpif_vif))
                `uvm_fatal("CFG", "Passive Driver couldn't get lpif_vif")
        endfunction

        task run_phase(uvm_phase phase);
            super.run_phase(phase);
            forever begin
                fifo_mon_rx.get(s_item_rx);
                fifo_mon_tx.get(s_item_tx);
                fifo_mon_sm.get(s_item_sm);
                @(lpif_vif.drv_cb);
                passive_vif.tx_dllp   = s_item_tx.dllp;
                passive_vif.rx_dllp   = s_item_rx.dllp;
                passive_vif.reset     = s_item_tx.reset;
                passive_vif.pl_lnk_up = s_item_tx.pl_lnk_up; 
                passive_vif.state     = s_item_sm.vip_state;
                passive_vif.DL_Up     = s_item_sm.DL_Up;
                passive_vif.DL_Down   = s_item_sm.DL_Down;
                passive_vif.fi1_flag  = s_item_sm.FI1;
                passive_vif.fi2_flag  = s_item_sm.FI2;
                passive_vif.scaled_fc_active  = s_item_sm.scaled_fc_active;
                passive_vif.local_register_feature = cfg.local_register_feature;
                passive_vif.remote_register_feature = cfg.remote_register_feature;
                passive_vif.feature_exchange_cap = cfg.feature_exchange_cap;
                passive_vif.fc_credits_register = cfg.fc_credits_register;
            end
        endtask
    endclass 

`endif