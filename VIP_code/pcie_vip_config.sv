`ifndef PCIE_VIP_CONFIG_SV
`define PCIE_VIP_CONFIG_SV

class pcie_vip_config extends uvm_object;

    // UVM Factory register
    `uvm_object_utils(pcie_vip_config)

    // Virtual interface handles, one to LPIF and one to passive side of the VIP (for assertions)
    virtual lpif_if           lpif_vif;
    virtual passive_interface p_vif   ;

    // Feature Exchange Registers
    dl_feature_cap_reg_t    local_register_feature ;
    dl_feature_status_reg_t remote_register_feature;

    // FC Credit Registers
    fc_credits_t local_fc_credits_register ;
    fc_credits_t remote_fc_credits_register;

    // Control Flags
    bit reset               ;   // Active-high reset signal
    bit feature_exchange_cap;   // Enables feature exchange capability
    bit scaled_fc_active    ;   // Indicates scaled FC is currently active

    // Randomizable capability flags
    rand bit surprise_down_capable;
    rand bit link_not_disabled    ;

    // Constraints — keep disabled/incapable scenarios rare
    constraint c {
        link_not_disabled     dist {0:=1,  1:=99};
        surprise_down_capable dist {0:=1,  1:=99};
    }

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_vip_config");
        super.new(name);
    endfunction : new

endclass

`endif