`ifndef PCIE_PASSIVE_DRIVER
`define PCIE_PASSIVE_DRIVER 

    // Declare separate analysis imp macros for each port
    `uvm_analysis_imp_decl(_rx)
    `uvm_analysis_imp_decl(_tx)
    `uvm_analysis_imp_decl(_sm)

    class pcie_passive_driver extends uvm_driver#(pcie_dllp_seq_item);

        `uvm_component_utils(pcie_passive_driver)

        virtual passive_interface passive_vif;
        virtual lpif_if    lpif_vif;
        pcie_vip_config    cfg;

        pcie_dllp_seq_item   s_item_rx;
        pcie_dllp_seq_item   s_item_tx;
        pcie_state_seq_item  s_item_sm;

        // Use suffixed imp types matching the macros declared above
        uvm_analysis_imp_rx #(pcie_dllp_seq_item, pcie_passive_driver)   mon_imp_rx; 
        uvm_analysis_imp_tx #(pcie_dllp_seq_item, pcie_passive_driver)   mon_imp_tx; 
        uvm_analysis_imp_sm #(pcie_state_seq_item, pcie_passive_driver)  mon_imp_sm; 

        function new(string name = "pcie_passive_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mon_imp_rx = new("mon_imp_rx", this);
            mon_imp_tx = new("mon_imp_tx", this);
            mon_imp_sm = new("mon_imp_sm", this);

        endfunction

        // Write callback for RX items
        function void write_rx(pcie_dllp_seq_item item);
            s_item_rx = item;
        endfunction

        // Write callback for TX items
        function void write_tx(pcie_dllp_seq_item item);
            s_item_tx = item;
        endfunction

        // Write callback for state machine items
        function void write_sm(pcie_state_seq_item item);
            s_item_sm = item;
        endfunction

        task run_phase(uvm_phase phase);
            super.run_phase(phase);
            forever begin
                @(lpif_vif.drv_cb);
                if (s_item_rx != null && s_item_tx != null && s_item_sm != null) begin
                    // Drive all passive interface signals
                    passive_vif.tx_dllp                    <= s_item_tx.dllp;
                    passive_vif.rx_dllp                    <= s_item_rx.dllp;
                    passive_vif.reset                      <= cfg.reset;
                    passive_vif.pl_lnk_up                  <= s_item_rx.pl_lnk_up;
                    passive_vif.state                      <= s_item_sm.vip_state;
                    passive_vif.DL_Up                      <= s_item_sm.DL_Up;
                    passive_vif.DL_Down                    <= s_item_sm.DL_Down;
                    passive_vif.fi1_flag                   <= s_item_sm.FI1;
                    passive_vif.fi2_flag                   <= s_item_sm.FI2;
                    passive_vif.scaled_fc_active           <= cfg.scaled_fc_active;
                    passive_vif.local_register_feature     <= cfg.local_register_feature;
                    passive_vif.remote_register_feature    <= cfg.remote_register_feature;
                    passive_vif.feature_exchange_cap       <= cfg.feature_exchange_cap;
                    passive_vif.local_fc_credits_register  <= cfg.local_fc_credits_register;
                    passive_vif.remote_fc_credits_register <= cfg.remote_fc_credits_register;
                    passive_vif.lp_data                    <= lpif_vif.lp_data;
                    passive_vif.lp_valid                   <= lpif_vif.lp_valid;
                    passive_vif.pl_valid                   <= lpif_vif.pl_valid;
                    passive_vif.pl_data                    <= lpif_vif.pl_data;

                    passive_vif.init1_p_f                  <=s_item_sm.init1_p_f;
                    passive_vif.init1_np_f                 <=s_item_sm.init1_np_f;
                    passive_vif.init1_cpl_f                <=s_item_sm.init1_cpl_f;

                end
            end
            
        endtask

    endclass 

`endif

