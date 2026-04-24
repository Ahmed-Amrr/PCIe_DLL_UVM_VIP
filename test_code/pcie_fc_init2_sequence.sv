class pcie_fc_init2_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_fc_init2_seq)

    pcie_dllp_seq_item item;

    function new(string name = "pcie_fc_init2_seq");
        super.new(name);
    endfunction

    virtual task body();
        int i = 0;
        
        // Drive INITFC1 triplets while SM stays in DL_INIT1
       while (p_sequencer.state == DL_INIT2) begin
            send_fc_dllp(INITFC2_P,   FC_POSTED, item);
            send_fc_dllp(INITFC2_NP,  FC_NON_POSTED, item);
            send_fc_dllp(INITFC2_CPL, FC_COMPLETION, item);
            // Counter to count Timeout for each state in order not to stuck 
            if (i == 1000) begin
              `uvm_error(get_type_name(), "Timeout for the seq in DL_INIT2 state")
              break;
            end
            i++;

            int delay;
            assert(std::randomize(delay) with {delay > 0;  delay < 34;});
            #(delay);
       end

        `uvm_info(get_type_name(), "Full FC initialization complete", UVM_LOW)
    endtask


endclass