`ifndef OUT_ORDER_FC
`define OUT_ORDER_FC

    class pcie_out_of_order_fc_cb extends pcie_seq_cb;
        `uvm_object_utils(pcie_out_of_order_fc_cb)

        int unsigned active_cycles   = 10;  // how many iterations use dropped pattern
        int unsigned current_cycle   = 0;   // internal counter

        function new(string name = "pcie_out_of_order_fc_cb");
            super.new(name);
        endfunction

        virtual function bit override_pattern();
        // only override for the first 'active_cycles' iterations
            if(current_cycle < active_cycles)
                return 1;
            else
                return 0;  // ← after limit reached, go back to normal
        endfunction


        virtual task do_send_pattern(pcie_fc_init1_seq seq, dl_state_t state);
            pcie_dllp_seq_item item;
            item = pcie_dllp_seq_item::type_id::create("item");

            if (current_cycle < active_cycles) begin
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
            else begin
                // normal pattern
                seq.send_fc_dllp(INITFC1_P,   FC_POSTED,     item);
                seq.send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
                seq.send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
            end   
            current_cycle++;        
        endtask

    endclass

`endif