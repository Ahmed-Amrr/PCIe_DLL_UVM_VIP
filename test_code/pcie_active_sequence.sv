`ifndef PCIE_ACTIVE_SEQUENCE_SV
`define PCIE_ACTIVE_SEQUENCE_SV

class pcie_active_seq extends pcie_base_seq;

    // UVM Factory register
    `uvm_object_utils(pcie_active_seq)

    // Randomizable credit values sent in each UpdateFC (P - NP - CPL)
    rand bit [7:0]  upd_hdr_credits  [3];
    rand bit [11:0] upd_data_credits [3];

    // Infinite-credit flags captured from INIT advertisement (value 00h / 000h)
    bit hdr_infinite_init  [3];
    bit data_infinite_init [3];

    // Handle
    pcie_dllp_seq_item item;

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_active_seq");
        super.new(name);
    endfunction : new

    //==========================================================
    // Body - Send UpdateFC triplet each iteration while DL_ACTIVE
    //==========================================================
    virtual task body();
        // Capture infinite-credit flags from the INIT advertisement
        foreach (hdr_infinite_init[i]) begin
            hdr_infinite_init[i]  = (cfg.local_fc_credits_register.hdr_credits[i]  == 0);
            data_infinite_init[i] = (cfg.local_fc_credits_register.data_credits[i] == 0);
        end

        while (p_sequencer.state == DL_ACTIVE) begin
            int delay;

            // Randomize new credit values for this UpdateFC round
            if (!this.randomize())
                `uvm_fatal(get_type_name(), "Randomization of UpdateFC credits failed")

            // check that we actually need to send UpdateFC for each FC type before sending, 
            // spec allows skipping UpdateFC if both hdr and data were advertised as infinite during INIT
            if (needs_updatefc(FC_POSTED))
                send_updatefc(UPDATEFC_P, FC_POSTED);

            if (needs_updatefc(FC_NON_POSTED))
                send_updatefc(UPDATEFC_NP, FC_NON_POSTED);

            if (needs_updatefc(FC_COMPLETION))
                send_updatefc(UPDATEFC_CPL, FC_COMPLETION);

            #0;
        end

        `uvm_info(get_type_name(), "Active seq complete", UVM_MEDIUM)

    endtask : body

    //==========================================================
    // needs_updatefc - Check if UpdateFC is required for FC type
    //==========================================================
    // Function: Check if UpdateFC is required for FC type &
    // Return 0 only if BOTH hdr and data were advertised as infinite
    // Input   : the type of UpdateFC dllp (P - NP - CPL)
    // Output  : bit indicating if we need UpdateFC or not
    function bit needs_updatefc(fc_type_t fc_type);

        if (hdr_infinite_init[fc_type] && data_infinite_init[fc_type]) begin
            `uvm_info(get_type_name(), $sformatf(
                "FC type %0s: both infinite — skipping UpdateFC", fc_type.name()), UVM_HIGH)
            return 0;
        end
        return 1;

    endfunction : needs_updatefc

    //==========================================================
    // send_updatefc - Build and send a single UpdateFC DLLP
    //==========================================================
    // Task  : Send UpdateFC DLLP and Force credits to 0 for any field advertised as infinite during INIT
    // Inputs: The type dllp (UPDATEFC_P - UPDATEFC_NP - UPDATEFC_CPL), 
    // and the fc type (FC_POSTED - FC_NON_POSTED - FC_COMPLETION) to index the credit arrays
    task send_updatefc(dllp_type_t pkt_type, fc_type_t fc_type);
        item = pcie_dllp_seq_item::type_id::create("item");

        if (!item.randomize())
            `uvm_fatal(get_type_name(), "item randomization failed")

        if (p_sequencer.state == DL_ACTIVE) begin
            start_item(item);
                item.dllp[47:40] = pkt_type;

                // Scale must match the original INIT advertisement
                item.dllp[39:38] = cfg.local_fc_credits_register.hdr_scale [fc_type];
                item.dllp[29:28] = cfg.local_fc_credits_register.data_scale[fc_type];

                // Hold infinite-credit fields at 0 as required by spec
                item.dllp[37:30] = hdr_infinite_init [fc_type] ? 8'h00   : upd_hdr_credits  [fc_type];
                item.dllp[27:16] = data_infinite_init[fc_type] ? 12'h000 : upd_data_credits [fc_type];
            finish_item(item);
        end
    endtask : send_updatefc

endclass : pcie_active_seq

`endif

