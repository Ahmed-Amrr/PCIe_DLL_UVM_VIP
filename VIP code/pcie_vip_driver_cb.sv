`ifndef PCIE_VIP_DRIVER_CB_SV
`define PCIE_VIP_DRIVER_CB_SV

class pcie_vip_driver_cb extends uvm_callback;
    `uvm_object_utils(pcie_vip_driver_cb)

    function new(string name = pcie_vip_driver_cb"");
        super.new(name);
    endfunction : new

    virtual task pre_drive(pcie_dllp_seq_item item);
        //
    endtask : pre_drive

    virtual task post_drive();
        //
    endtask : pre_drive
endclass : pcie_vip_driver_cb  

`endif