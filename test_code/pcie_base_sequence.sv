`ifndef PCIE_BASE_SEQ
`define PCIE_BASE_SEQ 

  class pcie_base_seq extends uvm_sequence#(pcie_dllp_seq_item);
    `uvm_object_utils(pcie_base_seq)

    `uvm_declare_p_sequencer(pcie_vip_tx_sequencer)

    pcie_vip_config cfg;
    pcie_dllp_seq_item item;

    extern virtual task send_feat_dllp (input dllp_type_t pkt_type, pcie_dllp_seq_item item);
    extern virtual task send_fc_dllp(dllp_type_t pkt_type, fc_type_t fc_type, pcie_dllp_seq_item item);

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

  endclass 


    // send_fc_dllp
  task pcie_base_seq::send_feat_dllp (input dllp_type_t pkt_type, pcie_dllp_seq_item item);
      item = pcie_dllp_seq_item::type_id::create("item");

      start_item(item);
      item.dllp[47:40] = pkt_type; 
      item.dllp[38:16] = cfg.local_register_feature.local_feature_supported;
      // We mirror the remote valid bit back as our Ack
      item.dllp[39]    = cfg.remote_register_feature.remote_feature_valid;
      finish_item(item);
      
  endtask : send_feat_dllp

    // send_fc_dllp
  task pcie_base_seq::send_fc_dllp(dllp_type_t pkt_type, fc_type_t fc_type, pcie_dllp_seq_item item);
      item = pcie_dllp_seq_item::type_id::create("item");

      start_item(item);
          item.dllp[47:40] = pkt_type;

          // Scale fields
          item.dllp[39:38] = cfg.fc_credits_register.hdr_scale  [fc_type];
          item.dllp[29:28] = cfg.fc_credits_register.data_scale [fc_type];

          // Credit fields
          item.dllp[37:30] = cfg.fc_credits_register.hdr_credits [fc_type];
          item.dllp[27:16] = cfg.fc_credits_register.data_credits[fc_type];
      finish_item(item);
  endtask




`endif