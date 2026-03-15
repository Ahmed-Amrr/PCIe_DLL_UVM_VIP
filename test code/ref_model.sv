`ifndef REF_MODEL_SV
`define REF_MODEL_SV

class dll_ref_model #(
    parameter int DLLP_WIDTH       = 48,
    parameter int PAYLOAD_WIDTH    = 32,  
    parameter int CRC_WIDTH        = 16,
    parameter int BYTE             = 8 ,
    parameter int PAYLOAD_IN_BYTES = PAYLOAD_WIDTH / BYTE
);

    bit [CRC_WIDTH-1:0] generator_polynomial;
    bit [CRC_WIDTH-1:0] initial_seed        ;

    dl_state_t   current_state;        // DL state machine
    bit          FI1, FI2;
    bit          fi1_p, fi1_np, fi1_cpl;   // per-type trackers for FI1
    bit          scaled_fc_active;
    fc_credits_t local_fc ;           // credits advertised by this VIP
    fc_credits_t remote_fc;           // credits received from peer
    dl_feature_cap_reg_t feature_cap_reg;
    dl_feature_status_reg_t  feature_status_reg;

    bit [1:0] local_hdr_scale;    // scaling factor for header credits
    bit [1:0] local_data_scale;   // scaling factor for data credits
    int       initfc1_tx_count;   // tracks P/NP/Cpl TX order in INIT1
    int       initfc2_tx_count;   // tracks P/NP/Cpl TX order in INIT2

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
    endfunction : new
    
    // Function : verify_rx_crc
    // Inputs   : the received DLLP
    // Outputs  : bit indicating that DLLP is corrupted
    // Calculate the CRC-16 over the received DLLP and compare it against the CRC field carried in rx_item.
    // Sets should_discard = 1 when a mismatch is detected.
    function void verify_rx_crc;
        input  bit [DLLP_WIDTH-1:0] _rx_item       ;
        output bit                  _should_discard;

        bit [CRC_WIDTH-1:0] rx_crc  ;
        bit [CRC_WIDTH-1:0] calc_crc; 

        rx_crc = _rx_item[(4*BYTE) +: (2*BYTE)];
        crc_calc(._dllp_without_crc(_rx_item[0 +: PAYLOAD_WIDTH]), ._crc(calc_crc));

        if (rx_crc !== calc_crc) begin
            _should_discard = 1;
            `uvm_info("DLL_RM", $sformatf("[verify_rx_crc] CRC mismatch. Calculated=0x%04h  Received=0x%04h", calc_crc, rx_crc), UVM_HIGH)
        end else begin
            _should_discard = 0;
            `uvm_info("DLL_RM", "[verify_rx_crc] CRC OK", UVM_HIGH)
        end
    endfunction : verify_rx_crc

    // Function: check_rx_legality
    // Inputs  : the dllp type and the current state of the VIP
    // Outputs : bit indicating if this dllp is legal to be received or not
    // Verify that receiving dllp_type is legal in current_state.
    // Sets is_legal = 0 and reports an error when the combination is not permitted by the PCIe Gen-5 specification.
    function void check_rx_legality;
        input  dllp_type_t _dllp_type    ;
        input  state_t     _current_state;
        output bit         _is_legal     ;

        _is_legal = 1;
        if (_current_state == DL_INACTIVE) begin
            _is_legal = 0;
            `uvm_error("DLL_RM", "[check_rx_legality] Illegal DLLP receving in state DL_INACTIVE")
        end
        // need to add legality for tx too
    endfunction : check_rx_legality

    function void process_rx_dllp;
        input dllp_type_t          _dllp_type;
        input bit [DLLP_WIDTH-1:0] _dllp     ;

        case (_dllp_type)
            INITFC1_P, INITFC1_NP, INITFC1_CPL: begin
                if (this.current_state == DL_INIT1) begin
                    record_fc_values(_dllp);
                    update_fi_flags(_dllp_type);
                end
            end
            INITFC2_P, INITFC2_NP, INITFC2_CPL: begin
                // Process received InitFC1 and InitFC2 DLLPs:
                //    ▪ Record the indicated HdrFC and DataFC values
                if (this.current_state == DL_INIT1) begin
                    record_fc_values(_dllp);
                    update_fi_flags(_dllp_type);
                end else if (this.current_state == DL_INIT2) begin
                    // update_fi_flags(_dllp_type);
                    // not sure if we should update the flag FI2 once we receiVe any of INITFC2 in DL_INIT2 or not
                    this.FI2 = 1;
                end
            end
            DL_FEATURE : begin 
                if (this.current_state == DL_FEATURE ) begin
                    if (feature_status_reg.remote_feature_valid == 1'b0) begin
                    record_Feature_Supported_field(_dllp);
                    feature_status_reg.remote_feature_valid = 1'b1;
                    end else activate_dl_feature;
                end
            end
           UPDATEFC_P, UPDATEFC_NP, UPDATEFC_CPL : begin 
            if (this.current_state == DL_INIT2) begin
                this.FI2 = 1;
            end
            if (this.current_state == DL_ACTIVE)
                record_fc_values(_dllp);
           end
        default: 
       endcase
        
    endfunction

    function void record_Feature_Supported_field;
        input bit [DLLP_WIDTH-1:0] _dllp;
        feature_status_reg.remote_feature_supported = _dllp[31:9]; //not sure
    endfunction

    // Activate Data Link feature negotiated through the DL_FEATURE DLLP
    // Enable Scaled Flow Control (bit 0) only if it is supported by both the local port and the remote port
    function void activate_dl_feature;
        scaled_fc_active = feature_status_reg.remote_feature_supported[0] & feature_cap_reg.local_feature_supported[0];
    endfunction

    function void record_fc_values;
        input bit [DLLP_WIDTH-1:0] _dllp;

        remote_fc.hdr_credits  = _dllp[];
        remote_fc.data_credits = _dllp[];

        `uvm_info("DLL_RM",$sformatf("[record_fc_values] HDR_FC=%0d  DATA_FC=%0d", remote_fc.hdr, remote_fc.data), UVM_MEDIUM)
    endfunction : record_fc_values
 
    function void update_fi_flags;
        input dllp_type_t _dllp_type;

        case (_dllp_type)
            INITFC1_P, INITFC2_P: begin
                // Posted credits must come first so non-posted and compeletion mustm't be set yet
                if (fi1_np || fi1_cpl) begin
                    `uvm_error("DLL_RM", "[update_fi_flags] ORDER VIOLATION — P received after NP or CPL")
                end else begin
                    fi1_p = 1;
                    `uvm_info("DLL_RM", "[update_fi_flags] P credits recorded", UVM_HIGH)
                end
            end

            INITFC1_NP, INITFC2_NP: begin
                // NP must come after P
                if (!fi1_p) begin
                    `uvm_error("DLL_RM", "[update_fi_flags] ORDER VIOLATION — NP received before P")
                end else if (fi1_cpl) begin
                    `uvm_error("DLL_RM", "[update_fi_flags] ORDER VIOLATION — NP received after CPL")
                end else begin
                    fi1_np = 1;
                    `uvm_info("DLL_RM", "[update_fi_flags] NP credits recorded", UVM_HIGH)
                end
            end

            INITFC1_CPL, INITFC2_CPL: begin
                // CPL must come after P and NP 
                if (!fi1_p || !fi1_np) begin
                    `uvm_error("DLL_RM", "[update_fi_flags] ORDER VIOLATION — CPL received before P or NP")
                end else begin
                    fi1_cpl = 1;
                    `uvm_info("DLL_RM", "[update_fi_flags] CPL credits recorded", UVM_HIGH)
                end
            end
        endcase

        // FI1 set only when all three received IN ORDER
        if (fi1_p && fi1_np && fi1_cpl) begin
            this.FI1 = 1;
            `uvm_info("DLL_RM", "[update_fi_flags] FI1 SET — P/NP/CPL all received in order", UVM_MEDIUM)
        end

    endfunction : update_fi_flags

    function void crc_calc;
        input  bit [PAYLOAD_WIDTH-1:0] _dllp_without_crc;
        output bit [CRC_WIDTH-1:0]     _crc             ;

        bit [BYTE-1:0] data [PAYLOAD_IN_BYTES];
        bit [CRC_WIDTH-1:0] crc;
        bit [CRC_WIDTH-1:0] mapped_crc;
        bit feedback;
        
        // split the payload into bytes as CRC calculation starts with bit 0 of byte 0 and proceeds from bit 0 to bit 7 of each byte
        foreach (data[i]) begin
            data[i] = _dllp_without_crc[(BYTE*i) +: BYTE];
        end
        // load the LFSR with the initial seed
        crc = initial_seed;

        // process the btes to generate the crc
        for (int i = 0; i < PAYLOAD_IN_BYTES; i++) begin            
            for (int j = 0; j < BYTE; j++) begin
                feedback = data[i][j] ^ crc[CRC_WIDTH-1];
                crc = crc << 1;
                crc[0] = feedback;
                if (feedback) 
                    crc = crc ^ generator_polynomial;
            end
        end
        // complemet the crc "The result of the calculation is complemented"
        crc = ~crc;
        // map the bits as specs say
        mapped_crc[7:0]   = {<<{crc[7:0]}};
        mapped_crc[15:8]  = {<<{crc[15:8]}};
        _crc = mapped_crc;
    endfunction : crc_calc

    //Main Function
function  void update_sm_on_rx;
    input dllp_type_t            _dllp_type;
    input bit [DLLP_WIDTH-1:0]   _dllp     ;
    input bit                    pl_lnk_up ;
    input bit                    dl_reset;
    //Flags
    input  bit                   FI1, FI2  ;
    input  bit                   surprise_down_Error_Reporting_capable; 
    input  bit                   link_not_disabled; 

    //OUTPUT
    output dl_state_t            next_state;
    output bit                   state_changed;
    output bit                   surprise_down_event;

    // default
        next_state    = current_state;
        state_changed = 1'b0;
        surprise_down_event  = 1'b0;
    
    // Reset handling (hot/warm/cold reset)

    if (dl_reset) begin
        next_state = DL_INACTIVE;

        if (current_state != DL_INACTIVE) begin
            state_changed = 1'b1;

            if (feature_cap_reg.feature_exchange_enable) begin
                    feature_status_reg.remote_feature_supported = '0;
                    feature_status_reg.remote_feature_valid     = 1'b0;
                    `uvm_info("DLL_RM", "[update_sm_on_rx] reset: feature regs cleared", UVM_MEDIUM) 
            end

        end
        else
            state_changed = 1'b0;


        return;
    end

        // every state has "exit to DL_Inactive if PhysicalLinkUp=0"
    if (!pl_lnk_up) begin
        if (current_state != DL_INACTIVE) begin

            // detect DL_ACTIVE → DL_INACTIVE transition
            if (current_state == DL_ACTIVE && surprise_down_Error_Reporting_capable) begin
                surprise_down_event = 1'b1;
            end

            next_state    = DL_INACTIVE;
            state_changed = 1'b1;
            if (feature_cap_reg.feature_exchange_enable) begin
                    feature_status_reg.remote_feature_supported = '0;
                    feature_status_reg.remote_feature_valid     = 1'b0;
                    `uvm_info("DLL_RM", "[update_sm_on_rx] reset: feature regs cleared", UVM_MEDIUM) 
            end

        end
        return; // no further processing
    end

    case (current_state)

        
            DL_INACTIVE: begin
                // Exit to DL_Feature if: port supports feature exchange,
                //   feature exchange enable bit is Set, link not disabled,
                //   and PhysicalLinkUp=1 (already confirmed above)
                // Exit to DL_Init if: port does NOT support feature exchange
                //   OR feature exchange enable bit is Clear,
                //   link not disabled, PhysicalLinkUp=1

                if (link_not_disabled) begin

                    if (feature_cap_reg.local_feature_supported[0] && feature_cap_reg.feature_exchange_enable) begin
                        next_state = DL_FEATURE;
                       // clear on entry to DL_FEATURE
                        feature_status_reg.remote_feature_supported = '0;
                        feature_status_reg.remote_feature_valid     = 1'b0;
                    end 
                    else begin
                        next_state = DL_INIT1;
                    end

                    state_changed = 1'b1;

                end 
                else begin
                    next_state    = current_state;
                    state_changed = 1'b0;
                end
            end

            DL_FEATURE: begin
                // → DL_Init if: feature exchange completes successfully
                //              OR remote does not support feature exchange
                //              AND PhysicalLinkUp still 1
                // → DL_Inactive if: PhysicalLinkUp=0 (handled above already)
                //
                // Feature exchange completes  when:
                //   - received InitFC1 DLLP 
                //   - OR at least one DL_Feature DLLP received with Feature_Ack=1

                if (_dllp_type == INITFC1_P ||_dllp_type == INITFC1_NP ||_dllp_type == INITFC1_CPL) begin
                    next_state    = DL_INIT1;
                    state_changed = 1'b1;
                end else if (_dllp_type == DL_FEATURE && _dllp[15]) begin
                    // feature ack seen → exchange complete
                    next_state    = DL_INIT1;
                    state_changed = 1'b1;
                end else if (!feature_status_reg.remote_feature_supported[0]) begin         
                    next_state    = DL_INIT1;
                    state_changed = 1'b1;
                end  else begin
                    next_state    = DL_FEATURE;
                    state_changed = 1'b0;
                end
                
            end

            DL_INIT1: begin
                // → DL_DL_INIT2 if: FI1 set,
                //                 PhysicalLinkUp still 1
                // → DL_Inactive if: PhysicalLinkUp=0 (handled above)
                if (FI1) begin
                    next_state    = DL_INIT2;
                    state_changed = 1'b1;
                end else begin
                    next_state    = current_state;
                    state_changed = 1'b0;
                end
            end

            DL_INIT2: begin
                // → DL_Active if: FC initialization completes (FI2 set),
                //                 PhysicalLinkUp still 1
                // → DL_Inactive if: PhysicalLinkUp=0 (handled above)
                if (FI2) begin
                    next_state    = DL_ACTIVE;
                    state_changed = 1'b1;
                end else begin
                    next_state    = current_state;
                    state_changed = 1'b0;
                end
            end

            DL_ACTIVE: begin
                    next_state    = current_state;
                    state_changed = 1'b0;
            end
    endcase

endfunction

// after update_sm_on_rx returns next_state
function void get_dl_status;
    input  dl_state_t _state;
    output bit        DL_Down;
    output bit        DL_Up;

    //defaults 
    DL_Down = 1'b0;
    DL_Up   = 1'b0;

    case (_state)
        DL_INACTIVE,
        DL_FEATURE,
        DL_INIT1  : DL_Down = 1'b1;  // spec: DL_Down reported

        DL_INIT2,
        DL_ACTIVE : DL_Up   = 1'b1;  // spec: DL_Up reported

        default   : DL_Down = 1'b1;  // unknown state → safe default = DL_Down
    endcase

endfunction : get_dl_status


function void predict_expected_tx_response;

    input  dl_state_t current_state;
    output dllp_type_t expected_type;
    output bit [DLLP_WIDTH-1:0] expected_dllp;

    expected_dllp = '0;
    expected_type = NOP;

    case (current_state)

        
        // DL_FEATURE : transmit DL_FEATURE DLLP
        
        DL_FEATURE: begin

            expected_type = DL_FEATURE;

            // Feature Supported field //LE ////////////////----------->>>>>>>>fixxxxxxx mapppping
           { expected_dllp[14:8],expected_dllp[31:16]} = feature_cap_reg.local_feature_supported;

            // Feature Ack bit
            expected_dllp[15] = feature_status_reg.remote_feature_valid;

            `uvm_info("DLL_RM",
            $sformatf("[predict_expected_tx_response] TX DL_FEATURE: supported=0x%0h ack=%0b",
                feature_cap_reg.local_feature_supported,
                feature_status_reg.remote_feature_valid),
            UVM_MEDIUM)

        end
    
        
        // DL_INIT1 : send InitFC1 sequence
   
        DL_INIT1: begin

            case (initfc1_tx_count)

                0: begin
                    expected_type = INITFC1_P;
                    expected_dllp = build_initfc_pkt(FC_POSTED, 0);
                    initfc1_tx_count++;
                end

                1: begin
                    expected_type = INITFC1_NP;
                    expected_dllp = build_initfc_pkt(FC_NON_POSTED, 0);
                    initfc1_tx_count++;
                end

                2: begin
                    expected_type = INITFC1_CPL;
                    expected_dllp = build_initfc_pkt(FC_COMPLETION, 0);
                    initfc1_tx_count++;
                end

                default: begin
                    // spec: repeat P→NP→Cpl frequently until FI1 is set
                    // reset counter → next call starts from P again
                    initfc1_tx_count = 0;
                    expected_type    = INITFC1_P;
                    expected_dllp    = build_initfc_pkt(FC_POSTED, 0);
                    initfc1_tx_count++;
               end

            endcase

        end

        // DL_INIT2 : send InitFC2 sequence
       
        DL_INIT2: begin

            case (initfc2_tx_count)

                0: begin
                    expected_type = INITFC2_P;
                    expected_dllp = build_initfc_pkt(FC_POSTED, 1);
                    initfc2_tx_count++;  //---->>>>>> put its initialization in the new function
                end

                1: begin
                    expected_type = INITFC2_NP;
                    expected_dllp = build_initfc_pkt(FC_NON_POSTED, 1);
                    initfc2_tx_count++;
                end

                2: begin
                    expected_type = INITFC2_CPL;
                    expected_dllp = build_initfc_pkt(FC_COMPLETION, 1);
                    initfc2_tx_count++;
                end

                default: begin
                    // same — repeat P→NP→Cpl until FI2 is set
                    initfc2_tx_count = 0;
                    expected_type    = INITFC2_P;
                    expected_dllp    = build_initfc_pkt(FC_POSTED, 1);
                    initfc2_tx_count++;
                end

            endcase

        end

         default: begin
            expected_type = NOP;
            expected_dllp = '0;
        end

    endcase
endfunction : predict_expected_tx_response

function bit [DLLP_WIDTH-1:0] build_initfc_pkt
(
    input fc_type_t  fc_type,
    input bit        is_init2   // 0 = InitFC1 , 1 = InitFC2
 
);
    
    bit [DLLP_WIDTH-1:0] pkt;
    pkt = '0;

  
    // DLLP TYPE
 
    if (!is_init2) begin
        // InitFC1
        case (fc_type)
            FC_POSTED     : pkt[7:0] = 8'b0100_0000; // INITFC1_P
            FC_NON_POSTED : pkt[7:0] = 8'b0101_0000; // INITFC1_NP
            FC_COMPLETION : pkt[7:0] = 8'b0110_0000; // INITFC1_CPL
            default       : _pkt[7:0] = 8'b0000_0000;
        endcase
    end
    else begin
        // InitFC2
        case (fc_type)
            FC_POSTED     : pkt[7:0] = 8'b1100_0000; // INITFC2_P
            FC_NON_POSTED : pkt[7:0] = 8'b1101_0000; // INITFC2_NP
            FC_COMPLETION : pkt[7:0] = 8'b1110_0000; // INITFC2_CPL
            default       : pkt[7:0] = 8'b0000_0000;
        endcase
    end

//---------------->>>>fix mapping
// SCALE FIELDS

// in class member variable
//_hdr_scale;    // configured at start of sim
//_data_scale;   // configured at start of sim

//function new();
    
    //this._hdr_scale  = 2'b01; // default x1 scaling
    //this._data_scale = 2'b01;
//endfunction

   
    if (scaled_fc_active) begin
        pkt[9:8] = local_hdr_scale; // HdrScale [1:0]
        pkt[19:18] = local_data_scale; // DataScale[1:0]
    end
    else begin
        pkt[9:8]   = 2'b00;
        pkt[19:18] = 2'b00;
    end


    
    // CREDITS
    
    pkt[17:10] = local_fc.hdr_credits[fc_type];
    pkt[31:20] = local_fc.data_credits[fc_type];

    return pkt;

endfunction


function void check_response_correctness;
    input dllp_type_t           _actual_tx_type ;
    input bit [DLLP_WIDTH-1:0]  _actual_tx_dllp ;
    input bit                   _response_required;

    dllp_type_t          exp_type;
    bit [DLLP_WIDTH-1:0] exp_dllp;

    // only check if response is required
    if (!_response_required) return;

  
    // get prediction from model based on current state
    
    predict_expected_tx_response(
        .current_state (current_state),
        .expected_type (exp_type),
        .expected_dllp (exp_dllp)
    );

    
    
    // do not check these — do not advance counter
   
    if (_actual_tx_type inside {ACK, NAK, NOP}) begin
        `uvm_info("DLL_RM", $sformatf(
            "[check_response] state=%s skipping %s — not an FC DLLP",
            current_state.name(), _actual_tx_type.name()), UVM_HIGH)
        return;
    end

    
    // CHECK 1: DLLP type correct?
    // predicted_tx_response (from rx model) == actual_tx_response (from TX monitor)
   
    if (_actual_tx_type !== exp_type) begin
        `uvm_error("DLL_RM", $sformatf(
            "[check_response] TYPE MISMATCH: state=%s expected=%s actual=%s",
            current_state.name(),
            exp_type.name(),
            _actual_tx_type.name()))
    end else begin
        `uvm_info("DLL_RM", $sformatf(
            "[check_response] TYPE OK: state=%s type=%s",
            current_state.name(),
            _actual_tx_type.name()), UVM_MEDIUM)
    end

    
    // CHECK 2: DLLP content correct?
    // field by field based on current state
    
    case (current_state)

        DL_FEATURE: begin
            if (_actual_tx_dllp[31:0] !== exp_dllp[31:0]) begin
                `uvm_error("DLL_RM", $sformatf(
                    "[check_response] DL_FEATURE MISMATCH: expected=0x%08h actual=0x%08h",
                    exp_dllp[31:0], _actual_tx_dllp[31:0]))
            end else
                `uvm_info("DLL_RM", $sformatf(
                    "[check_response] DL_FEATURE OK: 0x%08h",
                    _actual_tx_dllp[31:0]), UVM_MEDIUM)
        end

        DL_INIT1, DL_INIT2: begin
            if (_actual_tx_dllp[31:0] !== exp_dllp[31:0]) begin
                `uvm_error("DLL_RM", $sformatf(
                    "[check_response] %s MISMATCH: expected=0x%08h actual=0x%08h",
                    current_state.name(),
                    exp_dllp[31:0], _actual_tx_dllp[31:0]))
            end else
                `uvm_info("DLL_RM", $sformatf(
                    "[check_response] %s OK: 0x%08h",
                    current_state.name(), _actual_tx_dllp[31:0]), UVM_MEDIUM)
        end

       

        default: begin
            `uvm_info("DLL_RM", $sformatf(
                "[check_response] state=%s no check defined",
                current_state.name()), UVM_MEDIUM)
        end

    endcase

endfunction : check_response_correctness

endclass : dll_ref_model

`endif // REF_MODEL_SV