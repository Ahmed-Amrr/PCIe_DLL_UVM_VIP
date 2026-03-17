`ifndef PCIE_TOP_CFG
`define PCIE_TOP_CFG 

    class pcie_top_cfg extends uvm_object;
     
     /*-------------------------------------------------------------------------------
     -- UVM Factory register
     -------------------------------------------------------------------------------*/
         // Provide implementations of virtual methods such as get_type_name and create
         `uvm_object_utils(pcie_top_cfg)

         virtual lpif_if u_lpif_vif;
         virtual lpif_if d_lpif_vif;

         bit link_down_test;
         bit GL_error_inj;
         bit pl_valid_off;

     /*-------------------------------------------------------------------------------
     -- Functions
     -------------------------------------------------------------------------------*/
         // Constructor
         function new(string name = "pcie_top_cfg");
             super.new(name);
         endfunction : new

     endclass  

`endif