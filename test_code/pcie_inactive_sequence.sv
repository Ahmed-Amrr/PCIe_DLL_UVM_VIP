class pcie_inactive_seq extends pcie_base_seq;
    `uvm_object_utils(pcie_inactive_seq)

    function new(string name = "pcie_inactive_seq");
        super.new(name);
    endfunction //new()

    task body();
        for (int i = 0; i < 10; i++) begin
            item = pcie_dllp_seq_item::type_id::create("item");
            
            start_item(item);
            item.rst_req = 1;
            finish_item(item);
        end  
    endtask

endclass //pcie_inactive_seq extends pcie_base_seq