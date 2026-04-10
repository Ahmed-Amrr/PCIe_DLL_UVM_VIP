`ifndef PCIE_BASE_SEQ
`define PCIE_BASE_SEQ 

  class pcie_base_seq extends uvm_sequence #(pcie_dllp_seq_item);
    `uvm_object_utils(pcie_base_seq)

    `uvm_declare_p_sequencer(pcie_vip_tx_sequencer)

    pcie_vip_config cfg;

    // Tasks to walk through the states
    extern virtual task start_from_INACTIVE(pcie_dllp_seq_item item);
    extern virtual task start_from_Feature(pcie_dllp_seq_item item);
    extern virtual task start_from_INIT1(pcie_dllp_seq_item item);
    extern virtual task start_from_INIT2(pcie_dllp_seq_item item);
    extern virtual task start_from_ACTIVE(pcie_dllp_seq_item item);
    extern virtual task send_feat_dllp (input dllp_type_t pkt_type);
    extern virtual task send_fc_dllp(dllp_type_t pkt_type, fc_type_t fc_type);

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


  // start_from_INACTIVE task 
  // Send reset DLLPs to initialize the link from INACTIVE state
  task pcie_base_seq::start_from_INACTIVE(pcie_dllp_seq_item item);
      for (int i = 0; i < 10; i++) begin
        item = pcie_dllp_seq_item::type_id::create("item");

        start_item(item);
        item.rst_req = 1;
        finish_item(item);
      end   
  endtask : start_from_INACTIVE 


  // start_from_Feature task 
  // Enter FEATURE stage by reusing INACTIVE initialization then wait the SM to change state
  task pcie_base_seq::start_from_Feature(pcie_dllp_seq_item item);
      start_from_INACTIVE(item); 
  endtask : start_from_Feature

  // start_from_INIT1 task  
  // Sends DL_FEATURE DLLPs while state is DL_FEATURE
  task pcie_base_seq::start_from_INIT1(pcie_dllp_seq_item item);
      int i = 0;

      start_from_Feature(item); 

      if (cfg.local_register_feature.feature_exchange_enable & cfg.feature_exchange_cap) begin
        while (p_sequencer.state == DL_FEATURE) begin
          item = pcie_dllp_seq_item::type_id::create("item");
          start_item(item);
            item.dllp[47:40] = DL_FEATURE; 
            item.dllp[38:16] = cfg.local_register_feature.local_feature_supported;
            item.dllp[39] = cfg.remote_register_feature.remote_feature_valid;
          finish_item(item);
          i++;

          // Counter to count Timeout for each state in order not to stuck 
          if (i == 1000) begin
            `uvm_error("Base Seq", "Timeout for the base seq in DL_FEATURE state")
            break;
          end
        end 
      end

  endtask : start_from_INIT1


  // start_from_INIT2 task  
  // Perform Flow Control initialization phase 1
  // Sends INITFC1 (P/NP/CPL) DLLPs using cfg credits    
  task pcie_base_seq::start_from_INIT2(pcie_dllp_seq_item item);
      int i = 0;

      start_from_INIT1(item); 

      while (p_sequencer.state == DL_INIT1) begin
        item = pcie_dllp_seq_item::type_id::create("item");
        start_item(item);
          item.dllp[47:40] = INITFC1_P; 
          item.dllp[39:38] = cfg.fc_credits_register.hdr_scale[0];
          item.dllp[37:30] = cfg.fc_credits_register.hdr_credits[0];
          item.dllp[29:28] = cfg.fc_credits_register.data_scale[0];
          item.dllp[27:16] = cfg.fc_credits_register.data_credits[0];
        finish_item(item);

        item = pcie_dllp_seq_item::type_id::create("item");
        start_item(item);
          item.dllp[47:40] = INITFC1_NP; 
          item.dllp[39:38] = cfg.fc_credits_register.hdr_scale[1];
          item.dllp[37:30] = cfg.fc_credits_register.hdr_credits[1];
          item.dllp[29:28] = cfg.fc_credits_register.data_scale[1];
          item.dllp[27:16] = cfg.fc_credits_register.data_credits[1];
        finish_item(item);

        item = pcie_dllp_seq_item::type_id::create("item");
        start_item(item);
          item.dllp[47:40] = INITFC1_CPL; 
          item.dllp[39:38] = cfg.fc_credits_register.hdr_scale[2];
          item.dllp[37:30] = cfg.fc_credits_register.hdr_credits[2];
          item.dllp[29:28] = cfg.fc_credits_register.data_scale[2];
          item.dllp[27:16] = cfg.fc_credits_register.data_credits[2];
        finish_item(item);

        i++;

        // Counter to count Timeout for each state in order not to stuck 
        if (i == 1000) begin
          `uvm_error("Base Seq", "Timeout for the base seq in DL_INIT1 state")
          break;
        end
      end 

  endtask : start_from_INIT2


  // start_from_ACTIVE task  
  // Complete Flow Control initialization phase 2
  // Sends INITFC2 (P/NP/CPL) DLLPs
  task pcie_base_seq::start_from_ACTIVE(pcie_dllp_seq_item item);
    int i = 0;

    start_from_INIT2(item); 

      while (p_sequencer.state == DL_INIT2) begin
        item = pcie_dllp_seq_item::type_id::create("item");
        start_item(item);
          item.dllp[47:40] = INITFC2_P; 
          item.dllp[39:38] = cfg.fc_credits_register.hdr_scale[0];
          item.dllp[37:30] = cfg.fc_credits_register.hdr_credits[0];
          item.dllp[29:28] = cfg.fc_credits_register.data_scale[0];
          item.dllp[27:16] = cfg.fc_credits_register.data_credits[0];
        finish_item(item);

        item = pcie_dllp_seq_item::type_id::create("item");
        start_item(item);
          item.dllp[47:40] = INITFC2_NP; 
          item.dllp[39:38] = cfg.fc_credits_register.hdr_scale[1];
          item.dllp[37:30] = cfg.fc_credits_register.hdr_credits[1];
          item.dllp[29:28] = cfg.fc_credits_register.data_scale[1];
          item.dllp[27:16] = cfg.fc_credits_register.data_credits[1];
        finish_item(item);

        item = pcie_dllp_seq_item::type_id::create("item");
        start_item(item);
          item.dllp[47:40] = INITFC2_CPL; 
          item.dllp[39:38] = cfg.fc_credits_register.hdr_scale[2];
          item.dllp[37:30] = cfg.fc_credits_register.hdr_credits[2];
          item.dllp[29:28] = cfg.fc_credits_register.data_scale[2];
          item.dllp[27:16] = cfg.fc_credits_register.data_credits[2];
        finish_item(item);

        i++;

        // Counter to count Timeout for each state in order not to stuck 
        if (i == 1000) begin
          `uvm_error("Base Seq", "Timeout for the base seq in DL_INIT2 state")
          break;
        end
      end 

  endtask : start_from_ACTIVE

    // send_fc_dllp
  task send_feat_dllp (input dllp_type_t pkt_type);
      item = pcie_dllp_seq_item::type_id::create("item");
      start_item(item);
      item.dllp[47:40] = pkt_type; 
      item.dllp[38:16] = cfg.local_register_feature.local_feature_supported;
      // We mirror the remote valid bit back as our Ack
      item.dllp[39]    = cfg.remote_register_feature.remote_feature_valid;
      finish_item(item);
  endtask : send_feat_dllp

    // send_fc_dllp
  task send_fc_dllp(dllp_type_t pkt_type, fc_type_t fc_type);
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