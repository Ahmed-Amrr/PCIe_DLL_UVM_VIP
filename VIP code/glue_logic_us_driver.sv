class glue_logic_us_driver extends uvm_driver;

    `uvm_component_utils(glue_logic_us_driver)

    virtual lpif_us_if lpif_us_vif;
    pcie_seq_item      s_item_ds  ;

    uvm_tlm_analysis_fifo #(pcie_seq_item) fifo_mon_ds;

    function new(string name = "glue_logic_us_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction //new()

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        fifo_mon_ds = new("fifo_mon_ds", this);
    endfunction

    task run_phase();
        super.run_phase(phase);
        fifo_mon_ds.get(s_item_ds);
        forever begin
            fifo_mon_ds.get(s_item_ds);
            @(lpif_us_vif.drv_cb)
            if (s_item_ds.lp_valid != 0) begin
                lpif_us_vif.drv_cb.pl_data <= s_item_ds.lp_data;
            end
        end
    endtask
endclass //glue_logic_driver extends uvm_driver