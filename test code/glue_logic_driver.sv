class glue_logic_driver extends uvm_driver;

    `uvm_component_utils(glue_logic_driver)

    virtual lpif_if    lpif_vif;
    pcie_seq_item      s_item  ;
    pcie_top_cfg       cfg     ;

    uvm_tlm_analysis_fifo #(pcie_seq_item) fifo_mon;

    function new(string name = "glue_logic_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction //new()

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        fifo_mon = new("fifo_mon", this);
        if(!uvm_config_db #(pcie_top_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("CFG", "Config object not found")
    endfunction

    task run_phase();
        super.run_phase(phase);
        fifo_mon.get(s_item);
        forever begin
            fifo_mon.get(s_item);
            @(lpif_vif.drv_cb)
            if (cfg.link_down_test == 0) begin
                lpif_vif.drv_cb.pl_lnk_up <= 1;
                if (s_item.lp_valid) begin
                    lpif_vif.drv_cb.pl_data <= s_item.lp_data;
                end
                if (cfg.pl_valid_off) begin
                    lpif_vif.drv_cb.pl_valid <= 0;
                end else begin
                    lpif_vif.drv_cb.pl_valid <= 1;
                end 
            end else if (cfg.link_down_test) begin
                lpif_vif.drv_cb.pl_lnk_up <= 0;
            end 
        end
    endtask
endclass 