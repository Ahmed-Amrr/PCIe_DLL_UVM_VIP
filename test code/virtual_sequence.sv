`ifndef V_SEQUENCE
`define V_SEQUENCE 

  class vseq_base extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(vseq_base)

    `uvm_declare_p_sequencer(v_sequencer)

    // Sequences to run 
    pcie_base_seq us_seq;
    pcie_base_seq ds_seq;

    pcie_vip_tx_sequencer us_sqr;
    pcie_vip_tx_sequencer ds_sqr;

    function new(string name = "vseq_base");
      super.new(name);
    endfunction

    task body();

      us_sqr = p_sequencer.tx_us_sqr;
      ds_sqr = p_sequencer.tx_ds_sqr;

      fork
        begin
          if (us_seq != null)
            us_seq.start(us_sqr);
        end
        begin
          if (ds_seq != null)
            ds_seq.start(ds_sqr);
        end
      join

    endtask
  endclass 

`endif