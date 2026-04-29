`ifndef PCIE_BASE_SEQUENCE_SV
`define PCIE_BASE_SEQUENCE_SV

class pcie_base_seq extends uvm_sequence #(pcie_dllp_seq_item);

    // UVM Factory register and callback / sequencer declarations
    `uvm_object_utils(pcie_base_seq)
    `uvm_register_cb(pcie_base_seq, pcie_seq_cb)
    `uvm_declare_p_sequencer(pcie_vip_tx_sequencer)

    // Handles
    pcie_vip_config    cfg ;
    pcie_dllp_seq_item item;

    // External task declarations
    extern virtual task send_feat_dllp(input dllp_type_t pkt_type, input pcie_dllp_seq_item item);
    extern virtual task send_fc_dllp  (input dllp_type_t pkt_type, input fc_type_t fc_type, input pcie_dllp_seq_item item);
    extern virtual task reset         ();

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_base_seq");
        super.new(name);
    endfunction : new

    //==========================================================
    // Pre Body - Retrieve cfg from attached sequencer
    //==========================================================
    task pre_body();
        super.pre_body();

        if (p_sequencer == null)
            `uvm_fatal("SEQ", "No sequencer attached")

        cfg = p_sequencer.cfg;

        if (cfg == null)
            `uvm_fatal("CFG", "cfg is null in sequencer")
    endtask : pre_body

endclass : pcie_base_seq

//==========================================================
// send_feat_dllp
//==========================================================
// Task: Packs local feature bits and the remote valid (Ack) bit into the DLLP
// used in the feature exchange phase of link initialization
// Inputs: the type of FC DLLP to send (pkt_type) and the type of FC to index the credit arrays (fc_type)
task pcie_base_seq::send_feat_dllp(input dllp_type_t pkt_type, input pcie_dllp_seq_item item);
    item = pcie_dllp_seq_item::type_id::create("item");

    start_item(item);
        item.dllp[47:40] = pkt_type;
        item.dllp[38:16] = cfg.local_register_feature.local_feature_supported;
        item.dllp[39]    = cfg.remote_register_feature.remote_feature_valid;   // Ack bit
    finish_item(item);
endtask : send_feat_dllp

//==========================================================
// send_fc_dllp 
//==========================================================
// Task  : Packs scaled credit values from the local_fc_credits_register into the DLLP
// Inputs: the type of FC DLLP to send (pkt_type) and the type of FC to index the credit arrays (fc_type)
task pcie_base_seq::send_fc_dllp(input dllp_type_t pkt_type, input fc_type_t fc_type, input pcie_dllp_seq_item item);
    item = pcie_dllp_seq_item::type_id::create("item");

    start_item(item);
        if ((p_sequencer.state == DL_INIT1) || (p_sequencer.state == DL_INIT2)) begin
            item.dllp[47:40] = pkt_type;

            // Scale fields
            item.dllp[39:38] = cfg.local_fc_credits_register.hdr_scale  [fc_type];
            item.dllp[29:28] = cfg.local_fc_credits_register.data_scale [fc_type];

            // Credit fields
            item.dllp[37:30] = cfg.local_fc_credits_register.hdr_credits [fc_type];
            item.dllp[27:16] = cfg.local_fc_credits_register.data_credits[fc_type];
        end
    finish_item(item);
endtask : send_fc_dllp

//==========================================================
// Reset 
//==========================================================
// Task: Assert cfg reset flag through a sequence item 
// to drive the reset signal in the passive driver
task pcie_base_seq::reset();
    item = pcie_dllp_seq_item::type_id::create("item");

    start_item(item);
        cfg.reset = 1;
    finish_item(item);
endtask : reset

`endif