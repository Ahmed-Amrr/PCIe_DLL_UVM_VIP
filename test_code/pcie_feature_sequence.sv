`ifndef PCIE_FEATURE_SEQUENCE_SV
`define PCIE_FEATURE_SEQUENCE_SV

class pcie_feature_sequence extends pcie_base_seq;

    // UVM Factory register
    `uvm_object_utils(pcie_feature_sequence)

    // Handle
    pcie_dllp_seq_item item;

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_feature_sequence");
        super.new(name);
    endfunction : new

    //==========================================================
    // Body - Send Feature DLLPs while in DL_FEATURE state
    //==========================================================
    // Enables feature exchange in cfg then repeatedly sends Feature
    // DLLPs until the sequencer exits DL_FEATURE or timeout is hit
    virtual task body();
        int i = 0;

        `uvm_info(get_type_name(), "Starting Feature Exchange Sequence", UVM_LOW)

        while (p_sequencer.state == DL_FEATURE) begin

            send_feat_dllp(FEATURE, item);

            // Timeout guard — break if state has not advanced after 1000 iterations
            i++;
            if (i == 1000) begin
                `uvm_error(get_type_name(), "Timeout for the seq in DL_FEATURE state")
                break;
            end
        end

        `uvm_info(get_type_name(), "Feature Exchange Sequence Finished", UVM_LOW)
    endtask : body

endclass : pcie_feature_sequence

`endif // PCIE_FEATURE_SEQUENCE_SV
