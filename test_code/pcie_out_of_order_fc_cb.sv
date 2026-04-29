`ifndef PCIE_OUT_OF_ORDER_FC_CB_SV
`define PCIE_OUT_OF_ORDER_FC_CB_SV

class pcie_out_of_order_fc_cb extends pcie_seq_cb;

    // UVM Factory register
    `uvm_object_utils(pcie_out_of_order_fc_cb)

    // Counters
    int unsigned active_cycles = 10;   // Number of iterations to apply the out-of-order pattern
    int unsigned current_cycle = 0 ;   // Internal iteration counter

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_out_of_order_fc_cb");
        super.new(name);
    endfunction : new

    //==========================================================
    // do_send_pattern - Send INITFC1 triplet in random order
    //==========================================================
    // Each iteration picks one of five orderings of the P / NP / CPL triplet via randcase
    // to verify the remote handles any arrival order correctly during DL_INIT1
    virtual task do_send_pattern(pcie_base_seq seq, dl_state_t state);
        pcie_dllp_seq_item item;
        item = pcie_dllp_seq_item::type_id::create("item");

        while (current_cycle < active_cycles) begin
            randcase
                1: begin // P → CPL → NP
                    seq.send_fc_dllp(INITFC1_P,   FC_POSTED,     item);
                    seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                    seq.send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
                end
                1: begin // CPL → NP → P
                    seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                    seq.send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
                    seq.send_fc_dllp(INITFC1_P,   FC_POSTED,     item);
                end
                1: begin // CPL → P → NP
                    seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                    seq.send_fc_dllp(INITFC1_P,   FC_POSTED,     item);
                    seq.send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
                end
                1: begin // NP → P → CPL
                    seq.send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
                    seq.send_fc_dllp(INITFC1_P,   FC_POSTED,     item);
                    seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                end
                1: begin // NP → CPL → P
                    seq.send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
                    seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                    seq.send_fc_dllp(INITFC1_P,   FC_POSTED,     item);
                end
            endcase
            current_cycle++;
        end

    endtask : do_send_pattern

endclass : pcie_out_of_order_fc_cb

`endif