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
            send_fc_dllp(INITFC1_P,   FC_POSTED,     item);
            if (p_sequencer.state == DL_INIT1)
            send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
            if (p_sequencer.state == DL_INIT1)
            send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);

            i++;
            if (i == 1000) begin
                `uvm_error(get_type_name(), "Timeout in DL_INIT1")
                break;
            end
        end
    endtask : body

endclass : pcie_fc_init1_seq

`endif

