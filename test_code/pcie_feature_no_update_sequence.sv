`ifndef PCIE_FEATURE_NO_UPDATE_SEQUENCE_SV
`define PCIE_FEATURE_NO_UPDATE_SEQUENCE_SV

class pcie_feature_no_update_sequence extends pcie_base_seq;

    // UVM Factory register
    `uvm_object_utils(pcie_feature_no_update_sequence)

    // Randomizable field
    rand bit [22:0] different_feature_value;

    // Constraint: second DLLP value must not match local advertisement
    constraint c_different_from_local {
        different_feature_value != cfg.local_register_feature.local_feature_supported;
    }

    // Handle
    pcie_dllp_seq_item item;

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_feature_no_update_sequence");
        super.new(name);
    endfunction : new

    //==========================================================
    // Body - Send alternating correct / mismatched Feature DLLPs
    //==========================================================
    // DLLP 1: correct local value  — remote captures the feature field and sets Valid=1,
    //         after which it stops reading the feature field from any further DLLPs
    // DLLP 2: different value      — sent to confirm the remote does NOT update its
    //         feature field once Valid=1 is set
    virtual task body();
        // Timeout counter to prevent infinite loop in case of unexpected behavior
        int i = 0;

        `uvm_info(get_type_name(), "Starting Feature No-Update Sequence", UVM_LOW)

        if (!this.randomize(different_feature_value))
            `uvm_fatal(get_type_name(), "Randomization failed")

        while (p_sequencer.state == DL_FEATURE) begin

            // DLLP 1: correct value — triggers Valid=1 on the remote side
            send_feat_dllp(FEATURE, item);

            // DLLP 2: different value — remote must ignore this since Valid=1 already set
            item = pcie_dllp_seq_item::type_id::create("item");
            start_item(item);
                item.dllp[47:40] = FEATURE;
                item.dllp[38:16] = different_feature_value;
                item.dllp[39]    = cfg.remote_register_feature.remote_feature_valid;
            finish_item(item);

            i++;
            if (i == 100) begin
                `uvm_error(get_type_name(), "Timeout in DL_FEATURE state")
                break;
            end
        end

        `uvm_info(get_type_name(), "Feature No-Update Sequence Finished", UVM_LOW)
    endtask : body

endclass : pcie_feature_no_update_sequence

`endif