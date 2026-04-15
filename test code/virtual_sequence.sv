`ifndef V_SEQUENCE
`define V_SEQUENCE 

  class vseq_base extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(vseq_base)

    `uvm_declare_p_sequencer(v_sequencer)

    // Sequences to run 
    pcie_base_seq us_seq;
    pcie_base_seq ds_seq;

    task body();

      fork
        if (us_seq != null) us_seq.start(p_sequencer.tx_us_sqr);
        if (ds_seq != null) ds_seq.start(p_sequencer.tx_ds_sqr);
      join

    endtask
  endclass 

`endif