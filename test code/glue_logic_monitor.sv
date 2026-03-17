`ifndef GLUE_LOGIC_MONITOR
`define GLUE_LOGIC_MONITOR
class glue_logic_monitor extends uvm_monitor;

    // UVM Factory register
    `uvm_component_utils(glue_logic_monitor)
    virtual lpif_if    lpif_vif;
    pcie_seq_item      s_item  ;
    
    uvm_analysis_port#(pcie_seq_item) mon_ap;
    
    function new(string name = "glue_logic_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction //new()

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon_ap = new("mon_ap", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            s_item_ds = pcie_seq_item::type_id::create("s_item", this);
            @(lpif_vif.drv_cb)
            s_item.lp_data = lpif_vif.mon_cb.lp_data;
            s_item.lp_valid = lpif_vif.mon_cb.lp_valid;
            mon_ap.write(s_item);
        end
    endtask

endclass //glue_logic_monitor extends uvm_monitor
`endif