class pcie_init1_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_init1_seq)
    
    pcie_dllp_seq_item item;
    pcie_vip_config cfg;
   
    function new(string name = "pcie_init1_seq");
        super.new(name);
    endfunction

    virtual task body();

        super.start_from_INIT1(item);

        if(!uvm_config_db #(pcie_vip_cfg)::get(this,"", "cfg", cfg))
            `uvm_fatal("build_phase","Init sequence unable to get configuration object")
        cfg.fc_credits_register.hdr_scale[fc_type]    = 2'b00;
        cfg.fc_credits_register.data_scale[fc_type]   = 2'b00;
        cfg.fc_credits_register.hdr_credits[fc_type]  = $random;
        cfg.fc_credits_register.data_credits[fc_type] = $random;

        uvm_config_db#(pcie_vip_cfg)::set(this, "*", "cfg", cfg);

        while(p_sequencer.state == DL_INIT1) begin 
            // Send InitFC1 DLLPs in STRICT ORDER 
            send_initfc1_pkt(INITFC1_P);    // FIRST
            send_initfc1_pkt(INITFC1_NP);   // SECOND
            send_initfc1_pkt(INITFC1_CPL);  // THIRD
        end

        `uvm_info(get_type_name(), "FC_INIT1 complete", UVM_LOW)
    endtask
    
    // Task to transmit the 3-DLLP sequence
    task send_initfc1_pkt(dllp_type_t pkt_type);
    fc_type_t fc_type;

    // Step 1: Map DLLP type -> FC type
    case (pkt_type)
        INITFC1_P   : fc_type = FC_POSTED;
        INITFC1_NP  : fc_type = FC_NON_POSTED;
        INITFC1_CPL : fc_type = FC_COMPLETION;
        default: begin
        `uvm_error("INITFC1_SEQ", "Invalid DLLP type for INITFC1")
        return;
        end
    endcase

    // Create transaction
    item = pcie_dllp_seq_item::type_id::create("item");
    start_item(item);
    // Set DLLP type field
    item.dllp[47:40] = pkt_type;
    // Scaling 
    item.dllp[39:38] = cfg.fc_credits_register.hdr_scale[fc_type];
    item.dllp[29:28] = cfg.fc_credits_register.data_scale[fc_type];

    //Credits 
    item.dllp[37:30] = cfg.fc_credits_register.hdr_credits[fc_type];
    item.dllp[27:16] = cfg.fc_credits_register.data_credits[fc_type];

    finish_item(item);

    endtask
endclass