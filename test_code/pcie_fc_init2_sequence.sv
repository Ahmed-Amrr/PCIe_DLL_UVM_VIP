`ifndef PCIE_FC_INIT2_SEQUENCE_SV
`define PCIE_FC_INIT2_SEQUENCE_SV

class pcie_fc_init2_seq extends pcie_base_seq;

    // UVM Factory register
    `uvm_object_utils(pcie_fc_init2_seq)

    // Handle
    pcie_dllp_seq_item item;

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_fc_init2_seq");
        super.new(name);
    endfunction : new

    //==========================================================
    // Body - Send INITFC2 triplet each iteration while DL_INIT2
    //==========================================================
    virtual task body();
        // Timeout counter to prevent infinite loop in case of unexpected behavior
        int i = 0;

        while (p_sequencer.state == DL_INIT2) begin

            if (p_sequencer.state == DL_INIT2)
            send_fc_dllp(INITFC2_P_D,   FC_POSTED,     item, FC_DEDICATED);
            if (p_sequencer.state == DL_INIT2)
            send_fc_dllp(INITFC2_NP_D,  FC_NON_POSTED, item, FC_DEDICATED);
            if (p_sequencer.state == DL_INIT2)
            send_fc_dllp(INITFC2_CPL_D, FC_COMPLETION, item, FC_DEDICATED);
            if (cfg.flit_mode_enable) begin
                if (p_sequencer.state == DL_INIT1)
                send_fc_dllp(INITFC2_P_S,   FC_POSTED,     item, FC_SHARED);
                if (p_sequencer.state == DL_INIT1)
                send_fc_dllp(INITFC2_NP_S,  FC_NON_POSTED, item, FC_SHARED);
                if (p_sequencer.state == DL_INIT1)
                send_fc_dllp(INITFC2_CPL_S, FC_COMPLETION, item, FC_SHARED);
            end

            // Timeout guard — break if state has not advanced after 1000 iterations
            if (i == 1000) begin
                `uvm_error(get_type_name(), "Timeout for the seq in DL_INIT2 state")
                break;
            end
            i++;
        end

        `uvm_info(get_type_name(), "Full FC initialization complete", UVM_LOW)
    endtask : body

endclass : pcie_fc_init2_seq

`endif
