`ifndef GLUE_LOGIC_MONITOR_SV
`define GLUE_LOGIC_MONITOR_SV

    class glue_logic_monitor extends uvm_monitor;

        // UVM Factory register
        `uvm_component_utils(glue_logic_monitor)

        // Virtual interface handle
        virtual lpif_if lpif_vif;

        // Handles
        pcie_dllp_seq_item s_item;

        // Analysis port — broadcasts observed transactions to connected subscribers
        uvm_analysis_port #(pcie_dllp_seq_item) mon_ap;

        //==========================================================
        // Constructor
        //==========================================================
        function new(string name = "glue_logic_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        //==========================================================
        // Build Phase - Create analysis port
        //==========================================================
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mon_ap = new("mon_ap", this);
        endfunction

        //==========================================================
        // Run Phase - Sample interface and broadcast each cycle
        //==========================================================
        virtual task run_phase(uvm_phase phase);
            super.run_phase(phase);
            forever begin
                @(lpif_vif.mon_cb)
                    s_item          = pcie_dllp_seq_item::type_id::create("s_item");
                    s_item.dllp     = lpif_vif.mon_cb.lp_data ;
                    s_item.lp_valid = lpif_vif.mon_cb.lp_valid;
                    mon_ap.write(s_item);
            end
        endtask

    endclass : glue_logic_monitor

`endif