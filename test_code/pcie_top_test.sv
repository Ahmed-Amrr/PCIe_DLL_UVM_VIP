`ifndef PCIE_TOP_TEST_SV
`define PCIE_TOP_TEST_SV

class pcie_top_test_base extends uvm_test;

    // UVM Factory register
    `uvm_component_utils(pcie_top_test_base)

    // Configuration objects
    pcie_top_cfg    top_cfg;
    pcie_vip_config u_cfg  ;
    pcie_vip_config d_cfg  ;

    // Command-line processor and VIP mode strings
    uvm_cmdline_processor clp          ;
    string                up_vip_mode  ;
    string                down_vip_mode;

    // Error mode strings — read from plusargs
    string up_err_mode  ;
    string down_err_mode;

    // Callback instances — null means no error injection for that side
    pcie_vip_driver_cb us_drv_cb;
    pcie_vip_driver_cb ds_drv_cb;
    pcie_seq_cb        us_seq_cb;
    pcie_seq_cb        ds_seq_cb;

    // Handles
    pcie_top_env top_env;

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "PCIe_top_test_base", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    //==========================================================
    // create_driver_callback - Instantiate driver callback by err_mode string
    //==========================================================
    // Function: Returns the matching pcie_vip_driver_cb subclass for the given
    // error mode, or null if no driver-level error injection is needed.
    // Inputs  : err_mode — plusarg error mode string
    //           name     — UVM instance name for the created callback
    // Outputs : pcie_vip_driver_cb handle (null if mode unrecognised)
    function pcie_vip_driver_cb create_driver_callback(string err_mode, string name);
        case (err_mode)
            "crc_err" : begin
                pcie_crc_err_cb cb = pcie_crc_err_cb::type_id::create(name);
                `uvm_info("TEST_CFG", $sformatf("Creating CRC error callback: %s", name), UVM_LOW)
                return cb;
            end
            "dllp_type_err" : begin
                pcie_dllp_type_err_cb cb = pcie_dllp_type_err_cb::type_id::create(name);
                `uvm_info("TEST_CFG", $sformatf("Creating DLLP type error callback: %s", name), UVM_LOW)
                return cb;
            end
            "feature_ack_bit_err" : begin
                pcie_feature_wrong_ack_cb cb = pcie_feature_wrong_ack_cb::type_id::create(name);
                `uvm_info("TEST_CFG", $sformatf("Creating feature error callback: %s", name), UVM_LOW)
                return cb;
            end
            "feature_err" : begin
                pcie_feature_wrong_cb cb = pcie_feature_wrong_cb::type_id::create(name);
                `uvm_info("TEST_CFG", $sformatf("Creating feature error callback: %s", name), UVM_LOW)
                return cb;
            end
            "updatefc_scale_err" : begin
                pcie_updatefc_scale_err_cb cb = pcie_updatefc_scale_err_cb::type_id::create(name);
                `uvm_info("TEST_CFG", $sformatf("Creating UpdateFC scale error callback: %s", name), UVM_LOW)
                return cb;
            end
            "fcupdate_init2_cb" : begin
                pcie_fcupdate_init2_cb cb = pcie_fcupdate_init2_cb::type_id::create(name);
                `uvm_info("TEST_CFG", $sformatf("Creating UpdateFC init2 callback: %s", name), UVM_LOW)
                return cb;
            end
            "fc2_init1_cb" : begin
                pcie_fc2_init1_cb cb = pcie_fc2_init1_cb::type_id::create(name);
                `uvm_info("TEST_CFG", $sformatf("Creating fc2_dllp init1 callback: %s", name), UVM_LOW)
                return cb;
            end
            default : begin
                `uvm_info("TEST_CFG", $sformatf("No driver error injection for mode: %s", err_mode), UVM_LOW)
                return null;
            end
        endcase
    endfunction : create_driver_callback

    //==========================================================
    // create_seq_callback - Instantiate sequence callback by err_mode string
    //==========================================================
    // Function: Returns the matching pcie_seq_cb subclass for the given error
    // mode, or null if no sequence-level error injection is needed.
    // Inputs  : err_mode — plusarg error mode string
    //           name     — UVM instance name for the created callback
    // Outputs : pcie_seq_cb handle (null if mode unrecognised)
    function pcie_seq_cb create_seq_callback(string err_mode, string name);
        case (err_mode)
            "dropped_fc_err" : begin
                pcie_dropped_fc_cb cb = pcie_dropped_fc_cb::type_id::create(name);
                `uvm_info("TEST_CFG", $sformatf("Creating dropped FC callback: %s", name), UVM_LOW)
                return cb;
            end
            "out_of_order_fc_err" : begin
                pcie_out_of_order_fc_cb cb = pcie_out_of_order_fc_cb::type_id::create(name);
                `uvm_info("TEST_CFG", $sformatf("Creating out-of-order FC callback: %s", name), UVM_LOW)
                return cb;
            end
            default : begin
                `uvm_info("TEST_CFG", $sformatf("No sequence error injection for mode: %s", err_mode), UVM_LOW)
                return null;
            end
        endcase
    endfunction : create_seq_callback

    //==========================================================
    // configure_top - Randomize top cfg and assign shared interfaces
    //==========================================================
    // Inputs : top_cfg — top configuration object to populate
    //          u_cfg   — upstream VIP config carrying its interface handles
    //          d_cfg   — downstream VIP config carrying its interface handles
    function void configure_top(ref pcie_top_cfg top_cfg, pcie_vip_config u_cfg, pcie_vip_config d_cfg);
        assert(top_cfg.randomize());

        // Propagate interface handles from each VIP cfg into the shared top cfg
        top_cfg.u_lpif_vif = u_cfg.lpif_vif;
        top_cfg.d_lpif_vif = d_cfg.lpif_vif;
        top_cfg.u_p_vif    = u_cfg.p_vif   ;
        top_cfg.d_p_vif    = d_cfg.p_vif   ;
    endfunction

    //==========================================================
    // configure_vip - Populate a VIP config based on vip_mode string
    //==========================================================
    // Function: Controls feature exchange capability, surprise-down capability, and FC credit values.
    // Random credits are used unless an infinite credit mode is selected for a specific FC type.
    // Inputs : cfg      — VIP config object to populate
    //          vip_mode — plusarg mode string selecting the scenario
    function void configure_vip(ref pcie_vip_config cfg, string vip_mode);

        // Clear reserved and valid fields before configuration
        cfg.remote_register_feature.rsvdz                = 0;
        cfg.local_register_feature.rsvdp                 = 0;
        cfg.remote_register_feature.remote_feature_valid = 0;

        // Feature exchange configuration
        if (vip_mode == "feature_cap_off")
            cfg.feature_exchange_cap = 0;
        else begin
            cfg.feature_exchange_cap = 1;
            cfg.local_register_feature.local_feature_supported =
                (vip_mode == "no_support_scale_fc") ? 0 : 1;
            cfg.local_register_feature.feature_exchange_enable =
                (vip_mode == "feature_disabled")    ? 0 : 1;
        end

        // Surprise-down capability
        cfg.surprise_down_capable = (vip_mode == "surprise_down_capable_off") ? 0 : 1;

        // FC credit configuration — force 0 for infinite credit modes, random otherwise
        cfg.local_fc_credits_register.hdr_credits [FC_COMPLETION] = $random();
        cfg.local_fc_credits_register.data_credits[FC_COMPLETION] = $random();
        cfg.local_fc_credits_register.hdr_credits [FC_POSTED]     = $random();
        cfg.local_fc_credits_register.data_credits[FC_POSTED]     = $random();
        cfg.local_fc_credits_register.hdr_credits [FC_NON_POSTED] = $random();
        cfg.local_fc_credits_register.data_credits[FC_NON_POSTED] = $random();
            
        if (vip_mode == "P_infinite_credits") begin
            cfg.local_fc_credits_register.hdr_credits [FC_POSTED] = 0;
            cfg.local_fc_credits_register.data_credits[FC_POSTED] = 0;
        end
        else if (vip_mode == "NP_infinite_credits") begin
            cfg.local_fc_credits_register.hdr_credits [FC_NON_POSTED] = 0;
            cfg.local_fc_credits_register.data_credits[FC_NON_POSTED] = 0;
        end
        else if (vip_mode == "CPL_infinite_credits") begin
            cfg.local_fc_credits_register.hdr_credits [FC_COMPLETION] = 0;
            cfg.local_fc_credits_register.data_credits[FC_COMPLETION] = 0;
        end
    endfunction : configure_vip

    //==========================================================
    // Build Phase - Create env, read plusargs, configure and set cfgs
    //==========================================================
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        clp = uvm_cmdline_processor::get_inst();

        // Read VIP mode plusargs
        if (clp.get_arg_value("+U_VIP_MODE=", up_vip_mode))
            `uvm_info("TEST_CFG", $sformatf("Setting upper VIP mode to: %s", up_vip_mode), UVM_LOW)
        if (clp.get_arg_value("+D_VIP_MODE=", down_vip_mode))
            `uvm_info("TEST_CFG", $sformatf("Setting down VIP mode to: %s",  down_vip_mode), UVM_LOW)

        // Read error mode plusargs
        if (clp.get_arg_value("+U_ERR_MODE=", up_err_mode))
            `uvm_info("TEST_CFG", $sformatf("Upper error mode: %s", up_err_mode),   UVM_LOW)
        if (clp.get_arg_value("+D_ERR_MODE=", down_err_mode))
            `uvm_info("TEST_CFG", $sformatf("Down error mode: %s",  down_err_mode), UVM_LOW)

        // Create driver-level callbacks for applicable error modes
        if (up_err_mode   inside {"updatefc_scale_err", "crc_err", "dllp_type_err", "feature_err", "feature_ack_bit_err", "fc2_init1_cb", "fcupdate_init2_cb"})
            us_drv_cb = create_driver_callback(up_err_mode,   "us_drv_cb");
        else if (up_err_mode inside {"dropped_fc_err", "out_of_order_fc_err"})
            us_seq_cb = create_seq_callback(up_err_mode,      "us_seq_cb");

        if (down_err_mode inside {"updatefc_scale_err", "crc_err", "dllp_type_err", "feature_err", "feature_ack_bit_err",  "fc2_init1_cb", "fcupdate_init2_cb"})
            ds_drv_cb = create_driver_callback(down_err_mode, "ds_drv_cb");
        else if (down_err_mode inside {"dropped_fc_err", "out_of_order_fc_err"})
            ds_seq_cb = create_seq_callback(down_err_mode,    "ds_seq_cb");

        // Create top-level components
        top_env = pcie_top_env::type_id::create("top_env", this);

        // Create configuration objects
        top_cfg = pcie_top_cfg::type_id::create("top_cfg");
        u_cfg   = pcie_vip_config::type_id::create("u_cfg");
        d_cfg   = pcie_vip_config::type_id::create("d_cfg");

        // Retrieve virtual interfaces from the top module
        if (!uvm_config_db #(virtual lpif_if)::get(this, "", "u_lpif", u_cfg.lpif_vif))
            `uvm_fatal("build_phase", "Test unable to get upper LPIF virtual interface")
        if (!uvm_config_db #(virtual lpif_if)::get(this, "", "d_lpif", d_cfg.lpif_vif))
            `uvm_fatal("build_phase", "Test unable to get lower LPIF virtual interface")
        if (!uvm_config_db #(virtual passive_interface)::get(this, "", "u_p_if", u_cfg.p_vif))
            `uvm_fatal("build_phase", "Test unable to get upper passive virtual interface")
        if (!uvm_config_db #(virtual passive_interface)::get(this, "", "d_p_if", d_cfg.p_vif))
            `uvm_fatal("build_phase", "Test unable to get lower passive virtual interface")

        // Configure and distribute cfg objects to each environment
        configure_vip(u_cfg, up_vip_mode);
        configure_vip(d_cfg, down_vip_mode);
        configure_top(top_cfg, u_cfg, d_cfg);

        uvm_config_db #(pcie_top_cfg)::set(this, "*",               "top_cfg", top_cfg);
        uvm_config_db #(pcie_vip_config)::set(this, "top_env.u_vip*", "vip_cfg", u_cfg);
        uvm_config_db #(pcie_vip_config)::set(this, "top_env.d_vip*", "vip_cfg", d_cfg);

    endfunction : build_phase

    //==========================================================
    // Run Phase - Register callbacks, wait, then deregister
    //==========================================================
    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        phase.raise_objection(this);

        #4000;

        // Register callbacks — null check ensures no injection when not needed
        if (us_drv_cb != null)
            uvm_callbacks #(pcie_vip_driver, pcie_vip_driver_cb)::add(top_env.u_vip.tx_agent.drv, us_drv_cb);
        else if (us_seq_cb != null)
            uvm_callbacks #(pcie_base_seq, pcie_seq_cb)::add(null, us_seq_cb);

        if (ds_drv_cb != null)
            uvm_callbacks #(pcie_vip_driver, pcie_vip_driver_cb)::add(top_env.d_vip.tx_agent.drv, ds_drv_cb);
        else if (ds_seq_cb != null)
            uvm_callbacks #(pcie_base_seq, pcie_seq_cb)::add(null, ds_seq_cb);

        #4000;

        // Deregister driver callbacks after injection window
        if (us_drv_cb != null)
            uvm_callbacks #(pcie_vip_driver, pcie_vip_driver_cb)::delete(top_env.u_vip.tx_agent.drv, us_drv_cb);
        if (ds_drv_cb != null)
            uvm_callbacks #(pcie_vip_driver, pcie_vip_driver_cb)::delete(top_env.d_vip.tx_agent.drv, ds_drv_cb);

        #4000;
        phase.drop_objection(this);
    endtask : run_phase

endclass : pcie_top_test_base

`endif
