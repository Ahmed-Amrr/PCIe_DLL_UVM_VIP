`ifndef PCIE_FEATURE_DISABLED_SEQ
`define PCIE_FEATURE_DISABLED_SEQ

    class pcie_feature_disabled_seq extends pcie_base_seq;
        `uvm_object_utils(pcie_feature_disabled_seq)

        pcie_dllp_seq_item item;

        function new(string name = "pcie_feature_disabled_seq");
            super.new(name);
        endfunction

        virtual task body();
            super.start_from_ACTIVE(item);
        endtask

    endclass

`endif