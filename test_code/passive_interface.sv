`ifndef PASSIVE_IF_SV
`define PASSIVE_IF_SV
interface passive_interface (input logic lclk);

    import dll_pkg::*;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // DLLP buses 
    bit [47:0] tx_dllp;   // DLLP being transmitted by local side
    bit [47:0] rx_dllp;   // DLLP received from remote side

    //  Feature Exchange Registers
    // Local: what this device supports and whether exchange is enabled
    dl_feature_cap_reg_t    local_register_feature;
    // Remote: what the far end advertised and whether it's valid yet
    dl_feature_status_reg_t remote_register_feature;

    //  Flow Control Credit Registers 
    // local_fc_credits_register  : credits/scale this device advertised
    fc_credits_t local_fc_credits_register;
    // remote_fc_credits_register : credits/scale received from far end
    fc_credits_t remote_fc_credits_register;

    // Whether feature exchange capability is enabled
    bit feature_exchange_cap;

    // Current DL state machine state
    dl_state_t state;

    //  Physical / Link signals 
    logic pl_lnk_up;   // Physical layer link-up indicator
    logic reset;        // Active-high reset
    logic pl_valid;     // PL data is valid
    logic lp_valid;     // LP data is valid
    logic lp_data;      // LP data bus
    logic pl_data;      // PL data bus

    //  Link Status outputs 
    logic DL_Up;        // DL layer reports link is UP
    logic DL_Down;      // DL layer reports link is DOWN

    // Scaled Flow Control feature is negotiated and active
    logic scaled_fc_active;

    //  FC Init completion flags 
    logic fi1_flag;   // Set when all 3 InitFC1 triplets received
    logic fi2_flag;   // Set when all 3 InitFC2 triplets received

    //  TX DLLP type decode signals 
    logic tx_is_initfc1_p;
    logic tx_is_initfc1_np;
    logic tx_is_initfc1_cpl;
    logic tx_is_initfc2_p;
    logic tx_is_initfc2_np;
    logic tx_is_initfc2_cpl;

    // Scale fields extracted from TX DLLP
    logic [1:0] tx_hdr_scale;
    logic [1:0] tx_data_scale;

    // Scale fields extracted from RX DLLP
    logic [1:0] rx_hdr_scale;
    logic [1:0] rx_data_scale;

    // Grouped TX/RX DLLP type flags
    logic tx_is_initfc1;
    logic tx_is_initfc2;
    logic rx_is_initfc1;
    logic rx_is_initfc2;

    // RX DLLP type decode signals
    logic rx_is_initfc2_p;
    logic rx_is_initfc2_np;
    logic rx_is_initfc2_cpl;
    logic rx_is_initfc1_p;
    logic rx_is_initfc1_np;
    logic rx_is_initfc1_cpl;

    // Feature DLLP decode signal
    logic        tx_is_feature;       // TX DLLP is a Feature DLLP
    logic        rx_is_feature;       // RX DLLP is a Feature DLLP
    logic [22:0] tx_feature_field;    // Feature supported bits from TX
    logic [22:0] rx_feature_field;    // Feature supported bits from RX
    logic        tx_ack_bit;          // ACK bit in TX Feature DLLP
    logic        rx_ack_bit;          // ACK bit in RX Feature DLLP

    //These flags used for getting DLLP with INITFC1 type in order
    bit init1_p_f;              //Posetd
    bit init1_np_f;             //Non-Posted
    bit init1_cpl_f;            //Compeletion       

    // ============================================================
    // Continuous assignments — decode DLLPs
    // ============================================================

    // Feature DLLP detection
    assign tx_is_feature    = (tx_dllp[47:40] == FEATURE);
    assign rx_is_feature    = (rx_dllp[47:40] == FEATURE);
    assign tx_feature_field = tx_dllp[38:16];   // local feature bits
    assign rx_feature_field = rx_dllp[38:16];   // remote feature bits
    assign tx_ack_bit       = tx_dllp[39];       // ACK bit position
    assign rx_ack_bit       = rx_dllp[39];

    // TX InitFC1 type detection
    assign tx_is_initfc1_p   = (tx_dllp[47:40] == INITFC1_P);
    assign tx_is_initfc1_np  = (tx_dllp[47:40] == INITFC1_NP);
    assign tx_is_initfc1_cpl = (tx_dllp[47:40] == INITFC1_CPL);

    // TX InitFC2 type detection
    assign tx_is_initfc2_p   = (tx_dllp[47:40] == INITFC2_P);
    assign tx_is_initfc2_np  = (tx_dllp[47:40] == INITFC2_NP);
    assign tx_is_initfc2_cpl = (tx_dllp[47:40] == INITFC2_CPL);

    // RX InitFC1 type detection
    assign rx_is_initfc1_p   = (rx_dllp[47:40] == INITFC1_P);
    assign rx_is_initfc1_np  = (rx_dllp[47:40] == INITFC1_NP);
    assign rx_is_initfc1_cpl = (rx_dllp[47:40] == INITFC1_CPL);

    // RX InitFC2 type detection
    assign rx_is_initfc2_p   = (rx_dllp[47:40] == INITFC2_P);
    assign rx_is_initfc2_np  = (rx_dllp[47:40] == INITFC2_NP);
    assign rx_is_initfc2_cpl = (rx_dllp[47:40] == INITFC2_CPL);

    // Scale fields — bits 39:38 = HdrScale, bits 29:28 = DataScale
    assign tx_hdr_scale  = tx_dllp[39:38];
    assign tx_data_scale = tx_dllp[29:28];
    assign rx_hdr_scale  = rx_dllp[39:38];
    assign rx_data_scale = rx_dllp[29:28];

    // Grouped any-type checks using 'inside'
    assign tx_is_initfc1 = (tx_dllp[47:40] inside {INITFC1_P, INITFC1_NP, INITFC1_CPL});
    assign tx_is_initfc2 = (tx_dllp[47:40] inside {INITFC2_P, INITFC2_NP, INITFC2_CPL});
    assign rx_is_initfc1 = (rx_dllp[47:40] inside {INITFC1_P, INITFC1_NP, INITFC1_CPL});
    assign rx_is_initfc2 = (rx_dllp[47:40] inside {INITFC2_P, INITFC2_NP, INITFC2_CPL});

    // ============================================================
    // RESET BEHAVIOR
    // ============================================================

    // After reset, remote feature register must be cleared within 2 cycles
    property p_reset_clears_remote_feature;
        @(posedge lclk)
        (reset == 1) |-> ##[1:2]
        remote_register_feature == '0;
    endproperty

    assert property (p_reset_clears_remote_feature)
        else `uvm_error("ASSERT_FAIL", "Remote feature signals not cleared after reset");

    cover property (p_reset_clears_remote_feature);

    // ============================================================
    // LINK STATUS vs STATE CHECKS
    // ============================================================

    // DL_Up must be asserted (and DL_Down de-asserted) in DL_ACTIVE or DL_INIT2
    property p_link_up_in_active_states;
        @(posedge lclk) disable iff (reset || $isunknown(DL_Up) || !pl_valid)
        (state == DL_ACTIVE || state == DL_INIT2) |->
        (DL_Up == 1'b1 && DL_Down == 1'b0);
    endproperty

    assert property (p_link_up_in_active_states)
        else `uvm_error("ASSERT_FAIL", "LINK_STATUS should be DL_UP in DL_ACTIVE or FC_INIT2");
    cover property (p_link_up_in_active_states);

    // DL_Down must be asserted (and DL_Up de-asserted) in DL_INACTIVE, DL_FEATURE, or DL_INIT1
    property p_link_down_in_inactive_states;
        @(posedge lclk) disable iff (reset || $isunknown(DL_Up) || !pl_valid)
        (state inside {DL_INACTIVE, DL_FEATURE, DL_INIT1}) |->
        (DL_Down == 1'b1 && DL_Up == 1'b0);
    endproperty

    assert property (p_link_down_in_inactive_states)
        else `uvm_error("ASSERT_FAIL", "LINK_STATUS should be DL_DOWN in DL_INACTIVE, DL_FEATURE, or FC_INIT1");
    cover property (p_link_down_in_inactive_states);

    // ============================================================
    // PHYSICAL LINK UP/DOWN vs STATE CONSISTENCY
    // ============================================================

    // If pl_lnk_up is low, state must be DL_INACTIVE
    property p_link_down_state_inactive;
        @(posedge lclk) disable iff (reset)
        (!pl_lnk_up) |=> (state == DL_INACTIVE);
    endproperty

    assert property (p_link_down_state_inactive)
        else `uvm_error("ASSERT_FAIL", "State must be DL_INACTIVE when pl_link_up is low");
    cover property (p_link_down_state_inactive);

    // If pl_lnk_up is high, state must advance to FEATURE/INIT1/INIT2/ACTIVE within 2 cycles
    property p_link_up_state_valid;
        @(posedge lclk) disable iff (reset || !pl_valid)
        (pl_lnk_up) |-> ##[1:2]
        state inside {DL_FEATURE, DL_INIT1, DL_INIT2, DL_ACTIVE};
    endproperty

    assert property (p_link_up_state_valid)
        else `uvm_error("ASSERT_FAIL", "State must be DL_FEATURE/DL_INIT1/DL_INIT2/DL_ACTIVE when pl_link_up is high");
    cover property (p_link_up_state_valid);

    // If pl_lnk_up drops while in any active state, next state must be DL_INACTIVE
    property p_link_drop_goes_inactive;
        @(posedge lclk)
        ($past(state) inside {DL_FEATURE, DL_INIT1, DL_INIT2, DL_ACTIVE} && !pl_lnk_up) |=>
        (state == DL_INACTIVE);
    endproperty

    assert property (p_link_drop_goes_inactive)
        else `uvm_error("ASSERT_FAIL", "State did not transition to DL_INACTIVE after pl_link_up drop");
    cover property (p_link_drop_goes_inactive);

    // ============================================================
    // VALID STATE TRANSITIONS
    // ============================================================

    // From DL_INACTIVE, next state can only be DL_FEATURE or DL_INIT1
    property p_inactive_next_state;
        @(posedge lclk)
        ($past(state) == DL_INACTIVE && state != DL_INACTIVE) |->
        (state inside {DL_FEATURE, DL_INIT1});
    endproperty

    assert property (p_inactive_next_state)
        else `uvm_error("ASSERT_FAIL", "Invalid state transition from DL_INACTIVE");
    cover property (p_inactive_next_state);

    // From DL_FEATURE, next state can only be DL_INIT1 or DL_INACTIVE
    property p_feature_next_state;
        @(posedge lclk)
        ($past(state) == DL_FEATURE && state != DL_FEATURE) |->
        (state inside {DL_INIT1, DL_INACTIVE});
    endproperty

    assert property (p_feature_next_state)
        else `uvm_error("ASSERT_FAIL", "Invalid state transition from DL_FEATURE");
    cover property (p_feature_next_state);

    // From DL_INIT2, next state can only be DL_ACTIVE or DL_INACTIVE
    property p_fc_init_next_state;
        @(posedge lclk)
        ($past(state) == DL_INIT2 && state != DL_INIT2) |->
        (state inside {DL_ACTIVE, DL_INACTIVE});
    endproperty

    assert property (p_fc_init_next_state)
        else `uvm_error("ASSERT_FAIL", "Invalid state transition from DL_INIT2");
    cover property (p_fc_init_next_state);

    // ============================================================
    // FEATURE_04 : TX feature field must match local supported register
    // ============================================================
    property p_tx_field_matches_local;
        @(posedge lclk) disable iff (reset || !pl_valid)
        (tx_is_feature && state==DL_FEATURE) |->
        (tx_feature_field == local_register_feature.local_feature_supported);
    endproperty

    assert_feature_04: assert property (p_tx_field_matches_local)
        else `uvm_error("ASSERT_FEATURE_04",
            $sformatf("FEATURE_04: TX feature field 0x%0h != local register 0x%0h",
                tx_feature_field, local_register_feature.local_feature_supported))
    cov_feature_04: cover property (p_tx_field_matches_local);

    // ============================================================
    // FEATURE_05 : TX ACK bit must equal the previous value of remote_feature_valid
    // ============================================================
    property p_ack_matches_valid;
        @(posedge lclk) disable iff (reset || !pl_lnk_up || !pl_valid)
        tx_is_feature |->
        (tx_ack_bit == $past(remote_register_feature.remote_feature_valid));
    endproperty

    assert_feature_05: assert property (p_ack_matches_valid)
        else `uvm_error("ASSERT_FEATURE_05",
            $sformatf("FEATURE_05: Ack bit %0b != remote_feature_valid %0b",
                tx_ack_bit, remote_register_feature.remote_feature_valid))
    cov_feature_05: cover property (p_ack_matches_valid);

    // ============================================================
    // FEATURE_06/07 : On first received Feature DLLP (valid=0),
    //                 remote_feature_supported must be recorded and valid set next cycle
    // ============================================================
    property p_remote_field_recorded_on_first_dllp;
        @(posedge lclk) disable iff (reset || !pl_lnk_up)
        // Trigger: first Feature DLLP arrives when valid is still clear
        (rx_is_feature && !$past(remote_register_feature.remote_feature_valid) && (state==DL_FEATURE) && ($past(state)!=DL_INACTIVE) && pl_valid)
        // Next cycle: supported field updated and valid set
        |=> ((remote_register_feature.remote_feature_supported == (rx_feature_field)) &&
             (remote_register_feature.remote_feature_valid == 1));
    endproperty

    assert_feature_06_07: assert property (p_remote_field_recorded_on_first_dllp)
        else `uvm_error("ASSERT_FEATURE_06_07",
            $sformatf("FEATURE_06_07: remote_feature_supported not updated on first DLLP. Expected 0x%0h got 0x%0h, valid=0x%0h",
                (rx_feature_field),
                remote_register_feature.remote_feature_supported,
                remote_register_feature.remote_feature_valid))
    cov_feature_06_07: cover property (p_remote_field_recorded_on_first_dllp);

    // ============================================================
    // FEATURE_08 : After valid=1, remote_feature_supported must NOT change on subsequent Feature DLLPs
    // ============================================================
    property p_no_update_after_valid_1;
        @(posedge lclk) disable iff (reset || !pl_valid)
        (state == DL_FEATURE &&
         rx_is_feature &&
         remote_register_feature.remote_feature_valid)
        // Value must remain stable next cycle
        |=> (remote_register_feature.remote_feature_supported ==
             $past(remote_register_feature.remote_feature_supported));
    endproperty

    assert_feature_08: assert property (p_no_update_after_valid_1)
        else `uvm_error("ASSERT_FEATURE_08",
            $sformatf("FEATURE_08: remote_feature_supported changed after Valid=1. Was 0x%0h now 0x%0h",
                $past(remote_register_feature.remote_feature_supported),
                remote_register_feature.remote_feature_supported))
    cov_feature_08: cover property (p_no_update_after_valid_1);

    // ============================================================
    // FEATURE_11 : scaled_fc_active must be set when ALL three conditions are true:
    //              feature_exchange_cap=1, local_supported[0]=1, remote_supported[0]=1
    // ============================================================
    property p_scaled_fc_active_when_all_set;
        @(posedge lclk) disable iff (reset || !pl_valid)
        (feature_exchange_cap                                &&
         local_register_feature.local_feature_supported[0]  &&
         remote_register_feature.remote_feature_supported[0] &&
         remote_register_feature.remote_feature_valid)
        |-> scaled_fc_active;
    endproperty

    assert_feature_11: assert property (p_scaled_fc_active_when_all_set)
        else `uvm_error("ASSERT_FEATURE_11",
            "FEATURE_11: All conditions met but scaled_fc_active=0")
    cov_feature_11: cover property (p_scaled_fc_active_when_all_set);

    // ============================================================
    // TRANS_FEAT_01 : DL_FEATURE -> DL_INIT1 when ACK=1 and LinkUp=1
    // ============================================================
    property p_feature_to_init_on_ack;
        @(posedge lclk) disable iff (reset || !pl_lnk_up)
        ($past(state) == DL_FEATURE &&
         pl_valid == 1'b1    &&
         rx_is_feature       &&
         rx_ack_bit == 1'b1)
        |=> (state == DL_INIT1);
    endproperty

    assert_trans_feat_01: assert property (p_feature_to_init_on_ack)
        else `uvm_error("ASSERT_TRANS_FEAT_01",
            "TRANS_FEAT_01: Did not transition to DL_INIT1 after Ack=1 + LinkUp=1")
    cov_trans_feat_01: cover property (p_feature_to_init_on_ack);

    // ============================================================
    // TRANS_FEAT_02 : DL_FEATURE -> DL_INIT1 on receipt of InitFC1_P + LinkUp=1
    //                 (hits when feature exchange is disabled)
    // ============================================================
    property p_feature_to_init_on_initfc1;
        @(posedge lclk) disable iff (reset || !pl_lnk_up || !pl_valid)
        (state == DL_FEATURE &&
         $past(state) != DL_INACTIVE &&
         rx_dllp[47:40] == INITFC1_P)
        |=> (state == DL_INIT1);
    endproperty

    assert_trans_feat_02: assert property (p_feature_to_init_on_initfc1)
        else `uvm_error("ASSERT_TRANS_FEAT_02",
            "TRANS_FEAT_02: Did not transition to DL_INIT1 after InitFC1 + LinkUp=1")
    cov_trans_feat_02: cover property (p_feature_to_init_on_initfc1);

    // ============================================================
    // TRANS_FEAT_04 : DL_FEATURE -> DL_INACTIVE when pl_lnk_up drops
    // ============================================================
    property p_feature_to_inactive_on_linkdown;
        @(posedge lclk) disable iff (reset)
        (state == DL_FEATURE && !pl_lnk_up) |=>
        (state == DL_INACTIVE);
    endproperty

    assert_trans_feat_04: assert property (p_feature_to_inactive_on_linkdown)
        else `uvm_error("ASSERT_TRANS_FEAT_04",
            "TRANS_FEAT_04: Did not transition to DL_INACTIVE when LinkUp=0")
    cov_trans_feat_04: cover property (p_feature_to_inactive_on_linkdown);

    // ============================================================
    // FCINIT1_03 : InitFC1 triplet must be transmitted in strict order P -> NP -> CPL -> P -> ...
    // ============================================================

    // P must be followed by NP
    property p_InitFC1_triplet_correct_order_p_np;
        @(posedge lclk) disable iff (reset || !pl_lnk_up)
        (state == DL_INIT1 && tx_is_initfc1_p)
        |=> if (state == DL_INIT1) tx_is_initfc1_np;
    endproperty

    // NP must be followed by CPL
    property p_InitFC1_triplet_correct_order_np_cpl;
        @(posedge lclk) disable iff (reset || !pl_lnk_up)
        (state == DL_INIT1 && tx_is_initfc1_np)
        |=> if (state == DL_INIT1) tx_is_initfc1_cpl;
    endproperty

    // CPL must be followed by P (cyclic)
    property p_InitFC1_triplet_correct_order_cpl_p;
        @(posedge lclk) disable iff (reset || !pl_lnk_up)
        (state == DL_INIT1 && tx_is_initfc1_cpl)
        |=> if (state == DL_INIT1) tx_is_initfc1_p;
    endproperty

    assert_fcinit1_03_p_np:   assert property (p_InitFC1_triplet_correct_order_p_np)
        else `uvm_error("ASSERT_FCINIT1_03", "FCINIT1_03: InitFC1-P-NP did not follow CORRECT order")
    assert_fcinit1_03_np_cpl: assert property (p_InitFC1_triplet_correct_order_np_cpl)
        else `uvm_error("ASSERT_FCINIT1_03", "FCINIT1_03: InitFC1-NP-CPL did not follow CORRECT order")
    assert_fcinit1_03_cpl_p:  assert property (p_InitFC1_triplet_correct_order_cpl_p)
        else `uvm_error("ASSERT_FCINIT1_03", "FCINIT1_03: InitFC1-CPL-P did not follow CORRECT order")

    cov_fcinit1_03_p_np:   cover property (p_InitFC1_triplet_correct_order_p_np);
    cov_fcinit1_03_np_cpl: cover property (p_InitFC1_triplet_correct_order_np_cpl);
    cov_fcinit1_03_cpl_p:  cover property (p_InitFC1_triplet_correct_order_cpl_p);

    // ============================================================
    // FCINIT1_08 : HdrScale and DataScale must be 00b in InitFC1 when Scaled FC is NOT active
    // ============================================================
    property p_scale_0_scaled_fc_not_active;
        @(posedge lclk) disable iff (reset)
        (state == DL_INIT1 && tx_is_initfc1 && !scaled_fc_active)
        |-> (tx_hdr_scale == 2'b00 && tx_data_scale == 2'b00);
    endproperty

    assert_fcinit1_08: assert property (p_scale_0_scaled_fc_not_active)
        else `uvm_error("ASSERT_FCINIT1_08",
            $sformatf("FCINIT1_08: Scale fields non-zero when Scaled FC inactive. HdrScale=%0b DataScale=%0b",
                tx_hdr_scale, tx_data_scale))
    cov_fcinit1_08: cover property (p_scale_0_scaled_fc_not_active);

    // ============================================================
    // FCINIT1_09 : At least one of HdrScale/DataScale must be non-zero in InitFC1 when Scaled FC IS active
    // ============================================================
    property p_scale_nonzero_when_active_init1;
        @(posedge lclk) disable iff (reset)
        (state == DL_INIT1 && tx_is_initfc1 && scaled_fc_active)
        |-> (tx_hdr_scale != 2'b00 || tx_data_scale != 2'b00);
    endproperty

    ast_fcinit1_09: assert property (p_scale_nonzero_when_active_init1)
        else `uvm_error("ASSERT_FCINIT1_09",
            "FCINIT1_09: Scale fields are 00b when Scaled FC is active")
    cov_fcinit1_09: cover property (p_scale_nonzero_when_active_init1);

    // ============================================================
    // FCINIT1_10 : Received InitFC1 OR InitFC2 credits must be stored correctly in DL_INIT1
    //              Posted, Non-Posted, and Completion credits all checked separately
    // ============================================================

    // Posted credits (P type) recorded from hdr[37:30] and data[27:16]
    property p_initfc_p_recorded;
        @(posedge lclk) disable iff (reset || !pl_valid)
        (state == DL_INIT1 && (rx_is_initfc1_p || rx_is_initfc2_p) && init1_p_f)
        |=> (remote_fc_credits_register.hdr_credits[FC_POSTED]  == $past(rx_dllp[37:30]) &&
             remote_fc_credits_register.data_credits[FC_POSTED] == $past(rx_dllp[27:16]));
    endproperty

    // Non-Posted credits (NP type)
    property p_initfc_np_recorded;
        @(posedge lclk) disable iff (reset || !pl_valid)
        (state == DL_INIT1 && (rx_is_initfc1_np || rx_is_initfc2_np) && init1_np_f)
        |=> (remote_fc_credits_register.hdr_credits[FC_NON_POSTED]  == $past(rx_dllp[37:30]) &&
             remote_fc_credits_register.data_credits[FC_NON_POSTED] == $past(rx_dllp[27:16]));
    endproperty

    // Completion credits (CPL type)
    property p_initfc_cpl_recorded;
        @(posedge lclk) disable iff (reset || !pl_valid)
        ((state) == DL_INIT2 && (rx_is_initfc1_cpl || rx_is_initfc2_cpl))
        |=> (remote_fc_credits_register.hdr_credits[FC_COMPLETION]  == $past(rx_dllp[37:30]) &&
             remote_fc_credits_register.data_credits[FC_COMPLETION] == $past(rx_dllp[27:16]));
    endproperty

    assert_fcinit1_10_fc_p:   assert property (p_initfc_p_recorded)
        else `uvm_error("ASSERT_FCINIT1_10", "FCINIT1_10: Posted credits not recorded from InitFC1-P || InitFC2-P")
    assert_fcinit1_10_fc_np:  assert property (p_initfc_np_recorded)
        else `uvm_error("ASSERT_FCINIT1_10", "FCINIT1_10: Non-Posted credits not recorded from InitFC1-NP || InitFC2-NP")
    assert_fcinit1_10_fc_cpl: assert property (p_initfc_cpl_recorded)
        else `uvm_error("ASSERT_FCINIT1_10", "FCINIT1_10: Completion credits not recorded from InitFC1-CPL || InitFC2-CPL")

    cov_fcinit1_10_fc_p:   cover property (p_initfc_p_recorded);
    cov_fcinit1_10_fc_np:  cover property (p_initfc_np_recorded);
    cov_fcinit1_10_fc_cpl: cover property (p_initfc_cpl_recorded);

    // ============================================================
    // FCINIT1_11 : HdrScale/DataScale from received InitFC1/FC2 must be stored when Scaled FC is active
    // ============================================================

    // Scale recorded from Posted (P) DLLP — bits 39:38=HdrScale, 29:28=DataScale
    property p_scale_recorded_p;
        @(posedge lclk) disable iff (reset || !pl_lnk_up || !pl_valid)
        (state == DL_INIT1 && (rx_is_initfc1_p || rx_is_initfc2_p) && scaled_fc_active)
        |=> (remote_fc_credits_register.hdr_scale[FC_POSTED]  == $past(rx_dllp[39:38]) &&
             remote_fc_credits_register.data_scale[FC_POSTED] == $past(rx_dllp[29:28]));
    endproperty

    // Scale recorded from Non-Posted (NP) DLLP
    property p_scale_recorded_np;
        @(posedge lclk) disable iff (reset || !pl_lnk_up || !pl_valid)
        (state == DL_INIT1 && (rx_is_initfc1_np || rx_is_initfc2_np) && scaled_fc_active)
        |=> (remote_fc_credits_register.hdr_scale[FC_NON_POSTED]  == $past(rx_dllp[39:38]) &&
             remote_fc_credits_register.data_scale[FC_NON_POSTED] == $past(rx_dllp[29:28]));
    endproperty

    // Scale recorded from Completion (CPL) DLLP
    property p_scale_recorded_cpl;
        @(posedge lclk) disable iff (reset || !pl_lnk_up || !pl_valid)
        ($past(state) == DL_INIT1 && (rx_is_initfc1_cpl || rx_is_initfc2_cpl) && scaled_fc_active)
        |-> (remote_fc_credits_register.hdr_scale[FC_COMPLETION]  == (rx_dllp[39:38]) &&
             remote_fc_credits_register.data_scale[FC_COMPLETION] == (rx_dllp[29:28]));
    endproperty

    assert_fcinit1_11_p:   assert property (p_scale_recorded_p)
        else `uvm_error("ASSERT_FCINIT1_11", "FCINIT1_11: Posted scale not recorded from InitFC1-P")
    assert_fcinit1_11_np:  assert property (p_scale_recorded_np)
        else `uvm_error("ASSERT_FCINIT1_11", "FCINIT1_11: Non-Posted scale not recorded from InitFC1-NP")
    assert_fcinit1_11_cpl: assert property (p_scale_recorded_cpl)
        else `uvm_error("ASSERT_FCINIT1_11", "FCINIT1_11: Completion scale not recorded from InitFC1-CPL")

    cov_fcinit1_11_p:   cover property (p_scale_recorded_p);
    cov_fcinit1_11_np:  cover property (p_scale_recorded_np);
    cov_fcinit1_11_cpl: cover property (p_scale_recorded_cpl);

    // ============================================================
    // FCINIT1_12 : fi1_flag must be set only after ALL three (P, NP, CPL) received in order
    //              Two variants: one for InitFC1 triplets, one for InitFC2 triplets received in INIT1
    // ============================================================

    // fi1_flag set after receiving InitFC1 P -> NP -> CPL in DL_INIT1
    property p_fi1_set_after_P_NP_CPL_init1;
        @(posedge lclk) disable iff (reset || !pl_lnk_up || !pl_valid)
        (state == DL_INIT1 && rx_is_initfc1_p && ($past(state)!=DL_INACTIVE))
        |=> (state == DL_INIT1 && rx_is_initfc1_np)
        |=> (state == DL_INIT1 && rx_is_initfc1_cpl)
        |-> fi1_flag
    endproperty

    // fi1_flag set after receiving InitFC2 P -> NP -> CPL while still in DL_INIT1
    property p_fi1_set_after_P_NP_CPL_init2;
        @(posedge lclk) disable iff (reset || !pl_lnk_up || !pl_valid)
        (state == DL_INIT1 && rx_is_initfc2_p && ($past(state)!=DL_INACTIVE))
        |=> (state == DL_INIT1 && rx_is_initfc2_np)
        |=> (state == DL_INIT1 && rx_is_initfc2_cpl)
        |-> fi1_flag
    endproperty

    assert_fcinit1_12_initfc1: assert property (p_fi1_set_after_P_NP_CPL_init1)
        else `uvm_error("ASSERT_FCINIT1_12", "FCINIT1_12: FI1 not set after all three P+NP+CPL INIT1 received")
    assert_fcinit1_12_initfc2: assert property (p_fi1_set_after_P_NP_CPL_init2)
        else `uvm_error("ASSERT_FCINIT1_12", "FCINIT1_12: FI1 not set after all three P+NP+CPL INIT2 received")

    cov_fcinit1_12_initfc1: cover property (p_fi1_set_after_P_NP_CPL_init1);
    cov_fcinit1_12_initfc2: cover property (p_fi1_set_after_P_NP_CPL_init2);

    // ============================================================
    // TRANS_INIT1_01 : DL_INIT1 -> DL_INIT2 when fi1_flag=1 and LinkUp=1
    // ============================================================
    property p_trans_init1_to_init2_on_fi1;
        @(posedge lclk) disable iff (reset || !pl_valid)
        ((state == DL_INIT1) && fi1_flag == 1'b1 && pl_lnk_up == 1'b1)
        |=> (state == DL_INIT2);
    endproperty

    assert_trans_init1_01: assert property (p_trans_init1_to_init2_on_fi1)
        else `uvm_error("ASSERT_TRANS_INIT1_01",
            "TRANS_INIT1_01: Did not transition to DL_INIT2 when FI1=1 + LinkUp=1")
    cov_trans_init1_01: cover property (p_trans_init1_to_init2_on_fi1);

    // ============================================================
    // FCINIT2_03 : InitFC2 triplet must be transmitted in strict order P -> NP -> CPL
    // ============================================================

    // P must be followed by NP
    property p_initfc2_P_NP_in_order;
        @(posedge lclk) disable iff (reset || !pl_lnk_up)
        (state == DL_INIT2 && tx_is_initfc2_p)
        |=> if (state == DL_INIT2) tx_is_initfc2_np;
    endproperty

    // NP must be followed by CPL
    property p_initfc2_NP_CPL_in_order;
        @(posedge lclk) disable iff (reset || !pl_lnk_up)
        (state == DL_INIT2 && tx_is_initfc2_np)
        |=> if (state == DL_INIT2) tx_is_initfc2_cpl;
    endproperty

    assert_fcinit2_03_P_NP:  assert property (p_initfc2_P_NP_in_order)
        else `uvm_error("ASSERT_FCINIT2_03", "FCINIT2_03: InitFC2 triplet wrong order P_NP")
    assert_fcinit2_03_NP_CPL: assert property (p_initfc2_NP_CPL_in_order)
        else `uvm_error("ASSERT_FCINIT2_03", "FCINIT2_03: InitFC2 triplet wrong order NP_CPL")

    cov_fcinit2_03_P_NP:  cover property (p_initfc2_P_NP_in_order);
    cov_fcinit2_03_NP_CPL: cover property (p_initfc2_NP_CPL_in_order);

    // ============================================================
    // FCINIT2_04/05 : In DL_INIT2, received InitFC1 or InitFC2 DLLPs must be IGNORED
    //                 Credits and scale registers must NOT change
    // ============================================================
    property p_initfc1_2_ignored;
        @(posedge lclk) disable iff (reset || !pl_valid)
        (state == DL_INIT2 && (rx_is_initfc1 || rx_is_initfc2))
        // All four credit/scale fields must remain stable
        |-> (remote_fc_credits_register.hdr_credits  == $past(remote_fc_credits_register.hdr_credits)  &&
             remote_fc_credits_register.data_credits == $past(remote_fc_credits_register.data_credits) &&
             remote_fc_credits_register.hdr_scale    == $past(remote_fc_credits_register.hdr_scale)    &&
             remote_fc_credits_register.data_scale   == $past(remote_fc_credits_register.data_scale));
    endproperty

    assert_fcinit2_04: assert property (p_initfc1_2_ignored)
        else `uvm_error("ASSERT_FCINIT2_04",
            "FCINIT2_04: Remote FC credits / scale changed on received posted initfc")
    cov_fcinit2_04: cover property (p_initfc1_2_ignored);

    // ============================================================
    // FCINIT2_06 : fi2_flag must be set only after ALL three InitFC2 (P, NP, CPL) received in order
    // ============================================================
    property p_fi2_set_after_P_NP_CPL;
        @(posedge lclk) disable iff (reset || !pl_lnk_up || !pl_valid)
        (state == DL_INIT2 && rx_is_initfc2_p)
        |=> (state == DL_INIT2 && rx_is_initfc2_np)
        |=> ($past(state) == DL_INIT2 && rx_is_initfc2_cpl)
        |=> (fi2_flag)
    endproperty

    assert_fcinit2_06_fi2: assert property (p_fi2_set_after_P_NP_CPL)
        else `uvm_error("ASSERT_FCINIT2_06", "FCINIT2_06: FI2 not set after all three P+NP+CPL INIT2 received")
    cov_fcinit2_06_fi2: cover property (p_fi2_set_after_P_NP_CPL);

    // ============================================================
    // FCINIT2_08 : fi2_flag must already be set when an UpdateFC DLLP is received in DL_INIT2
    // ============================================================
    property p_fi2_set_on_updatefc;
        @(posedge lclk) disable iff (reset || !pl_valid)
        (state == DL_INIT2 && rx_dllp[47:40] inside {UPDATEFC_P, UPDATEFC_NP, UPDATEFC_CPL})
        |-> fi2_flag;
    endproperty

    assert_fcinit2_08: assert property (p_fi2_set_on_updatefc)
        else `uvm_error("ASSERT_FCINIT2_08",
            "FCINIT2_08: FI2 not set after UpdateFC transmitted before InitFC2 arrived")
    cov_fcinit2_08: cover property (p_fi2_set_on_updatefc);

    // ============================================================
    // FCINIT2_09 : HdrScale and DataScale must be 00b in InitFC2 when Scaled FC is NOT active
    // ============================================================
    property p_scale_zero_when_not_active;
        @(posedge lclk) disable iff (reset)
        (state == DL_INIT2 && tx_is_initfc2 && !scaled_fc_active)
        |-> (tx_hdr_scale == 2'b00 && tx_data_scale == 2'b00);
    endproperty

    assert_fcinit2_09: assert property (p_scale_zero_when_not_active)
        else `uvm_error("ASSERT_FCINIT2_09",
            $sformatf("FCINIT2_09: Scale non-zero in InitFC2 when Scaled FC inactive. HdrScale=%0b DataScale=%0b",
                rx_hdr_scale, rx_data_scale))
    cov_fcinit2_09: cover property (p_scale_zero_when_not_active);

    // ============================================================
    // FCINIT2_10 : BOTH HdrScale and DataScale must be non-zero in InitFC2 when Scaled FC IS active
    // ============================================================
    property p_scale_nonzero_when_active_init2;
        @(posedge lclk) disable iff (reset)
        (state == DL_INIT2 && tx_is_initfc2 && scaled_fc_active)
        |-> (tx_hdr_scale != 2'b00 && tx_data_scale != 2'b00);
    endproperty

    assert_fcinit2_10: assert property (p_scale_nonzero_when_active_init2)
        else `uvm_error("ASSERT_FCINIT2_10",
            "FCINIT2_10: Scale fields are 00b in InitFC2 when Scaled FC is active")
    cov_fcinit2_10: cover property (p_scale_nonzero_when_active_init2);

    // ============================================================
    // FCINIT2_11 : UpdateFC DLLPs in DL_ACTIVE must use the same scale advertised during init
    //              Checked separately for Posted, Non-Posted, and Completion
    // ============================================================

    // Posted UpdateFC scale must match what was advertised in local_fc_credits_register
    property p_updatefc_scale_matches_init_p;
        @(posedge lclk) disable iff (reset || !pl_valid)
        (state == DL_ACTIVE && tx_dllp[47:40] == UPDATEFC_P && scaled_fc_active)
        |-> (tx_hdr_scale  == local_fc_credits_register.hdr_scale[FC_POSTED] &&
             tx_data_scale == local_fc_credits_register.data_scale[FC_POSTED]);
    endproperty

    // Non-Posted UpdateFC scale check
    property p_updatefc_scale_matches_init_np;
        @(posedge lclk) disable iff (reset || !pl_valid)
        (state == DL_ACTIVE && tx_dllp[47:40] == UPDATEFC_NP && scaled_fc_active)
        |-> (tx_hdr_scale  == local_fc_credits_register.hdr_scale[FC_NON_POSTED] &&
             tx_data_scale == local_fc_credits_register.data_scale[FC_NON_POSTED]);
    endproperty

    // Completion UpdateFC scale check
    property p_updatefc_scale_matches_init_cpl;
        @(posedge lclk) disable iff (reset || !pl_valid)
        (state == DL_ACTIVE && tx_dllp[47:40] == UPDATEFC_CPL && scaled_fc_active)
        |-> (tx_hdr_scale  == local_fc_credits_register.hdr_scale[FC_COMPLETION] &&
             tx_data_scale == local_fc_credits_register.data_scale[FC_COMPLETION]);
    endproperty

    assert_fcinit2_11_p:   assert property (p_updatefc_scale_matches_init_p)
        else `uvm_error("ASSERT_FCINIT2_11", "FCINIT2_11: UpdateFC-P scale mismatch with init advertisement")
    assert_fcinit2_11_np:  assert property (p_updatefc_scale_matches_init_np)
        else `uvm_error("ASSERT_FCINIT2_11", "FCINIT2_11: UpdateFC-NP scale mismatch with init advertisement")
    assert_fcinit2_11_cpl: assert property (p_updatefc_scale_matches_init_cpl)
        else `uvm_error("ASSERT_FCINIT2_11", "FCINIT2_11: UpdateFC-CPL scale mismatch with init advertisement")

    cov_fcinit2_11_p:   cover property (p_updatefc_scale_matches_init_p);
    cov_fcinit2_11_np:  cover property (p_updatefc_scale_matches_init_np);
    cov_fcinit2_11_cpl: cover property (p_updatefc_scale_matches_init_cpl);

    // ============================================================
    // TRANS_INIT2_01 : DL_INIT2 -> DL_ACTIVE when fi2_flag=1 and LinkUp=1
    // ============================================================
    property p_trans_init2_to_active;
        @(posedge lclk) disable iff (reset || !pl_valid)
        ($past(state) == DL_INIT2 && fi2_flag == 1'b1 && pl_lnk_up == 1'b1)
        |=> (state == DL_ACTIVE);
    endproperty

    assert_trans_init2_01: assert property (p_trans_init2_to_active)
        else `uvm_error("ASSERT_TRANS_INIT2_01",
            "TRANS_INIT2_01: Did not transition to DL_ACTIVE when FI2=1 + InitFC2 + LinkUp=1")
    cov_trans_init2_01: cover property (p_trans_init2_to_active);

    // ============================================================
    // LPIF INTERFACE ASSERTIONS
    // ============================================================

    // When lp_valid is high, lp_data must not contain X or Z
    property p_lp_valid_data_known;
        @(posedge lclk) disable iff (reset)
        (lp_valid) |-> !$isunknown(lp_data);
    endproperty

    assert property (p_lp_valid_data_known)
        else `uvm_error("ASSERT_LPIF_02", "LPIF_02: lp_valid is HIGH but lp_data contains X/Z");
    cover property (p_lp_valid_data_known);

    // When pl_valid is high and link is up, pl_data must not contain X or Z next cycle
    property p_rx_dllp_known_when_valid;
        @(posedge lclk) disable iff (reset || !pl_lnk_up)
        (pl_valid) |=> !$isunknown(pl_data);
    endproperty

    assert property (p_rx_dllp_known_when_valid)
        else `uvm_error("ASSERT_LPIF_03", "DLLP_LPIF_03: pl_valid = 1 but pl_data is unknown");

    // ============================================================
    // DLLP TYPE LEGALITY ASSERTIONS
    // ============================================================
    // ============================================================
    // TYPE_LEGAL_06 : In DL_FEATURE, only FEATURE is legal TX DLLP
    // ============================================================
    property p_tx_dllp_type_legal_feature;
        @(posedge lclk) disable iff (reset || !lp_valid || !pl_lnk_up)
        (state == DL_FEATURE) |=>
        (tx_is_feature);
    endproperty

    assert_type_legal_06_tx: assert property (p_tx_dllp_type_legal_feature)
        else `uvm_error("ASSERT_TYPE_LEGAL_06",
            $sformatf("TYPE_LEGAL_06_TX: Illegal TX DLLP type 0x%0h in DL_FEATURE state (expected FEATURE)", 
                tx_dllp[47:40]))
    cov_type_legal_06_tx: cover property (p_tx_dllp_type_legal_feature);

    // ============================================================
    // TYPE_LEGAL_08 : In DL_INIT1, only InitFC1 types are legal TX DLLPs
    // ============================================================
    property p_tx_dllp_type_legal_init1;
        @(posedge lclk) disable iff (reset || !lp_valid || !pl_lnk_up)
        (state == DL_INIT1) |=>
        (tx_is_initfc1);
    endproperty

    assert_type_legal_08_tx: assert property (p_tx_dllp_type_legal_init1)
        else `uvm_error("ASSERT_TYPE_LEGAL_08",
            $sformatf("TYPE_LEGAL_08_TX: Illegal TX DLLP type 0x%0h in DL_INIT1 state (expected INITFC1)", 
                tx_dllp[47:40]))
    cov_type_legal_08_tx: cover property (p_tx_dllp_type_legal_init1);

    // ============================================================
    // TYPE_LEGAL_09 : In DL_INIT2, only InitFC2  types are legal TX DLLPs
    // ============================================================
    property p_tx_dllp_type_legal_init2;
        @(posedge lclk) disable iff (reset || !lp_valid || !pl_lnk_up)
        (state == DL_INIT2) |=>
        (tx_is_initfc2);
    endproperty

    assert_type_legal_09_tx: assert property (p_tx_dllp_type_legal_init2)
        else `uvm_error("ASSERT_TYPE_LEGAL_09",
            $sformatf("TYPE_LEGAL_09_TX: Illegal TX DLLP type 0x%0h in DL_INIT2 state (expected INITFC2)", 
                tx_dllp[47:40]))
    cov_type_legal_09_tx: cover property (p_tx_dllp_type_legal_init2);

    // ============================================================
    // TYPE_LEGAL_10 : In DL_ACTIVE, only UpdateFC types are legal TX DLLPs (besides ACK/NACK)
    // ============================================================
    property p_tx_dllp_type_legal_active;
        @(posedge lclk) disable iff (reset || !lp_valid || !pl_lnk_up)
        (state == DL_ACTIVE) |=>
        (tx_dllp[47:40] inside {UPDATEFC_P, UPDATEFC_NP, UPDATEFC_CPL, ACK, NACK});
    endproperty

    assert_type_legal_10_tx: assert property (p_tx_dllp_type_legal_active)
        else `uvm_error("ASSERT_TYPE_LEGAL_10",
            $sformatf("TYPE_LEGAL_10_TX: Illegal TX DLLP type 0x%0h in DL_ACTIVE state (expected UPDATEFC)", 
                tx_dllp[47:40]))
    cov_type_legal_10_tx: cover property (p_tx_dllp_type_legal_active);

endinterface : passive_interface
`endif
