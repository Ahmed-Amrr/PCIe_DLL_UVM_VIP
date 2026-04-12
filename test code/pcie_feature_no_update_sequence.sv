`ifndef PCIE_FEATURE_NO_UPDATE_SEQUENCE_SV
`define PCIE_FEATURE_NO_UPDATE_SEQUENCE_SV

class pcie_feature_no_update_sequence extends pcie_base_seq;
    `uvm_object_utils(pcie_feature_no_update_sequence)

    rand bit [22:0] different_feature_value;

    // Constraint second value that must differ from local register
    constraint c_different_from_local {
        different_feature_value !=  cfg.local_register_feature.local_feature_supported;
    }

    pcie_dllp_seq_item item;

    function new(string name = "pcie_feature_no_update_sequence");
        super.new(name);
    endfunction

    virtual task body();
        int i = 0;

        `uvm_info(get_type_name(), "Starting Feature No-Update Sequence", UVM_LOW)

        super.start_from_Feature(item);

        if (!this.randomize(different_feature_value))
            `uvm_fatal(get_type_name(), "Randomization failed")

        while (p_sequencer.state == DL_FEATURE) begin
        // DLLP 1: correct value from local register
        // Remote captures this and sets Valid=1
            send_feat_dllp(FEATURE);
        // DLLP 2: different value — remote must NOT update its field
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

endclass

`endif