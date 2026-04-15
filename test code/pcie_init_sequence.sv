`ifndef PCIE_INIT1_SEQUENCE_SV
`define PCIE_INIT1_SEQUENCE_SV

class pcie_init1_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_init1_seq)

    function new(string name = "pcie_init1_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        int i = 0;

        `uvm_info(get_type_name(), "Starting FC INIT1 Sequence", UVM_LOW)

        while (p_sequencer.state == DL_INIT1) begin

            // Posted
            item = pcie_dllp_seq_item::type_id::create("item");
            start_item(item);
            assert(item.randomize() with {
                dllp[47:40] == INITFC1_P;
                dllp[39:38] == cfg.fc_credits_register.hdr_scale[FC_POSTED];
                dllp[37:30] == cfg.fc_credits_register.hdr_credits[FC_POSTED];
                dllp[29:28] == cfg.fc_credits_register.data_scale[FC_POSTED];
                dllp[27:16] == cfg.fc_credits_register.data_credits[FC_POSTED];
            });
            finish_item(item);

            // Non Posted
            item = pcie_dllp_seq_item::type_id::create("item");
            start_item(item);
            assert(item.randomize() with {
                dllp[47:40] == INITFC1_NP;
                dllp[39:38] == cfg.fc_credits_register.hdr_scale[FC_NON_POSTED];
                dllp[37:30] == cfg.fc_credits_register.hdr_credits[FC_NON_POSTED];
                dllp[29:28] == cfg.fc_credits_register.data_scale[FC_NON_POSTED];
                dllp[27:16] == cfg.fc_credits_register.data_credits[FC_NON_POSTED];
            });
            finish_item(item);

            // Completion
            item = pcie_dllp_seq_item::type_id::create("item");
            start_item(item);
            assert(item.randomize() with {
                dllp[47:40] == INITFC1_CPL;
                dllp[39:38] == cfg.fc_credits_register.hdr_scale[FC_COMPLETION];
                dllp[37:30] == cfg.fc_credits_register.hdr_credits[FC_COMPLETION];
                dllp[29:28] == cfg.fc_credits_register.data_scale[FC_COMPLETION];
                dllp[27:16] == cfg.fc_credits_register.data_credits[FC_COMPLETION];
            });
            finish_item(item);

            i++;
            if (i == 1000) begin
                `uvm_error(get_type_name(), "Timeout for the seq in DL_INIT1 state")
                break;
            end

        end

        `uvm_info(get_type_name(), "FC INIT1 Sequence Finished", UVM_LOW)
    endtask : body

endclass : pcie_init1_seq

`endif