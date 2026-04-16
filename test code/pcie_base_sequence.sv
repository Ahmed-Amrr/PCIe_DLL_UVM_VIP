`ifndef PCIE_BASE_SEQ_SV
`define PCIE_BASE_SEQ_SV

class pcie_base_seq extends uvm_sequence#(pcie_dllp_seq_item);
    `uvm_object_utils(pcie_base_seq)

    `uvm_declare_p_sequencer(pcie_vip_tx_sequencer)

    pcie_vip_config    cfg ;
    pcie_dllp_seq_item item;


    function new(string name = "pcie_base_seq");
        super.new(name);
    endfunction : new

    task pre_body();
      super.pre_body();

      // Get cfg from sequencer
      if (p_sequencer == null)
        `uvm_fatal("SEQ", "No sequencer attached")

      cfg = p_sequencer.cfg;

      if (cfg == null)
        `uvm_fatal("CFG", "cfg is null in sequencer")
    endtask

    virtual task body();
    endtask

endclass 

`endif

