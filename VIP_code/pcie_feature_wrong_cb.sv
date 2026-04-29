`ifndef PCIE_FEATURE_WRONG_CB_SV
`define PCIE_FEATURE_WRONG_CB_SV

class pcie_feature_wrong_cb extends pcie_vip_driver_cb;

    // UVM Factory register
    `uvm_object_utils(pcie_feature_wrong_cb)

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_feature_wrong_cb");
        super.new(name);
    endfunction : new

    //==========================================================
    // pre_drive - Send random unsupported feature value
    //==========================================================
    // Overrides the feature supported field with  
    // a value that will not match the local advertisement
    virtual task pre_drive(pcie_dllp_seq_item item, pcie_vip_tx_sequencer sqr);

        if (sqr == null) begin
            `uvm_warning("CB_FEATURE_UNSUPPORTED", "sqr is null")
            return;
        end

        if (sqr.state == DL_FEATURE) begin
            // Drive correct Ack bit but wrong feature value
            item.dllp[38:16] = ~sqr.cfg.local_register_feature.local_feature_supported;                                             // Random feature value — will not match local advertisement
        end

    endtask : pre_drive

endclass

`endif