class vseq_base extends uvm_sequence; 

  `uvm_object_utils(vseq_base) 

  `uvm_declare_p_sequencer(vsqr) 

  function new(string name="vseq_base"); 
    super.new(name); 
  endfunction 
  
  pcie_vip_tx_sequencer tx_us_sqr; 
  pcie_vip_tx_sequencer tx_ds_sqr;

  virtual task body(); 
    tx_us_sqr = p_sequencer.tx_us_sqr; 
    tx_ds_sqr = p_sequencer.tx_ds_sqr; 
  endtask 

endclass 