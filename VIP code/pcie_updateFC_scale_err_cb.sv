`ifndef PCIE_UPDATEFC_ERR_CB_SV
`define PCIE_UPDATEFC_ERR_CB_SV

    class pcie_updateFC_scale_err_cb extends pcie_vip_driver_cb;
        `uvm_object_utils(pcie_updateFC_scale_err_cb)


        function new(string name = "pcie_updateFC_scale_err_cb");
            super.new(name);
        endfunction : new

        virtual task pre_drive(pcie_dllp_seq_item item, pcie_vip_tx_sequencer sqr);

            if (sqr == null) begin
                `uvm_warning("CB_DLLP_TYPE", "sqr is null")
                return;
            end

            if (item[47:40] inside {UPDATEFC_P, UPDATEFC_NP, UPDATEFC_CPL}) begin
                item.dllp[39:38] = $random();
                item.dllp[29:28] = $random();
            end

        endtask : pre_drive

    endclass 

`endif