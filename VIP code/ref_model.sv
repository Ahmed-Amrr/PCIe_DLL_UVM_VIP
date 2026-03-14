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
    bit          scaled_fc_active;
    fc_credits_t local_fc ;           // credits advertised by this VIP
    fc_credits_t remote_fc;           // credits received from peer
    dl_feature_cap_reg_t feature_cap_reg;
    dl_feature_status_reg_t  feature_status_reg;

    function new();
        this.generator_polynomial = 'h100B;
        this.initial_seed         = 'hFFFF;  
        this.current_state        = DL_INACTIVE;
        this.local_fc             = '0;
        this.remote_fc            = '0;
        this.FI1                  = 0;
        this.FI2                  = 0;
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
            -is_legal = 0;
            `uvm_error("DLL_RM", "[check_rx_legality] Illegal DLLP receving in state DL_INACTIVE")
        end
    endfunction : check_rx_legality

    function void process_rx_dllp;
        input dllp_type_t          _dllp_type;
        input bit [DLLP_WIDTH-1:0] _dllp     ;

        case (_dllp_type)
            INITFC1_P, INITFC1_NP, INITFC1_CPL, INITFC2_P, INITFC2_NP, INITFC2_CPL: begin
                if (this.current_state == DL_INIT1) begin
                    record_fc_values(_dllp);
                    update_fi_flags(_dllp);
                end else if (this.current_state == DL_INIT2) begin
                    update_fi_flags(_dllp);
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

endclass : dll_ref_model

`endif // REF_MODEL_SV