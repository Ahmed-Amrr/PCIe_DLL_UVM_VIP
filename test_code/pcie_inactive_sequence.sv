class pcie_inactive_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_inactive_seq)

    function new(string name = "pcie_inactive_seq");
        super.new(name);
    endfunction //new()

    task body();
        while (p_sequencer.state == DL_INACTIVE) begin
             item = pcie_dllp_seq_item::type_id::create("item");

              start_item(item);
              finish_item(item);
        end
    endtask

endclass //pcie_inactive_seq extends pcie_base_seq