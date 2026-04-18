`ifndef DROPPED_FC
`define DROPPED_FC

    class pcie_dropped_fc_cb extends pcie_seq_cb;
        `uvm_object_utils(pcie_dropped_fc_cb)

        int unsigned active_cycles   = 10;  // how many iterations use dropped pattern
        int unsigned current_cycle   = 0;   // internal counter

        function new(string name = "pcie_dropped_fc_cb");
            super.new(name);
        endfunction

        virtual task do_send_pattern(pcie_fc_init1_seq seq, dl_state_t state);

            pcie_dllp_seq_item item;
            item = pcie_dllp_seq_item::type_id::create("item");

           
            if (current_cycle < active_cycles) begin
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
            end else begin
                // normal pattern
                seq.send_fc_dllp(INITFC1_P,   FC_POSTED,     item);
                seq.send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
                seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
            end
           
            current_cycle++;  // increment every time pattern is called

        endtask

    endclass

`endif