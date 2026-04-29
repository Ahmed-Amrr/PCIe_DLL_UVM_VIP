`ifndef PCIE_TOP_CFG_SV
`define PCIE_TOP_CFG_SV

class pcie_top_cfg extends uvm_object;

    // UVM Factory register
    `uvm_object_utils(pcie_top_cfg)

    // Virtual interface handles — one per side (upstream / downstream)
    virtual lpif_if          u_lpif_vif;
    virtual lpif_if          d_lpif_vif;
    virtual passive_interface u_p_vif  ;
    virtual passive_interface d_p_vif  ;

    // Randomizable test-control flags
    rand bit link_down_test;   // Enable link-down test scenario
    rand bit pl_valid_off  ;   // Deassert pl_valid for valid-off test scenarios
    rand bit common_reset  ;   // Assert reset on both sides simultaneously

    // Constraints — keep error scenarios rare to favour normal operation
    constraint c {
        link_down_test dist {0:=95, 1:=5};
        pl_valid_off        == 0          ;
        common_reset   dist {0:=95, 1:=5};
    }

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_top_cfg");
        super.new(name);
    endfunction : new

endclass : pcie_top_cfg

`endif