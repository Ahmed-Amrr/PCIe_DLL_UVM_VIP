class pcie_dropped_fc_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_dropped_fc_seq)

    function new(string name = "pcie_dropped_fc_seq");
        super.new(name);
    endfunction : new

    virtual task body();

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

