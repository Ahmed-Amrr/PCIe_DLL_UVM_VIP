`ifndef VIP_RX_AGENT
`define VIP_RX_AGENT

class vip_rx_agent extends uvm_agent;

/*-------------------------------------------------------------------------------
-- Interface, port, fields
-------------------------------------------------------------------------------*/
  

/*-------------------------------------------------------------------------------
-- UVM Factory register
-------------------------------------------------------------------------------*/
  // Provide implementations of virtual methods such as get_type_name and create
  `uvm_component_utils(vip_rx_agent)
  vip_rx_monitor rx_mon;
  vip_config vip_cfg;

  virtual vip_if vip_vif;

  uvm_analysis_port #(vip_seq_item) rx_agent_ap;  //analysis port declaration

/*-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------*/
  // Constructor
  function new(string name = "vip_rx_agent", uvm_component parent=null);
    super.new(name, parent);
  endfunction : new


  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get interface 
    if(!uvm_config_db #(vip_config)::get(this,"","CFG",vip_cfg))
      `uvm_fatal("build_phase","unable to get configuration object")

    rx_mon = vip_rx_monitor::type_id::create("rx_mon", this);
  
    rx_agent_ap = new("rx_agent_ap", this);
  endfunction : build_phase


  function void connect_phase(uvm_phase phase);
    rx_mon.vip_vif=vip_cfg.vip_vif;
    rx_mon.rx_mon_ap.connect(rx_agent_ap);
  endfunction : connect_phase

endclass : vip_rx_agent

`endif // End of include guard
