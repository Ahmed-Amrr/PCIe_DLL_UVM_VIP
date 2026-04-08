class pcie_fc_init_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_fc_init_seq)

    // Randomizable credit fields
    // Held constant across INIT1 and INIT2 per PCIe spec
    rand bit [1:0]  hdr_scale  [3];   // [0]=P  [1]=NP  [2]=CPL
    rand bit [1:0]  data_scale [3];
    rand bit [7:0]  hdr_credits  [3];
    rand bit [11:0] data_credits [3];

    pcie_dllp_seq_item item;

    function new(string name = "pcie_fc_init_seq");
        super.new(name);
    endfunction

    virtual task body();

        // Randomize credits — same values used in INIT2 1 & INIT2 phases
        if (!this.randomize())
            `uvm_fatal(get_type_name(), "Randomization of FC credits failed")

        // Push randomized values into cfg 
        for (int fc = 0; fc < 3; fc++) begin
            cfg.fc_credits_register.hdr_scale   [fc] = hdr_scale   [fc];
            cfg.fc_credits_register.data_scale  [fc] = data_scale  [fc];
            cfg.fc_credits_register.hdr_credits [fc] = hdr_credits [fc];
            cfg.fc_credits_register.data_credits[fc] = data_credits[fc];
        end

        // Move state machine up to INIT1
        super.start_from_INIT1(item);

        // Drive INITFC1 triplets while SM stays in DL_INIT1
       while (p_sequencer.state == DL_INIT1) begin
            send_fc_dllp(INITFC1_P,   FC_POSTED);
            send_fc_dllp(INITFC1_NP,  FC_NON_POSTED);
            send_fc_dllp(INITFC1_CPL, FC_COMPLETION);
       end

        // Drive INITFC2 triplets while SM stays in DL_INIT2
         while (p_sequencer.state == DL_INIT2) begin
            send_fc_dllp(INITFC2_P,   FC_POSTED);
            send_fc_dllp(INITFC2_NP,  FC_NON_POSTED);
            send_fc_dllp(INITFC2_CPL, FC_COMPLETION);
         end

        `uvm_info(get_type_name(), "Full FC initialization complete", UVM_LOW)
    endtask

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

endclass