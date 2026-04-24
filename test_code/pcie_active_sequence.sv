class pcie_active_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_active_seq)

    // New randomizable credit values for UpdateFC
    rand bit [7:0]  upd_hdr_credits  [3];
    rand bit [11:0] upd_data_credits [3];

    // Flags for INIT behavior 
     bit hdr_infinite_init  [3];
     bit data_infinite_init [3];

    pcie_dllp_seq_item item;

    function new(string name = "pcie_active_seq");
        super.new(name);
    endfunction

    virtual task body();
        int i = 0;

        // Capture INIT behavior
        foreach (hdr_infinite_init[i]) begin
            hdr_infinite_init[i]  = (cfg.fc_credits_register.hdr_credits[i]  == 0);
            data_infinite_init[i] = (cfg.fc_credits_register.data_credits[i] == 0);
         end   

        while (p_sequencer.state == DL_ACTIVE) begin
            int delay;

            // Randomize new credit values for this UpdateFC round
           if (!this.randomize())
                 `uvm_fatal(get_type_name(), "Randomization of UpdateFC credits failed")

            // // Write new values into cfg 
            // // Infinite fields stay 0, finite fields get new random values
            // update_credits_in_cfg();

            if (needs_updatefc(FC_POSTED))
                send_updatefc(UPDATEFC_P, FC_POSTED);

            if (needs_updatefc(FC_NON_POSTED))
                send_updatefc(UPDATEFC_NP, FC_NON_POSTED);

            if (needs_updatefc(FC_COMPLETION))
                send_updatefc(UPDATEFC_CPL, FC_COMPLETION);

            assert(std::randomize(delay) with {delay > 0;  delay < 34;});
            #(delay);

        end
        `uvm_info(get_type_name(), "Active seq complete", UVM_MEDIUM)
    endtask


    // --------------------------------------------------------
    // needs_updatefc
    // Returns 0 ONLY if BOTH hdr and data were advertised as infinite (value of 00h or 000h) during init 
    // Returns 1 otherwise as UpdateFC is still required
    // --------------------------------------------------------
    function bit needs_updatefc(fc_type_t fc_type);

        if (hdr_infinite_init[fc_type] && data_infinite_init[fc_type]) begin
            `uvm_info(get_type_name(), $sformatf(
                "FC type %0s: both infinite — skipping UpdateFC",
                fc_type.name()), UVM_HIGH)
            return 0;
        end
        return 1;
    endfunction

    // send_updatefc
    task send_updatefc(dllp_type_t pkt_type, fc_type_t fc_type);
        item = pcie_dllp_seq_item::type_id::create("item");

        if (!item.randomize())
            `uvm_fatal(get_type_name(), "item randomization failed")

        start_item(item);
            item.dllp[47:40] = pkt_type;

            // Scale match init advertisement 
            item.dllp[39:38] = cfg.fc_credits_register.hdr_scale [fc_type];
            item.dllp[29:28] = cfg.fc_credits_register.data_scale[fc_type];

            // Credits are forced to stay 0 for Infinite Credit advertisement
            item.dllp[37:30] = hdr_infinite_init [fc_type] ? 8'h00   : upd_hdr_credits  [fc_type];
            item.dllp[27:16] = data_infinite_init[fc_type] ? 12'h000 : upd_data_credits [fc_type];
        finish_item(item);
    endtask

endclass