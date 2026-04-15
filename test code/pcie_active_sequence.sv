`ifndef PCIE_ACTIVE_SEQUENCE_SV
`define PCIE_ACTIVE_SEQUENCE_SV

class pcie_active_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_active_seq)

    // Randomizable credit values for UpdateFC
    rand bit [7:0]  upd_hdr_credits  [3];
    rand bit [11:0] upd_data_credits [3];

    // Flags captured from init phase
    bit hdr_infinite_init  [3];
    bit data_infinite_init [3];

    function new(string name = "pcie_active_seq");
        super.new(name);
    endfunction : new


    virtual task body();
        `uvm_info(get_type_name(), "Starting Active Sequence", UVM_LOW)

        // Capture infinite credit flags from init phase
        foreach (hdr_infinite_init[i]) begin
            hdr_infinite_init[i]  = (cfg.fc_credits_register.hdr_credits[i]  == 0);
            data_infinite_init[i] = (cfg.fc_credits_register.data_credits[i] == 0);
        end

        while (p_sequencer.state == DL_ACTIVE) begin

            // Randomize new credit values for this UpdateFC round
            assert(this.randomize()) else
                `uvm_fatal(get_type_name(), "Randomization of UpdateFC credits failed")

            // Posted 
            if (needs_updatefc(FC_POSTED)) begin
                item = pcie_dllp_seq_item::type_id::create("item");
                start_item(item);
                assert(item.randomize() with {
                    dllp[47:40] == UPDATEFC_P;
                    dllp[39:38] == cfg.fc_credits_register.hdr_scale[FC_POSTED];
                    dllp[29:28] == cfg.fc_credits_register.data_scale[FC_POSTED];
                    dllp[37:30] == (hdr_infinite_init[FC_POSTED]  ?
                                    8'h00  : upd_hdr_credits[FC_POSTED]);
                    dllp[27:16] == (data_infinite_init[FC_POSTED] ?
                                    12'h000 : upd_data_credits[FC_POSTED]);
                }) else
                    `uvm_fatal(get_type_name(), "item randomization failed")
                finish_item(item);
            end

            // Non Posted 
            if (needs_updatefc(FC_NON_POSTED)) begin
                item = pcie_dllp_seq_item::type_id::create("item");
                start_item(item);
                assert(item.randomize() with {
                    dllp[47:40] == UPDATEFC_NP;
                    dllp[39:38] == cfg.fc_credits_register.hdr_scale[FC_NON_POSTED];
                    dllp[29:28] == cfg.fc_credits_register.data_scale[FC_NON_POSTED];
                    dllp[37:30] == (hdr_infinite_init[FC_NON_POSTED]  ?
                                    8'h00  : upd_hdr_credits[FC_NON_POSTED]);
                    dllp[27:16] == (data_infinite_init[FC_NON_POSTED] ?
                                    12'h000 : upd_data_credits[FC_NON_POSTED]);
                }) else
                    `uvm_fatal(get_type_name(), "item randomization failed")
                finish_item(item);
            end

            // Completion 
            if (needs_updatefc(FC_COMPLETION)) begin
                item = pcie_dllp_seq_item::type_id::create("item");
                start_item(item);
                assert(item.randomize() with {
                    dllp[47:40] == UPDATEFC_CPL;
                    dllp[39:38] == cfg.fc_credits_register.hdr_scale[FC_COMPLETION];
                    dllp[29:28] == cfg.fc_credits_register.data_scale[FC_COMPLETION];
                    dllp[37:30] == (hdr_infinite_init[FC_COMPLETION]  ?
                                    8'h00  : upd_hdr_credits[FC_COMPLETION]);
                    dllp[27:16] == (data_infinite_init[FC_COMPLETION] ?
                                    12'h000 : upd_data_credits[FC_COMPLETION]);
                }) else
                    `uvm_fatal(get_type_name(), "item randomization failed")
                finish_item(item);
            end

        end

        `uvm_info(get_type_name(), "Active Sequence Finished", UVM_LOW)
    endtask : body

    // --------------------------------------------------------
    // needs_updatefc
    // Returns 0 ONLY if BOTH hdr AND data were infinite at init
    // --------------------------------------------------------
    function bit needs_updatefc(fc_type_t fc_type);
        if (hdr_infinite_init[fc_type] && data_infinite_init[fc_type]) begin
            `uvm_info(get_type_name(), $sformatf(
                "FC type %0s: both infinite — skipping UpdateFC",
                fc_type.name()), UVM_MEDIUM)
            return 0;
        end
        return 1;
    endfunction : needs_updatefc

endclass : pcie_active_seq

`endif


