`ifndef VIP_DRIVER
`define VIP_DRIVER

class vip_driver extends uvm_driver #(/*seq_item*/);
    `uvm_component_utils(vip_driver)

    // virtual lpif_if lpif_vif
    // seq_item   dll_item & tlp ???

    function new(string name = "vip_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction //new()

    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);
    endfunction


    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
    endtask
endclass //vip_driver extends uvm_driver

`endif 