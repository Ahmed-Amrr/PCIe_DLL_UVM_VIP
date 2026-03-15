class glue_logic_us_monitor extends uvm_monitor;

    `uvm_component_utils(glue_logic_ds_monitor)
    virtual lpif_if    lpif_us_vif;
    pcie_seq_item      s_item_us  ;
    uvm_analysis_port#(pcie_seq_item) mon_ap;
    function new(string name = "glue_logic_ds_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction //new()

    function void build_phase(uvm_phase phase);
        super.build(phase);
        mon_ap = new("mon_ap", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            s_item_us = pcie_seq_item::type_id::create("s_item_us", this);
            @(lpif_us_vif.drv_cb)
            s_item_us.lp_data  = lpif_us_vif.mon_cb.lp_data;
            s_item_us.lp_valid = lpif_us_vif.mon_cb.lp_valid;
            mon_ap.write(s_item_us);
        end
    endtask


endclass //glue_logic_ds_monitor extends uvm_monitor