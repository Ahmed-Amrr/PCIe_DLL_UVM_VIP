`ifndef PCIE_CRC_ERR_CB_SV
`define PCIE_CRC_ERR_CB_SV

class pcie_crc_err_cb extends pcie_vip_driver_cb;
    `uvm_object_utils(pcie_crc_err_cb)

    function new(string name = "pcie_crc_err_cb");
        super.new(name);
    endfunction

    virtual task pre_drive(pcie_dllp_seq_item item, pcie_vip_tx_sequencer sqr);
        randcase
            1: item.dllp[15:0] = item.dllp[15:0];
            1: begin
                item.dllp[15:0] = ~item.dllp[15:0];
                `uvm_info("CB_DLLP_ERR", "DLLP crc corrupted", UVM_MEDIUM)
            end
        endcase
    endtask : pre_drive

endclass : pcie_crc_err_cb

`endif