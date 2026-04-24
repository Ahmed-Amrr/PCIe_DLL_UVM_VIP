`ifndef PCIE_TOP_CFG
`define PCIE_TOP_CFG 

    class pcie_top_cfg extends uvm_object;
     
     /*-------------------------------------------------------------------------------
     -- UVM Factory register
     -------------------------------------------------------------------------------*/
         // Provide implementations of virtual methods such as get_type_name and create
         `uvm_object_utils(pcie_top_cfg)

         // Holding virtual interfaces for bothe sides
         virtual lpif_if u_lpif_vif;
         virtual lpif_if d_lpif_vif;

        rand bit link_down_test;        // Signal to configure linkdown testcases
        rand bit pl_valid_off;          // Signal to configure Valid off interface testcases
        rand common_reset;
        constraint c {
            link_down_test dist {0:=99, 1:=1};
            pl_valid_off dist {0:=99, 1:=1};
            common_reset dist {0:=99, 1:=1};
        }

     /*-------------------------------------------------------------------------------
     -- Functions
     -------------------------------------------------------------------------------*/
         // Constructor
         function new(string name = "pcie_top_cfg");
             super.new(name);
         endfunction : new

     endclass  

`endif