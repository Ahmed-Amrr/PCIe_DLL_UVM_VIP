class pcie_fc_init1_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_fc_init1_seq)
    `uvm_register_cb(pcie_fc_init1_seq, pcie_seq_cb)

    pcie_dllp_seq_item item;

    function new(string name = "pcie_fc_init1_seq");
        super.new(name);
    endfunction

    virtual task body();

        int i = 0;
        bit cb_override = 0;

        pcie_dllp_seq_item item;
        item = pcie_dllp_seq_item::type_id::create("item");

        while(p_sequencer.state == DL_INIT1) begin
            // check if any callback wants to override
            `uvm_do_callbacks_exit_on(pcie_fc_init1_seq, pcie_seq_cb, override_pattern(), 1, cb_override)

            if(cb_override) begin
                `uvm_do_callbacks(pcie_fc_init1_seq, pcie_seq_cb, do_send_pattern(this))
            end else begin
                // normal pattern
                send_fc_dllp(INITFC1_P,   FC_POSTED,      item);
                send_fc_dllp(INITFC1_NP,  FC_NON_POSTED,  item);
                send_fc_dllp(INITFC1_CPL, FC_COMPLETION,  item);
            end
            i++;
            if(i == 1000) begin
                `uvm_error(get_type_name(), "Timeout in DL_INIT1")
                break;
            end
            // reset cb_override every iteration
            cb_override = 0;
        end

        `uvm_info(get_type_name(), "Full FC initialization complete", UVM_LOW)
    endtask


endclass