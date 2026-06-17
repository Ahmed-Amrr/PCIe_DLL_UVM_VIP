`ifndef PCIE_VIP_DRIVER_CB_SV
`define PCIE_VIP_DRIVER_CB_SV

class pcie_vip_driver_cb extends uvm_callback;

    // UVM Factory register
    `uvm_object_utils(pcie_vip_driver_cb)

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_vip_driver_cb");
        super.new(name);
    endfunction : new

    //==========================================================
    // pre_drive - Callback hook called before CRC generation
    //==========================================================
    virtual task pre_drive(pcie_dllp_seq_item item, pcie_vip_tx_sequencer sqr);
        // Default: do nothing
    endtask

    //==========================================================
    // crc_drive - Callback hook called after CRC generation
    //==========================================================
    virtual task crc_drive(pcie_dllp_seq_item item, pcie_vip_tx_sequencer sqr);
        // Default: do nothing
    endtask

    //==========================================================
    // post_drive - Callback hook called after driving the interface
    //==========================================================
    virtual task post_drive(pcie_dllp_seq_item item, pcie_vip_tx_sequencer sqr);
        // Default: do nothing
    endtask

endclass : pcie_vip_driver_cb

`endif