class glue_logic_ds_driver extends uvm_driver;

    `uvm_component_utils(glue_logic_ds_driver)

    virtual lpif_if    lpif_ds_vif;
    pcie_seq_item      s_item_us  ;

    uvm_tlm_analysis_fifo #(pcie_seq_item) fifo_mon_us;

    function new(string name = "glue_logic_ds_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction //new()

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        fifo_mon_us = new("fifo_mon_us", this);
    endfunction

    task run_phase();
        super.run_phase(phase);
        fifo_mon_us.get(s_item_us);
        forever begin
            fifo_mon_us.get(s_item_us);
            @(lpif_ds_vif.drv_cb)
            if (s_item_us.lp_valid != 0) begin
                lpif_ds_vif.drv_cb.pl_data <= s_item_us.lp_data;
            end
        end
    endtask
endclass //glue_logic_driver extends uvm_driver