`ifndef PCIE_FEATURE_RESEVED_CB_SV
`define PCIE_FEATURE_RESEVED_CB_SV

    class pcie_feature_reserved_err_cb extends pcie_vip_driver_cb;
        `uvm_object_utils(pcie_feature_reserved_err_cb)


        function new(string name = "pcie_feature_reserved_err_cb");
            super.new(name);
        endfunction : new

        virtual task pre_drive(pcie_dllp_seq_item item, pcie_vip_tx_sequencer sqr);

            dllp_type_t wrong_type;

            if (sqr = null) begin
                `uvm_warning("CB_DLLP_TYPE", "sqr is null")
                return;
            end

            if (sqr.state) begin
                item.dllp[38:16] = $random();
            end

        endtask : pre_drive

    endclass 

`endif