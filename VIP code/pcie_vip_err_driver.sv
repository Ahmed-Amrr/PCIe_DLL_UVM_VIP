`ifndef PCIE_ERR_VIP_DRIVER
`define PCIE_ERR_VIP_DRIVER

class pcie_vip_err_driver extends pcie_vip_driver;
    `uvm_component_utils(pcie_vip_err_driver)

    virtual lpif_if lpif_vif;
    pcie_dllp_seq_item   seq_item_drv;

    function new(string name = "pcie_vip_err_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);
    endfunction : 

    virtual task run_phase(uvm_phase phase);
        seq_item_drv = pcie_dllp_seq_item::type_id::create("seq_item_drv", this);
        forever begin
            seq_item_port.get_next_item(seq_item_drv);
            CRC_generation(seq_item_drv.dllp[47:16], seq_item_drv.dllp[15:0]);
            lpif_vif.lp_data = seq_item_drv.dllp;
            lpif_vif.lp_valid = seq_item_drv.lp_valid;
            @(lpif_vif.drv_cb);
            seq_item_port.item_done();
        end
    endtask

    function CRC_generation(input bit[31:0] dllp_before_crc, output bit[15:0] crc);
        // tie the crc to all-zero value regardless the value of the dllp
        crc = '0;
    endfunction : CRC_generation

endclass : 
`endif