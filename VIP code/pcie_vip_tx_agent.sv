`ifndef PCIE_VIP_TX_AGENT
`define PCIE_VIP_TX_AGENT

class pcie_vip_tx_agent extends uvm_agent;

/*-------------------------------------------------------------------------------
-- Interface, port, fields
-------------------------------------------------------------------------------*/
  

/*-------------------------------------------------------------------------------
-- UVM Factory register
-------------------------------------------------------------------------------*/
  // Provide implementations of virtual methods such as get_type_name and create
  `uvm_component_utils(pcie_vip_tx_agent)
  pcie_vip_tx_sequencer sqr;
  pcie_vip_driver drv;
  pcie_vip_tx_monitor tx_mon;
  pcie_vip_config cfg;

  virtual lpif_if lpif_vif;

  uvm_analysis_port #(pcie_dllp_seq_item) tx_agent_ap;  //analysis port declaration

/*-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------*/
  // Constructor
  function new(string name = "pcie_vip_tx_agent", uvm_component parent=null);
    super.new(name, parent);
  endfunction : new


  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    sqr = pcie_vip_tx_sequencer::type_id::create("sqr", this);
    drv = pcie_vip_driver::type_id::create("drv", this);
    tx_mon = pcie_vip_tx_monitor::type_id::create("tx_mon", this);
  
    tx_agent_ap = new("tx_agent_ap", this);
  endfunction : build_phase


  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export); //sqr.seqitem_imp
    tx_mon.tx_mon_ap.connect(tx_agent_ap);
  endfunction : connect_phase

endclass : pcie_vip_tx_agent

`endif // End of include guard
