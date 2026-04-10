`ifndef PCIE_CRC_ERR_SEQ
`define PCIE_CRC_ERR_SEQ

    class pcie_crc_err_seq extends pcie_base_seq;
        `uvm_object_utils(pcie_crc_err_seq)

        pcie_dllp_seq_item item;

        function new(string name = "pcie_crc_err_seq");
            super.new(name);
        endfunction

        virtual task body();
            super.start_from_ACTIVE(item);
        endtask

    endclass

`endif