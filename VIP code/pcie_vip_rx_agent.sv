`ifndef PCIE_VIP_RX_AGENT
`define PCIE_VIP_RX_AGENT

class pcie_vip_rx_agent extends uvm_agent;

/*-------------------------------------------------------------------------------
-- Interface, port, fields
-------------------------------------------------------------------------------*/
  

/*-------------------------------------------------------------------------------
-- UVM Factory register
-------------------------------------------------------------------------------*/
  // Provide implementations of virtual methods such as get_type_name and create
  `uvm_component_utils(pcie_vip_rx_agent)
  pcie_vip_rx_monitor rx_mon;
  pcie_vip_config cfg;

  virtual lpif_if lpif_vif;

  uvm_analysis_port #(/*pcie_vip_seq_item*/) rx_agent_ap;  //analysis port declaration

/*-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------*/
  // Constructor
  function new(string name = "pcie_vip_rx_agent", uvm_component parent=null);
    super.new(name, parent);
  endfunction : new


  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    rx_mon = pcie_vip_rx_monitor::type_id::create("rx_mon", this);
  
    rx_agent_ap = new("rx_agent_ap", this);
  endfunction : build_phase


  function void connect_phase(uvm_phase phase);
    rx_mon.rx_mon_ap.connect(rx_agent_ap);
  endfunction : connect_phase

endclass : pcie_vip_rx_agent

`endif // End of include guard
