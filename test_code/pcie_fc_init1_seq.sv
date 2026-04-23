class pcie_fc_init1_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_fc_init1_seq)

    pcie_dllp_seq_item item;

    function new(string name = "pcie_fc_init1_seq");
        super.new(name);
    endfunction

    task body();
        pcie_dllp_seq_item item;
        int i = 0;
        pcie_seq_cb cb;

        item = pcie_dllp_seq_item::type_id::create("item");

        while(p_sequencer.state == DL_INIT1) begin

                // callback registered — let it handle sending
                `uvm_do_callbacks(pcie_base_seq, pcie_seq_cb, do_send_pattern(this, p_sequencer.state))
                                
                // no callback — normal pattern
                send_fc_dllp(INITFC1_P,   FC_POSTED,     item);
                send_fc_dllp(INITFC1_NP,  FC_NON_POSTED, item);
                send_fc_dllp(INITFC1_CPL, FC_COMPLETION, item);

            i++;
            if(i == 1000) begin
                `uvm_error(get_type_name(), "Timeout in DL_INIT1")
                break;
            end
        end

    endtask


endclass
