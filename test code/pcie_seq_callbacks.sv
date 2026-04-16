`ifndef PCIE_CALLBACKS
`define PCIE_CALLBACKS


    class pcie_seq_callbacks extends uvm_callback;
        `uvm_object_utils(pcie_seq_callbacks)

        dl_state_t state;

        function new(string name = "pcie_seq_callbacks");
            super.new(name);
        endfunction

        virtual task do_send_pattern(pcie_fc_init1_seq seq);
            // default: do nothing, normal sequence runs
        endtask

        virtual function bit override_pattern();
            return 0; // default: don't override
        endfunction

    endclass


    class dropped_fc_cb extends pcie_seq_callbacks;
    `uvm_object_utils(dropped_fc_cb)

    function new(string name = "dropped_fc_cb");
        super.new(name);
    endfunction

    virtual function bit override_pattern();
        return 1;
    endfunction

    virtual task do_send_pattern(pcie_fc_init1_seq seq);
        pcie_dllp_seq_item item;
        item = pcie_dllp_seq_item::type_id::create("item");

        while(state == DL_INIT1) begin
            randcase
                10: begin
                    // dropped pattern — randomly pick which combination to drop
                        randcase
                            1: begin // DROP_NP
                                seq.send_fc_dllp(INITFC1_P,   FC_POSTED,     item);
                                seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                            end
                            1: begin // DROP_CPL
                                seq.send_fc_dllp(INITFC1_P,  FC_POSTED,     item);
                                seq.send_fc_dllp(INITFC1_NP, FC_NON_POSTED, item);
                            end
                            1: begin // DROP_P
                                seq.send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
                                seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                            end
                            1: begin // ONLY_P
                                seq.send_fc_dllp(INITFC1_P, FC_POSTED, item);
                            end
                            1: begin // ONLY_NP
                                seq.send_fc_dllp(INITFC1_NP, FC_NON_POSTED, item);
                            end
                            1: begin // ONLY_CPL
                                seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                            end
                        endcase
                     end
                1: begin
                        // normal pattern
                        seq.send_fc_dllp(INITFC1_P,   FC_POSTED,     item);
                        seq.send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
                        seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                    end
            endcase
        end
        
    endtask

endclass

class out_of_order_fc_cb extends pcie_seq_callbacks;
    `uvm_object_utils(dropped_fc_cb)

    function new(string name = "dropped_fc_cb");
        super.new(name);
    endfunction

    virtual function bit override_pattern();
        return 1;
    endfunction

    virtual task do_send_pattern(pcie_fc_init1_seq seq);
        pcie_dllp_seq_item item;
        item = pcie_dllp_seq_item::type_id::create("item");

        while(state == DL_INIT1) begin
            randcase
                10: begin
                    // out of order pattern 
                        randcase
                            1: begin 
                                seq.send_fc_dllp(INITFC1_P,   FC_POSTED, item);
                                seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                                seq.send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
                            end
                            1: begin 
                                seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                                seq.send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
                                seq.send_fc_dllp(INITFC1_P,   FC_POSTED, item);
                            end
                            1: begin 
                                seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                                seq.send_fc_dllp(INITFC1_P,   FC_POSTED, item);
                                seq.send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
                            end
                            1: begin 
                                seq.send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
                                seq.send_fc_dllp(INITFC1_P,   FC_POSTED, item);
                                seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                            end
                            1: begin 
                                seq.send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
                                seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                                seq.send_fc_dllp(INITFC1_P,   FC_POSTED, item);
                            end
                        endcase
                     end
                1: begin
                        // normal pattern
                        seq.send_fc_dllp(INITFC1_P,   FC_POSTED,     item);
                        seq.send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
                        seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
                    end
            endcase
        end
        
    endtask

endclass

`endif