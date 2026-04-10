`ifndef PCIE_VALID_OFF_SEQ
`define PCIE_VALID_OFF_SEQ

    class pcie_valid_off_seq extends pcie_base_seq;
        `uvm_object_utils(pcie_valid_off_seq)

        pcie_dllp_seq_item item;

        function new(string name = "pcie_valid_off_seq");
            super.new(name);
        endfunction

        virtual task body();
            super.start_from_ACTIVE(item);
        endtask

    endclass

`endif