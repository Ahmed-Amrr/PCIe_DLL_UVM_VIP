`ifndef PCIE_FC_INIT1_SEQ
`define PCIE_FC_INIT1_SEQ

class pcie_fc_init1_seq extends pcie_base_seq;

    // UVM Factory register
    `uvm_object_utils(pcie_fc_init1_seq)

    // Handle
    pcie_dllp_seq_item item;

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_fc_init1_seq");
        super.new(name);
    endfunction : new

    //==========================================================
    // Body - Send INITFC1 triplet each iteration while DL_INIT1
    //==========================================================
    task body();
        pcie_dllp_seq_item item;
        pcie_seq_cb        cb  ;

        // Timeout counter to prevent infinite loop in case of unexpected behavior
        int i = 0;

        item = pcie_dllp_seq_item::type_id::create("item");

        while (p_sequencer.state == DL_INIT1) begin

            // If a callback is registered it handles sending; otherwise send normal triplet
            `uvm_do_callbacks(pcie_base_seq, pcie_seq_cb, do_send_pattern(this, p_sequencer.state))

            if (p_sequencer.state == DL_INIT1)
            send_fc_dllp(INITFC1_P_D,   FC_POSTED,     item, FC_DEDICATED);
            if (p_sequencer.state == DL_INIT1)
            send_fc_dllp(INITFC1_NP_D,  FC_NON_POSTED, item, FC_DEDICATED);
            if (p_sequencer.state == DL_INIT1)
            send_fc_dllp(INITFC1_CPL_D, FC_COMPLETION, item, FC_DEDICATED);
            if (cfg.flit_mode_enable) begin
                if (p_sequencer.state == DL_INIT1)
                send_fc_dllp(INITFC1_P_S,   FC_POSTED,     item, FC_SHARED);
                if (p_sequencer.state == DL_INIT1)
                send_fc_dllp(INITFC1_NP_S,  FC_NON_POSTED, item, FC_SHARED);
                if (p_sequencer.state == DL_INIT1)
                send_fc_dllp(INITFC1_CPL_S, FC_COMPLETION, item, FC_SHARED);
            end
            i++;
            if (i == 1000) begin
                `uvm_error(get_type_name(), "Timeout in DL_INIT1")
                break;
            end
        end
    endtask : body

endclass : pcie_fc_init1_seq

`endif

