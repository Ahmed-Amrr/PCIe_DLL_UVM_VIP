`ifndef V_SEQUENCER
`define V_SEQUENCER 

  class v_sequencer extends uvm_sequencer; 

    `uvm_component_utils(v_sequencer) 
    pcie_vip_tx_sequencer tx_us_sqr; 
    pcie_vip_tx_sequencer tx_ds_sqr; 

    function new(string name = "v_sequencer", uvm_component parent = null); 
      super.new(name, parent); 
    endfunction 

  endclass 

`endif