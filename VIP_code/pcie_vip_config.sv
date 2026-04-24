`ifndef PCIE_VIP_CONFIG
`define PCIE_VIP_CONFIG

class pcie_vip_config extends uvm_object;
    `uvm_object_utils (pcie_vip_config)

     // virtal interface handle    
     virtual lpif_if lpif_vif;

     // Configuration registers
     // these types are declared in dll_pkg.sv
     dl_feature_cap_reg_t local_register_feature;       //for feature "Scaled Flow Control" the only important bits are
                                                        //feature_exchange_enable and local_feature_supported [0] (Supported or not)
     dl_feature_status_reg_t remote_register_feature;   //for feature "Scaled Flow Control" the only important bits are
                                                        //remote_feature_valid and remote_feature_supported [0] (Supported or not)
     // the other bits are reserved must be 0s.

     fc_credits_t fc_credits_register;                  //for "hdr_credits & data_credits" are for the credits counter
                                                        //for "hdr_scale & data_scale" are for the scale
     fc_credits_t remote_fc_credits_register;

     rand bit reset;


    bit feature_exchange_cap;
    bit scaled_fc_active;

    bit surprise_down_capable;
    rand bit link_not_disabled;

    constraint c {
            link_not_disabled dist {0:=99, 1:=1};
            reset dist {0:=99, 1:=1};
        }

     function new (string name ="pcie_vip_config");
      super.new(name);
     endfunction
endclass

`endif