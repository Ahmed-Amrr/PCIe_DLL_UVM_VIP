`ifndef PCIE_SEQ_CALLBACKS
`define PCIE_SEQ_CALLBACKS


    class pcie_seq_cb extends uvm_callback;
        `uvm_object_utils(pcie_seq_callbacks)

        dl_state_t state;

        function new(string name = "pcie_seq_callbacks");
            super.new(name);
        endfunction

        virtual task do_send_pattern(pcie_fc_init1_seq seq, dl_state_t state);
            // default: do nothing, normal sequence runs
        endtask

        virtual function bit override_pattern();
            return 0; // default: don't override
        endfunction

    endclass

`endif