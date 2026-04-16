class pcie_fc_init1_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_fc_init1_seq)

    pcie_dllp_seq_item item;

    function new(string name = "pcie_fc_init1_seq");
        super.new(name);
    endfunction

    virtual task body();

        // Move state machine up to INIT1
        int i = 0;
        super.start_from_INIT1(item);
        // Drive INITFC1 triplets while SM stays in DL_INIT1
        while(p_sequencer.state == DL_INIT1) begin
            send_fc_dllp(INITFC1_P,   FC_POSTED, item);
            send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
            send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);
            i++;
            // Counter to count Timeout for each state in order not to stuck 
            if (i == 1000) begin
              `uvm_error(get_type_name(), "Timeout for the seq in DL_INIT1 state")
              break;
            end
        end

        `uvm_info(get_type_name(), "Full FC initialization complete", UVM_LOW)
    endtask


endclass