`ifndef PCIE_FLIT_ECC_CB_SV
`define PCIE_FLIT_ECC_CB_SV

class pcie_flit_ecc_cb extends pcie_vip_driver_cb;

    // UVM Factory register
    `uvm_object_utils(pcie_flit_ecc_cb)

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_flit_ecc_cb");
        super.new(name);
    endfunction

    //==========================================================
    // flit_drive - Callback hook called after FLIT generation
    //==========================================================
    virtual task flit_drive(ref logic [0:255] [7:0] item, pcie_vip_tx_sequencer sqr);
        repeat(3) begin
            int idx = $urandom_range(0, 255);
            `uvm_info("FLIT_ECC_CB", $sformatf("Corrupted FLIT[%0d] before corruption: %0h", idx, item[idx]), UVM_DEBUG)
            item[idx] = $random;
            `uvm_info("FLIT_ECC_CB", $sformatf("Corrupted FLIT[%0d] after corruption: %0h", idx, item[idx]), UVM_DEBUG)
        end 
        
    endtask

endclass : pcie_flit_ecc_cb

`endif