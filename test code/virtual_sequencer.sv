class vsqr extends uvm_sequencer; 

  `uvm_component_utils(vsqr) 
  tx_us_sequencer tx_us_sqr; 
  tx_ds_sequencer tx_ds_sqr; 

  function new(string name = "vsqr", uvm_component parent = null); 
    super.new(name, parent); 
  endfunction 

  function void end_of_elaboration_phase(uvm_phase phase); 
    super.end_of_elaboration_phase(phase); 

    if (!uvm_config_db#(tx_us_sequencer)::get(this, "tx_us_sqr", "", tx_us_sqr)) begin 
        `uvm_fatal("VSQR", "No tx_us_sqr specified for this instance"); 
    end 

    if (!uvm_config_db#(tx_ds_sequencer)::get(this, "tx_ds_sqr", "", tx_ds_sqr)) begin 
        `uvm_fatal("VSQR", "No tx_ds_sqr specified for this instance"); 
    end 
  endfunction 
endclass 