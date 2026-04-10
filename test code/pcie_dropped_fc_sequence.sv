class pcie_dropped_fc_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_dropped_fc_seq)

    function new(string name = "pcie_dropped_fc_seq");
        super.new(name);
    endfunction : new

    virtual task body();

        // Randomize credits — same values used in INIT2 1 & INIT2 phases
        if (!super.randomize())
            `uvm_fatal(get_type_name(), "Randomization of FC credits failed")

        // Push randomized values into cfg 
        for (int fc = 0; fc < 3; fc++) begin
            cfg.fc_credits_register.hdr_scale   [fc] = hdr_scale   [fc];
            cfg.fc_credits_register.data_scale  [fc] = data_scale  [fc];
            cfg.fc_credits_register.hdr_credits [fc] = hdr_credits [fc];
            cfg.fc_credits_register.data_credits[fc] = data_credits[fc];
        end

        // Move state machine up to INIT1
        super.start_from_INIT1(item);

        repeat (1000) begin
            send_fc_dllp(INITFC1_P,   FC_POSTED);
            send_fc_dllp(INITFC1_CPL, FC_COMPLETION);
        end
        repeat (1000) begin
            send_fc_dllp(INITFC1_P,   FC_POSTED);
            send_fc_dllp(INITFC1_NP,  FC_NON_POSTED);
        end
        repeat (1000) begin
            send_fc_dllp(INITFC1_NP,  FC_NON_POSTED);
            send_fc_dllp(INITFC1_CPL, FC_COMPLETION);
        end
        repeat (1000) begin
            send_fc_dllp(INITFC1_P,   FC_POSTED);
        end
        repeat (1000) begin
            send_fc_dllp(INITFC1_NP,   FC_NON_POSTED);
        end
        repeat (1000) begin
            send_fc_dllp(INITFC1_CPL, FC_COMPLETION);
        end

        `uvm_info(get_type_name(), "Full FC initialization complete", UVM_LOW)
    endtask : body

endclass : pcie_dropped_fc_seq 

