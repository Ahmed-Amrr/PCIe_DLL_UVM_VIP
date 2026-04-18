`ifndef PCIE_FEATURE_RESEVED_CB_SV
`define PCIE_FEATURE_RESEVED_CB_SV

    class pcie_feature_reserved_err_cb extends pcie_vip_driver_cb;
        `uvm_object_utils(pcie_feature_reserved_err_cb)


        function new(string name = "pcie_feature_reserved_err_cb");
            super.new(name);
        endfunction : new

        virtual task pre_drive(pcie_dllp_seq_item item, pcie_vip_tx_sequencer sqr);

            if (sqr == null) begin
                `uvm_warning("CB_DLLP_TYPE", "sqr is null")
                return;
            end

            if (sqr.state == DL_FEATURE) begin
                item.dllp[38:16] = $random();
                item.dllp[39] = $random();
            end

        endtask : pre_drive

    endclass 

`endif