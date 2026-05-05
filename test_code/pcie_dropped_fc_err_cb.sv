`ifndef PCIE_DROPPED_FC_ERR_CB_SV
`define PCIE_DROPPED_FC_ERR_CB_SV

class pcie_dropped_fc_cb extends pcie_seq_cb;

    // UVM Factory register
    `uvm_object_utils(pcie_dropped_fc_cb)

    // Counters
    int unsigned active_cycles = 10;   // Number of iterations to apply the dropped pattern
    int unsigned current_cycle = 0 ;   // Internal iteration counter

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_dropped_fc_cb");
        super.new(name);
    endfunction : new

    //==========================================================
    // do_send_pattern 
    //==========================================================
    // Task : Send FC DLLP subset, dropping one type per iteration       
    virtual task do_send_pattern(pcie_base_seq seq, dl_state_t state);
        pcie_dllp_seq_item item;
        item = pcie_dllp_seq_item::type_id::create("item");

        while (current_cycle < active_cycles) begin
            `uvm_info("DROP_CB", "DROPPED FC", UVM_LOW)
            randcase
                1: begin // DROP_NP  — send P and CPL, omit NP
                    seq.send_fc_dllp(INITFC1_P,   FC_POSTED,     item);
                    seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                end
                1: begin // DROP_CPL — send P and NP, omit CPL
                    seq.send_fc_dllp(INITFC1_P,  FC_POSTED,     item);
                    seq.send_fc_dllp(INITFC1_NP, FC_NON_POSTED, item);
                end
                1: begin // DROP_P   — send NP and CPL, omit P
                    seq.send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
                    seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                end
                1: begin // ONLY_P   — send P only
                    seq.send_fc_dllp(INITFC1_P, FC_POSTED, item);
                end
                1: begin // ONLY_NP  — send NP only
                    seq.send_fc_dllp(INITFC1_NP, FC_NON_POSTED, item);
                end
                1: begin // ONLY_CPL — send CPL only
                    seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                end
            endcase
            current_cycle++;
        end
    endtask : do_send_pattern

endclass : pcie_dropped_fc_cb

`endif

