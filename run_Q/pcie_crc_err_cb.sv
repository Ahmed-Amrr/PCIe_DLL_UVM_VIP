`ifndef PCIE_CRC_ERR_CB_SV
`define PCIE_CRC_ERR_CB_SV

class pcie_crc_err_cb extends pcie_vip_driver_cb;

    // UVM Factory register
    `uvm_object_utils(pcie_crc_err_cb)

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_crc_err_cb");
        super.new(name);
    endfunction

    //==========================================================
    // crc_drive - Corrupt DLLP CRC by inverting the CRC field
    //==========================================================
    virtual task crc_drive(pcie_dllp_seq_item item, pcie_vip_tx_sequencer sqr);
        item.dllp[15:0] = ~item.dllp[15:0];
        `uvm_info("CB_DLLP_ERR", "DLLP crc corrupted", UVM_MEDIUM)
    endtask

endclass : pcie_crc_err_cb

`endif