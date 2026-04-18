`ifndef PCIE_SEQ_CALLBACKS
`define PCIE_SEQ_CALLBACKS


    class pcie_seq_cb extends uvm_callback;
        `uvm_object_utils(pcie_seq_cb)

        dl_state_t state;

        function new(string name = "pcie_seq_cb");
            super.new(name);
        endfunction

        virtual task do_send_pattern(pcie_base_seq seq, dl_state_t state);
            // default: do nothing, normal sequence runs
        endtask

    endclass

`endif
