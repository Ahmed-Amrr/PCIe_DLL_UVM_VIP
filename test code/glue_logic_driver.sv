`ifndef GLUE_LOGIC_DRIVER
`define GLUE_LOGIC_DRIVER 

    class glue_logic_driver extends uvm_driver #(pcie_dllp_seq_item);

        `uvm_component_utils(glue_logic_driver)

        virtual lpif_if lpif_vif;

        pcie_dllp_seq_item s_item;
        pcie_top_cfg cfg;

        uvm_tlm_analysis_fifo #(pcie_dllp_seq_item) fifo_mon;

        function new(string name = "glue_logic_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction //new()

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            fifo_mon = new("fifo_mon", this);

            // Retreving the cfg object from the top test
            if(!uvm_config_db #(pcie_top_cfg)::get(this, "", "top_cfg", cfg))
                `uvm_fatal("CFG", "GL Driver couldn't get config object ")
        endfunction

        task run_phase();
            super.run_phase(phase);

            forever begin
                fifo_mon.get(s_item);
                @(lpif_vif.drv_cb)
                if (s_item.rst_req == 1) begin
                    lpif_vif.drv_cb.reset <= 1;
                end
                if (cfg.link_down_test == 0) begin              // Normal operation 
                    lpif_vif.drv_cb.pl_lnk_up <= 1;
                    lpif_vif.drv_cb.pl_data <= s_item.lp_data;

                    if (cfg.pl_valid_off) begin                 // Valid off testcases
                        lpif_vif.drv_cb.pl_valid <= 0;
                    end else begin
                        lpif_vif.drv_cb.pl_valid <= 1;
                    end 
                end else if (cfg.link_down_test) begin          // Linkup = 0 testcases
                    lpif_vif.drv_cb.pl_lnk_up <= 0;
                end 
            end

        endtask
    endclass 

`endif