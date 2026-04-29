`ifndef PCIE_FEATURE_WRONG_ACK_CB_SV
`define PCIE_FEATURE_WRONG_ACK_CB_SV

class pcie_feature_wrong_ack_cb extends pcie_vip_driver_cb;

    // UVM Factory register
    `uvm_object_utils(pcie_feature_wrong_ack_cb)

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_feature_wrong_ack_cb");
        super.new(name);
    endfunction : new

    //==========================================================
    // pre_drive - Suppress Ack bit while sending correct feature value
    //==========================================================
    // Inverts the remote_feature_valid bit before driving — always
    // sending the wrong acknowledgment state to test remote error handling.
    virtual task pre_drive(pcie_dllp_seq_item item, pcie_vip_tx_sequencer sqr);

        if (sqr == null) begin
            `uvm_warning("CB_FEATURE_WRONG_ACK", "sqr is null")
            return;
        end

        if (sqr.state == DL_FEATURE) begin
            // Drive correct feature bits but wrong Ack bit
            item.dllp[39] = !sqr.cfg.remote_register_feature.remote_feature_valid;                                                    
        end

    endtask : pre_drive

endclass : pcie_feature_wrong_ack_cb

`endif