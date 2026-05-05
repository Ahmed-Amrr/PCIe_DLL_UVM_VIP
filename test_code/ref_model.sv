`ifndef REF_MODEL_SV
`define REF_MODEL_SV
import dll_pkg::*;
import uvm_pkg::*;
  `include "uvm_macros.svh"
class dll_ref_model #(
    parameter int DLLP_WIDTH       = 48,
    parameter int PAYLOAD_WIDTH    = 32,  
    parameter int CRC_WIDTH        = 16,
    parameter int BYTE             = 8 ,
    parameter int PAYLOAD_IN_BYTES = PAYLOAD_WIDTH / BYTE
);

    pcie_vip_config cfg;

    bit [CRC_WIDTH-1:0] generator_polynomial;
    bit [CRC_WIDTH-1:0] initial_seed        ;


    dl_state_t   current_state;              // DL state machine
    dl_state_t   next_state;
    bit          FI1, FI2;                   // flags to exit init1 / init2 states
    bit          fi1_p, fi1_np, fi1_cpl;     // per-type trackers for FI1
    bit          scaled_fc_active;
    dl_feature_status_reg_t remote_register_feature; 
    fc_credits_t local_fc ;                  // credits advertised by this VIP
    fc_credits_t remote_fc;                  // credits received from peer
    bit hdr_infinite [3];                    // infinite credits from initialization
    bit data_infinite[3];
    
    bit [1:0] local_hdr_scale;               // scaling factor for header credits
    bit [1:0] local_data_scale;              // scaling factor for data credits
    int       initfc1_tx_count;              // tracks P/NP/Cpl TX order in INIT1
    int       initfc2_tx_count;              // tracks P/NP/Cpl TX order in INIT2

    function new();
        this.generator_polynomial = 'h100B;
        this.initial_seed         = 'hFFFF;  
        this.current_state        = DL_INACTIVE;
        this.local_fc             = '0;
        this.remote_fc            = '0;
        this.FI1                  = 0;
        this.FI2                  = 0;
        this.local_hdr_scale  = 2'b01; 
        this.local_data_scale = 2'b01; 
        this.initfc1_tx_count = 0;
        this.initfc2_tx_count = 0;
        this.cfg              = null;       // set by scoreboard 
        this.next_state       = DL_INACTIVE; 
    endfunction : new

    // Function rx_path : Main RX path function. Processes a received DLLP through the full
    //                    pipeline : CRC verification → legality check → DLLP processing → state machine update.
    // Inputs  : 48-bit received DLLP, physical link up indicator, reset signal, physical layer valid signal
    // Outputs : DL Down/Up status signals,
    //           _surprise_down_event —> Indicates unexpected ACTIVE → INACTIVE transition
    function void rx_path (
        logic [DLLP_WIDTH-1:0] _rx_item,
        bit                    _pl_lnk_up,
        bit                    _dl_reset,
        bit                    _pl_valid,
        output bit             _DL_Down,
        output bit             _DL_Up,
        output bit             _surprise_down_event
    );

        // local variables
        dllp_type_t dllp_type;
        bit         should_discard;
        logic       is_legal;
        logic       state_changed;

        // defaults 
        _surprise_down_event = 1'b0;
        get_dl_status(this.current_state, _DL_Down, _DL_Up);

        // cfg guard 
        if (cfg == null) begin
            `uvm_fatal("DLL_RM", "[rx_path] cfg handle is null — set ref_model.cfg before calling rx_path")
            return;
        end

        // decode DLLP type 
        dllp_type = get_dllp_type(_rx_item);
        this.current_state = this.next_state;

        if (_dl_reset || !_pl_lnk_up) begin
            this.next_state = DL_INACTIVE;
        end

        // DL_INACTIVE : only drive state machine
        // skip CRC and legality checks in INACTIVE
        if (this.current_state == DL_INACTIVE) begin
            fi1_p   = 0;
            fi1_np  = 0;
            fi1_cpl = 0;
            FI1     = 0;
            FI2     = 0;
        end

         // CRC verification 
        should_discard = verify_rx_crc(_rx_item);
        if (should_discard && (this.next_state != DL_INACTIVE)) begin
            get_dl_status(this.current_state, _DL_Down, _DL_Up);
            `uvm_error("DLL_RM",
                $sformatf("[rx_path] CRC discard: state=%s type=%s pl_lnk_up=%0b reset=%0b dllp=0x%012h",
                          this.current_state.name(), dllp_type.name(), _pl_lnk_up, _dl_reset, _rx_item))
            return;
        end else begin
            // legality check → DLLP processing → SM update
            is_legal = check_rx_legality(dllp_type, this.current_state, _pl_valid);
            `uvm_info("DLL_RM",
                $sformatf("[rx_path] legality=%0b state=%s type=%s",
                          is_legal, this.current_state.name(), dllp_type.name()), UVM_MEDIUM)
            if (this.current_state != DL_INACTIVE)
                process_rx_dllp(dllp_type, _rx_item, _pl_valid);

            update_sm_on_rx(dllp_type, _rx_item, this.current_state,
                            _pl_lnk_up, _dl_reset, _pl_valid,
                            this.FI1, this.FI2,
                            cfg.surprise_down_capable,
                            cfg.link_not_disabled,
                            this.next_state, state_changed, _surprise_down_event);

            get_dl_status(this.current_state, _DL_Down, _DL_Up);

            `uvm_info("DLL_RM",
                $sformatf("[rx_path] next_state=%s DL_Up=%0b DL_Down=%0b surprise_down=%0b",
                          this.current_state.name(), _DL_Up, _DL_Down, _surprise_down_event), UVM_MEDIUM)
        end

    endfunction : rx_path
    
    // Function verify_rx_crc : Calculate the CRC-16 over the received DLLP and compare it against the CRC field carried in rx_item.
    // Inputs : 48-bit DLLP 
    // Returns : 1 when mismatch is detected (discard), 0 otherwise
    function bit verify_rx_crc (input logic [DLLP_WIDTH-1:0] _rx_item);

        bit [CRC_WIDTH-1:0] rx_crc  ;
        bit [CRC_WIDTH-1:0] calc_crc; 
        bit [PAYLOAD_WIDTH-1:0] payload_wo_crc;

        payload_wo_crc = _rx_item[DLLP_WIDTH-1:CRC_WIDTH];
        rx_crc = _rx_item[CRC_WIDTH-1:0];
        calc_crc = crc_calc(payload_wo_crc);

        if (rx_crc != calc_crc) begin
            verify_rx_crc = 1'b1;
            `uvm_info("DLL_RM",
                $sformatf("[verify_rx_crc] CRC mismatch. Calculated=0x%04h Received=0x%04h FullDLLP=0x%012h Payload[31:0]=0x%08h TypeByte=0x%02h",
                          calc_crc, rx_crc, _rx_item, payload_wo_crc, _rx_item[47:40]),
                UVM_MEDIUM)
        end else begin
            verify_rx_crc = 1'b0;
            `uvm_info("DLL_RM", "[verify_rx_crc] CRC OK", UVM_HIGH)
        end
    endfunction : verify_rx_crc

    // Function check_rx_legality : Verifies that the received DLLP type is legal in the current DL state
    // Inputs  : type of received DLLP, current DL state, physical layer valid signal
    // Returns : 1 when received dllp is legal , 0 otherwise
    function bit check_rx_legality (
        dllp_type_t _dllp_type,
        dl_state_t  _current_state,
        bit         _pl_valid
    );
    
        if (_pl_valid) begin
            if (!$isunknown(_dllp_type)) begin
                case (_current_state)

                    // no DLLPs should be accepted in INACTIVE
                    DL_INACTIVE: begin
                        `uvm_info("DLL_RM",
                            $sformatf("[check_rx_legality] Illegal DLLP received in DL_INACTIVE. received=%s",
                                    _dllp_type.name()), UVM_LOW)
                        return 0;
                    end

                    // FEATURE and INITFC1 are allowed in DL_FEATURE.
                    DL_FEATURE: begin
                        if (!(_dllp_type inside {FEATURE, INITFC1_P, INITFC1_NP, INITFC1_CPL})) begin
                            `uvm_info("DLL_RM",
                                $sformatf("[check_rx_legality] Illegal DLLP in DL_FEATURE. received=%s allowed={FEATURE,INITFC1_P,INITFC1_NP,INITFC1_CPL}",
                                        _dllp_type.name()), UVM_LOW)
                            return 0;
                        end
                    end

                    // FEATURE, INITFC1, and INITFC2 are allowed in DL_INIT1.
                    DL_INIT1: begin
                        if (!(_dllp_type inside {FEATURE, INITFC1_P, INITFC1_NP, INITFC1_CPL,
                                                        INITFC2_P, INITFC2_NP, INITFC2_CPL})) begin
                            `uvm_info("DLL_RM",
                                $sformatf("[check_rx_legality] Illegal DLLP in DL_INIT1. received=%s allowed={FEATURE,INITFC1_P,INITFC1_NP,INITFC1_CPL,INITFC2_P,INITFC2_NP,INITFC2_CPL}",
                                        _dllp_type.name()), UVM_LOW)
                            return 0;
                        end
                    end

                    // FEATURE, ACK, and NACK are forbidden in DL_INIT2.
                    DL_INIT2: begin
                        if (_dllp_type inside {FEATURE, ACK, NACK}) begin
                            `uvm_info("DLL_RM",
                                $sformatf("[check_rx_legality] Illegal DLLP in DL_INIT2. received=%s forbidden={FEATURE,ACK,NACK}",
                                        _dllp_type.name()), UVM_LOW)
                            return 0;
                        end
                    end

                    // In DL_ACTIVE, FEATURE is forbidden.
                    DL_ACTIVE: begin
                        if (_dllp_type == FEATURE) begin
                            `uvm_info("DLL_RM",
                                $sformatf("[check_rx_legality] Illegal DLLP in DL_ACTIVE. received=%s forbidden={FEATURE}",
                                        _dllp_type.name()), UVM_LOW)
                            return 0;
                        end
                    end
                endcase
            end
        end

        return 1; // legal by default

    endfunction : check_rx_legality
    
    // Function process_rx_dllp : Processes a received DLLP based on its type and the current DL state.
    //                            Handles FC initialization, feature exchange, and UpdateFC credit recording.
    //                            All processing is gated on pl_valid being asserted.
    // Inputs  :  type of received DLLP, 48-bit DLLP, physical layer valid signal
    function void process_rx_dllp (
        dllp_type_t            _dllp_type,
        logic [DLLP_WIDTH-1:0] _dllp,
        bit                    _pl_valid
    );

        if (_pl_valid) begin
            case (_dllp_type)

                INITFC1_P, INITFC1_NP, INITFC1_CPL: begin
                    if (this.current_state == DL_INIT1) begin
                        record_fc_values(_dllp);
                         update_fi_flags(_dllp_type, 0); // FI1
                    end
                end

                INITFC2_P, INITFC2_NP, INITFC2_CPL: begin
                    // In INIT1 : record credits and track reception order
                    if (this.current_state == DL_INIT1) begin
                        record_fc_values(_dllp);
                        update_fi_flags(_dllp_type, 0); // FI1
                    // In INIT2 : any InitFC2 received asserts FI2
                    end else if (this.current_state == DL_INIT2) begin
                        update_fi_flags(_dllp_type, 1); // FI2
                    end
                end

                FEATURE: begin
                    if (this.current_state == DL_FEATURE) begin
                        // First FEATURE DLLP received : record remote features and assert valid bit
                        if (remote_register_feature.remote_feature_valid == 1'b0) begin
                            record_Feature_Supported_field(_dllp);
                            remote_register_feature.remote_feature_valid = 1'b1;
                        end else
                            activate_dl_feature(); // Activate negotiated features once valid is set
                    end
                end

                UPDATEFC_P, UPDATEFC_NP, UPDATEFC_CPL: begin
                    // in INIT2 : any UpdateFC received asserts FI2
                    if (this.current_state == DL_INIT2)
                        this.FI2 = 1;

                    // in ACTIVE : update credits only if no FCPE violation detected
                    if (this.current_state == DL_ACTIVE)
                        if (!check_FCPE(_dllp))
                            record_fc_values(_dllp);
                end

            endcase
        end

    endfunction : process_rx_dllp

    // Function record_Feature_Supported_field : Stores the remote feature supported field from a received FEATURE DLLP.
    // Input   : 48-bit FEATURE DLLP
    function void record_Feature_Supported_field (bit [DLLP_WIDTH-1:0] _dllp);

        remote_register_feature.remote_feature_supported = _dllp[38:16];

    endfunction : record_Feature_Supported_field

    // Function activate_dl_feature : Activates negotiated DL features after feature exchange completes. 
    // Scaled Flow Control (bit 0) is enabled only if supported by both local and remote ports.
    function void activate_dl_feature ();

        scaled_fc_active = remote_register_feature.remote_feature_supported[0]
                         & cfg.local_register_feature.local_feature_supported[0];

    endfunction : activate_dl_feature

    // Function record_fc_values : Stores remote FC credit values from a received FC DLLP.
    //                             If scaled FC is active, scale fields are also recorded.
    //                             During initialization, detects infinite credit advertisement
    // Input   : 48-bit FC DLLP
    function void record_fc_values (bit [DLLP_WIDTH-1:0] _dllp);

        fc_type_t fc;

        // Decode FC type (P / NP / CPL).
        fc = decode_fc_type(get_dllp_type(_dllp));

        // Extract remote credit values.
        remote_fc.hdr_credits [fc] = _dllp[37:30];
        remote_fc.data_credits[fc] = _dllp[27:16];

        // Extract scale values when scaled flow control is active.
        if (scaled_fc_active) begin
            remote_fc.hdr_scale [fc] = _dllp[39:38];
            remote_fc.data_scale[fc] = _dllp[29:28];
        end

        // during initialization phase, detect infinite credit advertisement
        // infinite credit : hdr_credits = 00h or data_credits = 000h
        if (this.FI1 == 1 && this.FI2 == 0) begin
            if (remote_fc.hdr_credits [fc] == 0) hdr_infinite[fc]  = 1;
            if (remote_fc.data_credits[fc] == 0) data_infinite[fc] = 1;
        end

        `uvm_info("DLL_RM",
            $sformatf("[record_fc_values] TYPE=%0d HDR=%0d DATA=%0d",
                      fc, remote_fc.hdr_credits[fc], remote_fc.data_credits[fc]), UVM_MEDIUM)

    endfunction : record_fc_values

    // Function update_fi_flags : Tracks the reception order of FC DLLPs (P → NP → CPL)
    //           and asserts the corresponding FI flag (FI1 or FI2)
    // Input   : type of received DLLP,
    //           is_init2  : 0 → FI1 tracking, 1 → FI2 tracking
    function void update_fi_flags (
        dllp_type_t _dllp_type,
        bit         is_init2
    );

        case (_dllp_type)

            INITFC1_P, INITFC2_P: begin
                // Posted must come first — NP and CPL must not be set yet
                if (fi1_p || fi1_np || fi1_cpl) begin
                    if (remote_register_feature.remote_feature_valid)
                        `uvm_error("DLL_RM", "[update_fi_flags] ORDER VIOLATION — P received after P or NP or CPL")
                    else
                        `uvm_warning("DLL_RM", "[update_fi_flags] ORDER VIOLATION — P received after P or NP or CPL")
                    fi1_p = 1;
                    fi1_np = 0;
                    fi1_cpl =0;
                end
                else begin
                    fi1_p = 1;
                    `uvm_info("DLL_RM", "[update_fi_flags] P credits recorded", UVM_HIGH)
                end
            end

            INITFC1_NP, INITFC2_NP: begin
                // NP must come after P and before CPL
                if (!fi1_p || fi1_np || fi1_cpl) begin
                    if (remote_register_feature.remote_feature_valid)
                        `uvm_error("DLL_RM", "[update_fi_flags] ORDER VIOLATION — NP received before P or received after NP,CPL")
                    else
                        `uvm_warning("DLL_RM", "[update_fi_flags] ORDER VIOLATION — NP received before P or received after NP,CPL")
                    fi1_np = 0;
                    fi1_cpl =0;
                end
                else begin
                    fi1_np = 1;
                    fi1_p = 0;
                    `uvm_info("DLL_RM", "[update_fi_flags] NP credits recorded", UVM_HIGH)
                end
            end

            INITFC1_CPL, INITFC2_CPL: begin
                // CPL must come after both P and NP
                if (!fi1_np)begin
                    if (remote_register_feature.remote_feature_valid)
                        `uvm_error("DLL_RM", "[update_fi_flags] ORDER VIOLATION — CPL received before P or NP")
                    else
                        `uvm_warning("DLL_RM", "[update_fi_flags] ORDER VIOLATION — CPL received before P or NP")
                end
                else begin
                    fi1_cpl = 1;
                    fi1_np = 0;
                    `uvm_info("DLL_RM", "[update_fi_flags] CPL credits recorded", UVM_HIGH)
                end
            end

        endcase

        // FI1/FI2 set only when all three received in order
        if (fi1_cpl) begin

            if (is_init2)
                this.FI2 = 1;
            else
                this.FI1 = 1;

            // Reset the ordering trackers.
            fi1_p   = 0;
            fi1_np  = 0;
            fi1_cpl = 0;

            `uvm_info("DLL_RM",
                is_init2 ? "[FI2] SET — P/NP/CPL received"
                        : "[FI1] SET — P/NP/CPL received",
                UVM_MEDIUM)
        end

    endfunction : update_fi_flags

    // Function check_FCPE : Validates an UpdateFC DLLP against the FC Protocol Error (FCPE) rules.
    //                       Credits advertised as infinite during init must remain zero in UpdateFC.
    //                       If scaled FC is active, HdrScale and DataScale must match initialized values.
    // Input   : 48-bit UpdateFC DLLP
    // Returns : 1 if an FCPE violation is detected, 0 otherwise
    function bit check_FCPE (bit [DLLP_WIDTH-1:0] _dllp);

        bit [7:0]  hdr;
        bit [11:0] data;
        bit        fcpe_detected;
        fc_type_t  fc;

        // Decode FC type (P / NP / CPL).
        fc = decode_fc_type(get_dllp_type(_dllp));

        // Extract UpdateFC credit values.
        hdr           = _dllp[37:30];
        data          = _dllp[27:16];
        fcpe_detected = 0;

        // If both credits were advertised as zero during init, updates must stay zero.
        if (hdr_infinite[fc] && data_infinite[fc]) begin
            if (hdr != 0 || data != 0) begin
                `uvm_error("DLL_RM", "FCPE: UpdateFC must contain zero credits after infinite advertisement")
                fcpe_detected = 1;
            end
        end

        // If header was advertised as zero during init, it must stay zero.
        if (hdr_infinite[fc] && hdr != 0) begin
            `uvm_error("DLL_RM", "FCPE: Header must remain zero")
            fcpe_detected = 1;
        end

        // If data was advertised as zero during init, it must stay zero.
        if (data_infinite[fc] && data != 0) begin
            `uvm_error("DLL_RM", "FCPE: Data must remain zero")
            fcpe_detected = 1;
        end

        // When scaled FC is active, the scale fields must match the initialized values.
        if (scaled_fc_active) begin
            if (remote_fc.hdr_scale[fc] != _dllp[39:38] || remote_fc.data_scale[fc] != _dllp[29:28]) begin
                `uvm_error("DLL_RM", "FCPE: Scale mismatch in UpdateFC")
                fcpe_detected = 1;
            end
        end

        return fcpe_detected;

    endfunction : check_FCPE

    // Function update_sm_on_rx : Updates the Data Link Layer state machine based on received DLLP,
    //                            link status, reset, and initialization flags.
    // Inputs   : received DLLP type and DLLP , current DL state,
    //            physical link status, reset signal, pl_valid,
    //            FI1 / FI2 FC-init flags, surprise-down reporting capability
    //            link-not-disabled flag
    // Outputs  : next_state, state_changed flag , surprise_down_event flag
    function void update_sm_on_rx (
        dllp_type_t          _dllp_type,
        bit [DLLP_WIDTH-1:0] _dllp,
        dl_state_t           _current_state,
        bit                  pl_lnk_up,
        bit                  dl_reset,
        bit                  _pl_valid,
        // FC-init flags
        bit                  FI1,
        bit                  FI2,
        // read from cfg 
        bit                  surprise_down_Error_Reporting_capable,
        bit                  link_not_disabled,
        // outputs
        output dl_state_t           next_state,
        output bit                  state_changed,
        output bit                  surprise_down_event
    );

        // Defaults
        state_changed       = 1'b0;
        surprise_down_event = 1'b0;
        next_state          = _current_state;

        // RESET handling (highest priority)
        if (dl_reset) begin
            `uvm_info("DLL_RM",
                $sformatf("[update_sm_on_rx] reset=1, forcing DL_INACTIVE from %s",
                        _current_state.name()), UVM_MEDIUM)

            next_state    = DL_INACTIVE;
            state_changed = (_current_state != DL_INACTIVE);
            // If the Port supports the optional Data Link Feature Exchange ,
            // the Remote Data Link Feature Supported, and Remote Data Link Feature Supported Valid fields must be cleared
            if (state_changed &&
                cfg.local_register_feature.feature_exchange_enable &&
                cfg.feature_exchange_cap) begin
                remote_register_feature.remote_feature_supported = '0;
                remote_register_feature.remote_feature_valid     = 1'b0;
                `uvm_info("DLL_RM", "[update_sm_on_rx] reset: feature regs cleared", UVM_MEDIUM)
            end

            return;
        end

        // LINK DOWN handling
        // physical link down → force INACTIVE 
        if (!pl_lnk_up) begin
            `uvm_info("DLL_RM",
                $sformatf("[update_sm_on_rx] pl_lnk_up=0, forcing DL_INACTIVE from %s",
                        _current_state.name()), UVM_MEDIUM)

            if (_current_state != DL_INACTIVE) begin
                // Only report surprise-down for ACTIVE -> INACTIVE when supported.
                if (_current_state == DL_ACTIVE && surprise_down_Error_Reporting_capable)
                    surprise_down_event = 1'b1;

                next_state    = DL_INACTIVE;
                state_changed = 1'b1;

                if (cfg.local_register_feature.feature_exchange_enable &&
                    cfg.feature_exchange_cap) begin
                    remote_register_feature.remote_feature_supported = '0;
                    remote_register_feature.remote_feature_valid     = 1'b0;
                    `uvm_info("DLL_RM", "[update_sm_on_rx] link-down: feature regs cleared", UVM_MEDIUM)
                end
            end

            return; 
        end

        // State machine transitions.
        case (_current_state)
            DL_INACTIVE: begin
                `uvm_info("DLL_RM",
                    $sformatf("[update_sm_on_rx][DL_INACTIVE] link_not_disabled=%0b feature_cap=%0b feature_enable=%0b",
                            link_not_disabled,
                            cfg.feature_exchange_cap,
                            cfg.local_register_feature.feature_exchange_enable), UVM_MEDIUM)

                if (link_not_disabled) begin
                    // Exit to DL_Feature if: port supports feature exchange,
                    // feature exchange enable bit is Set, link not disabled,
                    // and PhysicalLinkUp=1 (already confirmed above)
                    if (cfg.feature_exchange_cap &&
                        cfg.local_register_feature.feature_exchange_enable) begin
                        `uvm_info("DLL_RM", "[update_sm_on_rx][DL_INACTIVE] → DL_FEATURE", UVM_MEDIUM)
                        next_state = DL_FEATURE;
                        remote_register_feature.remote_feature_supported = '0;
                        remote_register_feature.remote_feature_valid     = 1'b0;
                    end else begin
                        // Otherwise transition directly to DL_INIT1.
                        `uvm_info("DLL_RM", "[update_sm_on_rx][DL_INACTIVE] → DL_INIT1", UVM_MEDIUM)
                        next_state = DL_INIT1;
                    end
                    state_changed = 1'b1;
                end else begin
                       `uvm_info("DLL_RM", "[update_sm_on_rx][DL_INACTIVE] Staying in DL_INACTIVE because link_not_disabled=0", UVM_MEDIUM)
                        next_state    = _current_state;
                        state_changed = 1'b0;
                end
            end
            DL_FEATURE: begin
                // → DL_Init if : feature exchange completes successfully
                //               OR remote does not support feature exchange
                //               AND PhysicalLinkUp still 1
                // → DL_Inactive if : PhysicalLinkUp=0 (handled above already)
            
                // Feature exchange completes when:
                // (1) any INITFC1 (P / NP / CPL) is received, OR
                if (_dllp_type == INITFC1_P && _pl_valid) begin
                    next_state    = DL_INIT1;
                    state_changed = 1'b1;
                // (2) a FEATURE DLLP with Feature_Ack bit [39] = 1 is received
                end else if (_dllp_type == FEATURE && _dllp[39] && _pl_valid) begin // bit[39] = Feature_Ack
                    next_state    = DL_INIT1;
                    state_changed = 1'b1;
                end else begin
                    next_state    = DL_FEATURE;
                    state_changed = 1'b0;
                end
            end

            DL_INIT1: begin
                // → DL_DL_INIT2 if : FI1 set,PhysicalLinkUp still 1
                // → DL_Inactive if : PhysicalLinkUp=0 (handled above)
                if (FI1 && _pl_valid) begin
                    next_state    = DL_INIT2;
                    state_changed = 1'b1;
                end else begin
                    next_state    = _current_state;
                    state_changed = 1'b0;
                end
            end

            DL_INIT2: begin
                // → DL_Active if : FC initialization completes (FI2 set),
                //                  PhysicalLinkUp still 1
                // → DL_Inactive if : PhysicalLinkUp=0 (handled above)
                if (FI2 && _pl_valid) begin
                    next_state    = DL_ACTIVE;
                    state_changed = 1'b1;
                end else begin
                    next_state    = _current_state;
                    state_changed = 1'b0;
                end
            end

            DL_ACTIVE: begin
                    next_state    = _current_state;
                    state_changed = 1'b0;
                    
            end

        endcase

    endfunction : update_sm_on_rx
   
    // Function get_dl_status : determines the DL Up/Down status based on the current DL state.
    // Input    : current DL state
    // Outputs  : DL_Down status -> asserted in (INACTIVE, FEATURE, INIT1) states 
    //            DL_Up status   -> asserted in (INIT2, ACTIVE) states 
    function void get_dl_status (
        input  dl_state_t _state,
        output bit        _DL_Down,
        output bit        _DL_Up
    );

        // Default both outputs low.
        _DL_Down = 1'b0;
        _DL_Up   = 1'b0;

        case (_state)
            DL_INACTIVE,
            DL_FEATURE,
            DL_INIT1  : _DL_Down = 1'b1;

            DL_INIT2,
            DL_ACTIVE : _DL_Up   = 1'b1;

            default   : _DL_Down = 1'b1; // Safe fallback
        endcase

    endfunction : get_dl_status

    // Function crc_calc : Computes the 16-bit CRC over a 32-bit DLLP payload
    // Inputs   : 32-bit DLLP payload (without CRC field)
    // Returns  : 16-bit CRC
    function bit [CRC_WIDTH-1:0] crc_calc (bit [PAYLOAD_WIDTH-1:0] _dllp_without_crc);
        bit [BYTE-1:0]      data [PAYLOAD_IN_BYTES]; // Payload bytes
        bit [CRC_WIDTH-1:0] crc;                     // Running LFSR state
        bit [CRC_WIDTH-1:0] mapped_crc;              // Bit-reversed result
        bit                 feedback;                // XOR of MSB and current data bit

        // Split the payload into bytes.
        foreach (data[i])
            data[i] = _dllp_without_crc[(BYTE * i) +: BYTE];
        // load LFSR with initial seed 
        crc = initial_seed; // 0xFFFF
        // LFSR processing 
        // outer loop : bytes high-to-low  (byte[3] first, byte[0] last)
        // inner loop : bits LSB-to-MSB within each byte  ( bit 0 first, bit 7 last)
        // feedback drives the polynomial XOR only.
        for (int i = PAYLOAD_IN_BYTES - 1; i >= 0; i--) begin
            for (int j = 0; j < BYTE; j++) begin
                feedback = data[i][j] ^ crc[CRC_WIDTH-1]; // MSB of LFSR ⊕ current data bit
                crc      = crc << 1;                       // shift LFSR left
                if (feedback)
                    crc = crc ^ generator_polynomial;      // 0x100B
            end
        end
        // complement the result of the calculation
        crc = ~crc;

        // bit-reverse each byte independently 
        mapped_crc[7:0]  = {<<{crc[7:0]}};  // reverse bits [7:0]
        mapped_crc[15:8] = {<<{crc[15:8]}}; // reverse bits [15:8]

        return mapped_crc;

    endfunction : crc_calc

    // Function get_dllp_type : Decodes the DLLP type from a received 48-bit DLLP.
    //                          Masks the VC bits [2:0] for all FC-related DLLP types.
    // Input   : 48-bit received DLLP
    // Returns : decoded DLLP type
    function dllp_type_t get_dllp_type (logic [DLLP_WIDTH-1:0] _rx_item);
        
        logic [BYTE-1:0] type_byte;

        type_byte = _rx_item[DLLP_WIDTH-1:40];

        // Mask VC bits [2:0] for all FC types
        if (type_byte[BYTE-1:4] inside {4'b0100, 4'b0101, 4'b0110,
                                        4'b1100, 4'b1101, 4'b1110,
                                        4'b1000, 4'b1001, 4'b1010})
            type_byte[2:0] = 3'b000;

        return dllp_type_t'(type_byte);

    endfunction : get_dllp_type

    // Function decode_fc_type : Decodes a DLLP type into its FC category (Posted, Non-Posted, Completion).
    // Input   : type of received DLLP
    // Returns : fc_type_t (FC_POSTED / FC_NON_POSTED / FC_COMPLETION)
    function fc_type_t decode_fc_type (dllp_type_t _dllp_type);

        case (_dllp_type)
            INITFC1_P,   INITFC2_P,   UPDATEFC_P   : return FC_POSTED;
            INITFC1_NP,  INITFC2_NP,  UPDATEFC_NP  : return FC_NON_POSTED;
            INITFC1_CPL, INITFC2_CPL, UPDATEFC_CPL : return FC_COMPLETION;
            default: begin
                `uvm_error("DLL_RM", "decode_fc_type: Invalid FC DLLP type")
                return FC_POSTED; // safe fallback
            end
        endcase

    endfunction : decode_fc_type

endclass 

`endif 
