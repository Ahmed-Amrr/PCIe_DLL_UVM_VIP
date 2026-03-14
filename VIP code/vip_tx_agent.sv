`ifndef VIP_TX_AGENT
`define VIP_TX_AGENT

class vip_tx_agent extends uvm_agent;

/*-------------------------------------------------------------------------------
-- Interface, port, fields
-------------------------------------------------------------------------------*/
  

/*-------------------------------------------------------------------------------
-- UVM Factory register
-------------------------------------------------------------------------------*/
  // Provide implementations of virtual methods such as get_type_name and create
  `uvm_component_utils(vip_tx_agent)
  vip_sequencer sqr;
  vip_driver drv;
  vip_tx_monitor tx_mon;
  vip_config vip_cfg;

  virtual vip_if vip_vif;

  uvm_analysis_port #(vip_seq_item) tx_agent_ap;  //analysis port declaration

/*-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------*/
  // Constructor
  function new(string name = "vip_tx_agent", uvm_component parent=null);
    super.new(name, parent);
  endfunction : new


  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get interface 
    if(!uvm_config_db #(vip_config)::get(this,"","CFG",vip_cfg))
      `uvm_fatal("build_phase","unable to get configuration object")

    sqr = vip_sequencer::type_id::create("sqr", this);
    drv = vip_driver::type_id::create("drv", this);
    tx_mon = vip_tx_monitor::type_id::create("tx_mon", this);
  
    tx_agent_ap = new("tx_agent_ap", this);
  endfunction : build_phase


  function void connect_phase(uvm_phase phase);
    drv.vip_vif=vip_cfg.vip_vif;
    tx_mon.vip_vif=vip_cfg.vip_vif;
    drv.seq_item_port.connect(sqr.seq_item_export); //sqr.seqitem_imp
    tx_mon.tx_mon_ap.connect(tx_agent_ap);
  endfunction : connect_phase

endclass : vip_tx_agent

`endif // End of include guard
