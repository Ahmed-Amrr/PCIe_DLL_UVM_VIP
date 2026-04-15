`ifndef PCIE_FEATURE_SEQUENCE_SV
`define PCIE_FEATURE_SEQUENCE_SV

class pcie_feature_sequence extends pcie_base_seq;
    `uvm_object_utils(pcie_feature_sequence)

    pcie_dllp_seq_item item;

    function new(string name = "pcie_feature_sequence");
        super.new(name);
    endfunction : new

    virtual task body();
        int i = 0;

        `uvm_info(get_type_name(), "Starting Feature Exchange Sequence", UVM_LOW)

        while (p_sequencer.state == DL_FEATURE) begin
            item = pcie_dllp_seq_item::type_id::create("item");

            start_item(item);
            assert(item.randomize() with {
                dllp[47:40] == FEATURE; 
                dllp[38:16] == cfg.local_register_feature.local_feature_supported;
                dllp[39]    == cfg.remote_register_feature.remote_feature_valid;
            });
            finish_item(item);

            i++;
            if (i == 1000) begin
              `uvm_error(get_type_name(), "Timeout for the seq in DL_FEATURE state")
              break;
            end
        end

        `uvm_info(get_type_name(), "Feature Exchange Sequence Finished", UVM_LOW)
    endtask : body

endclass : pcie_feature_sequence

`endif