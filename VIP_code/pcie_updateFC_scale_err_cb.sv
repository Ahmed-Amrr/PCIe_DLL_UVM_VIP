`ifndef PCIE_UPDATEFC_SCALE_ERR_CB_SV
`define PCIE_UPDATEFC_SCALE_ERR_CB_SV

class pcie_updatefc_scale_err_cb extends pcie_vip_driver_cb;

    // UVM Factory register
    `uvm_object_utils(pcie_updatefc_scale_err_cb)

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_updatefc_scale_err_cb");
        super.new(name);
    endfunction : new

    //==========================================================
    // pre_drive - Inject random scale fields into UpdateFC DLLPs
    //==========================================================
    // Detects any UpdateFC DLLP (P / NP / CPL) and overwrites both
    // the header and data scale fields with random values
    virtual task pre_drive(pcie_dllp_seq_item item, pcie_vip_tx_sequencer sqr);

        if (sqr == null) begin
            `uvm_warning("CB_DLLP_TYPE", "sqr is null")
            return;
        end

        if (item.dllp[47:40] inside {UPDATEFC_P, UPDATEFC_NP, UPDATEFC_CPL}) begin
            item.dllp[39:38] = $random();   // Random header scale
            item.dllp[29:28] = $random();   // Random data scale   
        end

    endtask : pre_drive

endclass : pcie_updatefc_scale_err_cb

`endif