`ifndef PCIE_TOP_TEST
`define PCIE_TOP_TEST

    class pcie_top_test_base extends uvm_test;

        // Provide implementations of virtual methods such as get_type_name and create
        `uvm_component_utils(pcie_top_test_base)

        // Configuraton objects
        pcie_top_cfg top_cfg;
        pcie_vip_config u_cfg;
        pcie_vip_config d_cfg;

        // Seguence specific signals 
        uvm_cmdline_processor clp;
        string seq_name_u;
        string seq_name_d;
        pcie_base_seq seq_u;
        pcie_base_seq seq_d;

        // getiing test type from the cmd line
        string up_vip_mode;
        string down_vip_mode;

        // Virtual sequence
        vseq_base vseq;

        // top environment 
        pcie_top_env top_env;

        // Constructor
        function new(string name = "PCIe_top_test_base", uvm_component parent=null);
            super.new(name, parent);
        endfunction : new

        // Function to configure the top cfg testcases based of the sequences
        function void configure_top (ref pcie_top_cfg top_cfg, string up_vip_mode, string down_vip_mode, pcie_vip_config u_cfg, pcie_vip_config d_cfg);
            
            // Control nop for the link_up signal
            if (up_vip_mode == "link_down_test" || down_vip_mode == "link_down_test") 
                assert(top_cfg.randomize() with {link_down_test == 1;});

            // Control nop for the valid signal in interface
            else if (up_vip_mode == "valid_off_test" || down_vip_mode == "valid_off_test") 
                assert(top_cfg.randomize() with {pl_valid_off == 1;});
            else
                assert(top_cfg.randomize());

            // Getting the upper and lower interfaces from each environment cfg
            top_cfg.u_lpif_vif = u_cfg.lpif_vif;
            top_cfg.d_lpif_vif = d_cfg.lpif_vif;

        endfunction  

        // Functions to configure each enviroment register based on the current sequence
        function void configure_vip (ref pcie_vip_config cfg, string vip_mode);

            // Control nops to initialize the feature registers
            if (vip_mode == "feature_cap_off") 
                cfg.feature_exchange_cap = 0;
            else begin
                cfg.feature_exchange_cap = 1;
                cfg.local_register_feature.local_feature_supported = 1;
                cfg.remote_register_feature.remote_feature_valid = 0;
                if (vip_mode == "feature_disabled") 
                    cfg.local_register_feature.feature_exchange_enable = 0;
                else 
                    cfg.local_register_feature.feature_exchange_enable = 1;
            end


            // Control nop for surprise_down_capability
            if (vip_mode == "surprise_down_capable_off") 
                cfg.surprise_down_capable = 0;
            else
                cfg.surprise_down_capable = 1;


           // Control nops for the control credits and scale
            if (vip_mode == "P_infinite_credits") 
                assert(cfg.randomize() with { fc_credits_register.hdr_credits[FC_POSTED] == 0;
                                        fc_credits_register.data_credits[FC_POSTED] == 0; });
            
            else if (vip_mode == "NP_infinite_credits") 
                assert(cfg.randomize() with { fc_credits_register.hdr_credits[FC_NON_POSTED] == 0;
                                        fc_credits_register.data_credits[FC_NON_POSTED] == 0; });
            
            else if (vip_mode == "CPL_infinite_credits") 
                assert(cfg.randomize() with { fc_credits_register.hdr_credits[FC_COMPLETION] == 0;
                                        fc_credits_register.data_credits[FC_COMPLETION] == 0; });

            else if (vip_mode == "scaledFC_not_supported") 
                assert(cfg.randomize() with { fc_credits_register.hdr_scale[FC_COMPLETION] == '{default:0};
                                        fc_credits_register.data_scale[FC_COMPLETION] == '{default:0};});
            else
                assert(cfg.randomize());
                       
        endfunction 


        function void build_phase(uvm_phase phase);
            super.build_phase(phase); 

            // Get command line processor
            clp = uvm_cmdline_processor::get_inst();

            // Read test type from the cmd line
            if (clp.get_arg_value("+U_VIP_MODE=", up_vip_mode)) begin
                `uvm_info("TEST_CFG", $sformatf("Setting upper vip mode to: %s", up_vip_mode), UVM_LOW)
            end
            if (clp.get_arg_value("+D_VIP_MODE=", down_vip_mode)) begin
                `uvm_info("TEST_CFG", $sformatf("Setting down vip mode to: %s", down_vip_mode), UVM_LOW)
            end

            // Read sequence of the upper stream VIP
            // 1. Setup Upstream
            if (clp.get_arg_value("+SEQ_U=", seq_name_u)) begin
                // Override ONLY for the instance named "seq_u"
                uvm_factory::get().set_inst_override_by_name(
                    "pcie_base_seq", seq_name_u, "uvm_test_top.seq_u" 
                );
            end

            // 2. Setup Downstream
            if (clp.get_arg_value("+SEQ_D=", seq_name_d)) begin
                // Override ONLY for the instance named "seq_d"
                uvm_factory::get().set_inst_override_by_name(
                    "pcie_base_seq", seq_name_d, "uvm_test_top.seq_d"
                );
            end

            top_env = pcie_top_env::type_id::create("top_env",this); 
            vseq = vseq_base::type_id::create("vseq");

            // Create sequences - The factory chooses based on the name argument
            seq_u = pcie_base_seq::type_id::create("seq_u"); // Becomes SEQ_U type
            seq_d = pcie_base_seq::type_id::create("seq_d"); // Becomes SEQ_D type

            // Create configuration objects
            top_cfg = pcie_top_cfg::type_id::create("top_cfg");  
            u_cfg = pcie_vip_config::type_id::create("u_cfg");
            d_cfg = pcie_vip_config::type_id::create("d_cfg");  

            // Retriving the virtual interfaces from top
            if (!(uvm_config_db#(virtual lpif_if)::get(this, "", "u_lpif", u_cfg.lpif_vif))) 
                `uvm_fatal("build_phase", "Test unable to get upper vitual interface from top module");
            if (!(uvm_config_db#(virtual lpif_if)::get(this, "", "d_lpif", d_cfg.lpif_vif))) 
                `uvm_fatal("build_phase", "unable to get lower vitual interface from top module");



            // Call configure functions 
            configure_vip (u_cfg, up_vip_mode);
            configure_vip (d_cfg, down_vip_mode);
            configure_top (top_cfg, up_vip_mode, down_vip_mode, u_cfg, d_cfg);


            // Use an CRC error injection driver in this mode
            if (up_vip_mode == "crc_err_inj") begin
                set_inst_override_by_type(
                    "top_env.u_vip.*",
                    pcie_vip_driver::get_type(),
                    pcie_vip_err_driver::get_type()
                );
            end

            if (down_vip_mode == "crc_err_inj") begin
                set_inst_override_by_type(
                    "top_env.d_vip.*",
                    pcie_vip_driver::get_type(),
                    pcie_vip_err_driver::get_type()
                );
            end



            // Set the CFGs to the corresponding enviroments 
            uvm_config_db#(pcie_top_cfg)::set(this, "*", "top_cfg", top_cfg);
            uvm_config_db#(pcie_vip_config)::set(this, "top_env.u_vip.*", "vip_cfg", u_cfg);
            uvm_config_db#(pcie_vip_config)::set(this, "top_env.d_vip.*", "vip_cfg", d_cfg);

        endfunction : build_phase


        task run_phase(uvm_phase phase);
            super.run_phase(phase);

            phase.raise_objection(this);

              vseq.us_seq = seq_u;
              vseq.ds_seq = seq_d;

              vseq.start(top_env.vsqr);  

            phase.drop_objection(this);

        endtask : run_phase
    
    endclass 

`endif