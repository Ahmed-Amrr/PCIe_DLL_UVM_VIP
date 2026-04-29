`ifndef GLUE_LOGIC_DRIVER_SV
`define GLUE_LOGIC_DRIVER_SV

    class glue_logic_driver extends uvm_driver #(pcie_dllp_seq_item);

        // UVM Factory register
        `uvm_component_utils(glue_logic_driver)

        // Virtual interface handle
        virtual lpif_if lpif_vif;

        // Handles
        pcie_dllp_seq_item s_item ;
        pcie_top_cfg       cfg    ;

        // TLM Analysis Export and FIFO — receives transactions from the paired monitor
        uvm_analysis_export  #(pcie_dllp_seq_item) drv_ex  ;
        uvm_tlm_analysis_fifo#(pcie_dllp_seq_item) drv_fifo;

        //==========================================================
        // Constructor
        //==========================================================
        function new(string name = "glue_logic_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        //==========================================================
        // Build Phase - Create TLM objects and retrieve config
        //==========================================================
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            drv_fifo = new("drv_fifo", this);
            drv_ex   = new("drv_ex",   this);

            // Retrieve the config object from the top test
            if(!uvm_config_db #(pcie_top_cfg)::get(this, "", "top_cfg", cfg))
                `uvm_fatal("CFG", "GL Driver couldn't get config object")
        endfunction

        //==========================================================
        // Connect Phase - Connect export to FIFO
        //==========================================================
        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv_ex.connect(drv_fifo.analysis_export);
        endfunction

        //==========================================================
        // Run Phase - Drive interface signals each clock cycle
        //==========================================================
        task run_phase(uvm_phase phase);
            super.run_phase(phase);
            forever begin
                @(lpif_vif.drv_cb)
                drv_fifo.get(s_item);
                lpif_vif.drv_cb.pl_data <= s_item.dllp;

                // Drive pl_lnk_up low only during link-down test cases
                if (cfg.link_down_test == 1)
                    lpif_vif.drv_cb.pl_lnk_up <= 0;
                else
                    lpif_vif.drv_cb.pl_lnk_up <= 1;       // Normal operation

                // Deassert pl_valid during reset or link-down test cases
                if (cfg.common_reset || cfg.link_down_test)
                    lpif_vif.drv_cb.pl_valid <= 0;
                else
                    lpif_vif.drv_cb.pl_valid <= s_item.lp_valid;

            end
        endtask

    endclass : glue_logic_driver

`endif