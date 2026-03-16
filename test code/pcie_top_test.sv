`ifndef PCIE_TOP_TEST
`define PCIE_TOP_TEST

    class pcie_top_test_base extends uvm_test;

        // Provide implementations of virtual methods such as get_type_name and create
        `uvm_component_utils(pcie_top_test_base)

        pcie_top_cfg top_cfg;
        pcie_vip_cfg u_cfg;
        pcie_vip_cfg d_cfg;

        uvm_cmdline_processor clp;
        string seq_name_u;
        string seq_name_d;
        pcie_base_seq seq_u;
        pcie_base_seq seq_d;

        uvm_object obj;
        

        // Constructor
        function new(string name = "PCIe_top_test_base", uvm_component parent=null);
            super.new(name, parent);
        endfunction : new

        function void configure_top (ref pcie_top_cfg top_cfg, pcie_base_seq seq_u, pcie_base_seq seq_d);
            if (seq_u == || seq_d== ) 
                top_cfg.link_down_test = 1;
            else
                top_cfg.link_down_test = 0;


            if (seq_u == || seq_d== ) 
                top_cfg.GL_error_inj = 1;
            else 
                top_cfg.GL_error_inj = 0;

            if (seq_u == || seq_d== ) 
                top_cfg.pl_data_off = 1;
            else 
                top_cfg.pl_data_off = 0;

        endfunction  

        function void configure_vip_u (ref pcie_vip_cfg u_cfg, pcie_base_seq seq_u);
                    
        endfunction 

        function void configure_vip_d (ref pcie_vip_cfg d_cfg, pcie_base_seq seq_d);
                    
        endfunction 

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            // Get command line processor
            clp = uvm_cmdline_processor::get_inst();

            // Read sequence of the upper stream VIP
            if (clp.get_arg_value("+SEQ_U=", seq_name_u)) begin
                uvm_factory::get().set_type_override_by_name(
                  "pcie_base_seq", seq_name_u);

                seq_u = pcie_base_seq::type_id::create("seq_u");
            end

            // Read sequence of the Down stream VIP
            if (clp.get_arg_value("+SEQ_D=", seq_name_d)) begin
                uvm_factory::get().set_type_override_by_name(
                  "pcie_base_seq", seq_name_d);

                seq_d = pcie_base_seq::type_id::create("seq_u");
            end
      
            top_cfg = pcie_top_cfg::type_id::create("top_cfg");  
            u_cfg = pcie_vip_cfg::type_id::create("u_cfg");
            d_cfg = pcie_vip_cfg::type_id::create("d_cfg");                                

            configure_top (top_cfg, seq_u, seq_d);
            configure_vip_u (u_cfg, seq_u);
            configure_vip_d (d_cfg, seq_d);

            uvm_config_db#(pcie_top_cfg)::set(this, "*", "top_cfg", top_cfg);
            uvm_config_db#(pcie_vip_cfg)::set(this, "to be set to the first vip only", "vip_cfg", u_cfg);
            uvm_config_db#(pcie_vip_cfg)::set(this, "to be set to the second vip only", "vip_cfg", d_cfg);

        endfunction : build_phase

        task run_phase(uvm_phase phase);
            super.run_phase(phase);

            phase.raise_objection(this);

                

            phase.drop_objection(this);

        endtask : run_phase
    
    endclass 

`endif