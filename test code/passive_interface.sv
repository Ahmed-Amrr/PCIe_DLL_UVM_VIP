interface passive_interface (input logic lclk);
    import dll_pkg::*;
	import uvm_pkg::*;
    `include "uvm_macros.svh"
	bit [47:0] tx_dllp;
	bit [47:0] rx_dllp;

	dl_feature_cap_reg_t local_register_feature;       //for feature "Scaled Flow Control" the only important bits are
	                                                //feature_exchange_enable and local_feature_supported [0] (Supported or not)
	dl_feature_status_reg_t remote_register_feature;   //for feature "Scaled Flow Control" the only important bits are
	                                                //remote_feature_valid and remote_feature_supported [0] (Supported or not)
	fc_credits_t fc_credits_register;                  //for "hdr_credits & data_credits" are for the credits counter
	                                                //for "hdr_scale & data_scale" are for the scale
	bit feature_exchange_cap;

	dl_state_t state;

	logic pl_lnk_up;

	logic reset;
    logic rst_req;
	logic pl_valid;
	logic lp_valid;
	logic lp_data;
	logic pl_data;

	logic DL_Up;
	logic DL_Down;

	logic scaled_fc_active;

	logic fi1_flag;
	logic fi2_flag;

    logic tx_is_initfc1_p;
    logic tx_is_initfc1_np;
    logic tx_is_initfc1_cpl;
	logic tx_is_initfc2_p;
    logic tx_is_initfc2_np;
    logic tx_is_initfc2_cpl;
	logic tx_hdr_scale;
	logic rx_hdr_scale;
	logic tx_is_initfc1;
	logic tx_is_initfc2;
	logic rx_is_initfc1;
	logic rx_is_initfc2;
	logic rx_is_initfc2_p;
    logic rx_is_initfc2_np;
    logic rx_is_initfc2_cpl;
	logic rx_is_initfc1_p;
    logic rx_is_initfc1_np;
    logic rx_is_initfc1_cpl;
	logic        tx_is_feature;
    logic        rx_is_feature;
    logic [22:0] tx_feature_field;
    logic [22:0] rx_feature_field;
    logic        tx_ack_bit;
    logic        rx_ack_bit;

    assign tx_is_feature   = (tx_dllp[47:40] == FEATURE);
    assign rx_is_feature   = (rx_dllp[47:40] == FEATURE);
    assign tx_feature_field = tx_dllp[38:16];
    assign rx_feature_field = rx_dllp[38:16];
    assign tx_ack_bit       = tx_dllp[39];
    assign rx_ack_bit       = rx_dllp[39];


    assign tx_is_initfc1_p   = (tx_dllp[47:40] == INITFC1_P);
    assign tx_is_initfc1_np  = (tx_dllp[47:40] == INITFC1_NP);
    assign tx_is_initfc1_cpl = (tx_dllp[47:40] == INITFC1_CPL);
    assign tx_is_initfc2_p   = (tx_dllp[47:40] == INITFC2_P);
    assign tx_is_initfc2_np  = (tx_dllp[47:40] == INITFC2_NP);
    assign tx_is_initfc2_cpl = (tx_dllp[47:40] == INITFC2_CPL);

	assign rx_is_initfc1_p   = (rx_dllp[47:40] == INITFC1_P);
    assign rx_is_initfc1_np  = (rx_dllp[47:40] == INITFC1_NP);
    assign rx_is_initfc1_cpl = (rx_dllp[47:40] == INITFC1_CPL);
	assign rx_is_initfc2_p   = (rx_dllp[47:40] == INITFC2_P);
    assign rx_is_initfc2_np  = (rx_dllp[47:40] == INITFC2_NP);
    assign rx_is_initfc2_cpl = (rx_dllp[47:40] == INITFC2_CPL);

	assign tx_hdr_scale  = tx_dllp[39:38];
    assign tx_data_scale = tx_dllp[29:28];
	assign tx_is_initfc1 = (tx_dllp[47:40] inside {INITFC1_P,INITFC1_NP,INITFC1_CPL});
    assign tx_is_initfc2 = (tx_dllp[47:40] inside {INITFC2_P,INITFC2_NP,INITFC2_CPL}); 
    assign rx_is_initfc1 = (rx_dllp[47:40] inside {INITFC1_P,INITFC1_NP,INITFC1_CPL});
    assign rx_is_initfc2 = (rx_dllp[47:40] inside {INITFC2_P,INITFC2_NP,INITFC2_CPL}); 

	
	// check remote feature signals are cleared one cycle after reset
	property p_reset_clears_remote_feature;
		@(posedge lclk)
		(reset == 1) |=>
		(dl_feature_status.remote_feature_valid    == 0 &&
		dl_feature_status.remote_feature_supported == 0);
	endproperty

	assert property (p_reset_clears_remote_feature)
		else `uvm_error("ASSERT_FAIL", "Remote feature signals not cleared after reset");
        
	// cover: reset occurred and remote feature signals were cleared next cycle
	cover property (p_reset_clears_remote_feature);

	// LINK_STATUS must be DL_UP when state is DL_ACTIVE or FC_INIT2
	property p_link_up_in_active_states;
		@(posedge lclk) disable iff (reset)
		(state == DL_ACTIVE || state == DL_INIT2) |->
		(DL_Up == 1'b1 && DL_Down == 1'b0);
	endproperty
	assert property (p_link_up_in_active_states)
		else `uvm_error("ASSERT_FAIL", "LINK_STATUS should be DL_UP in DL_ACTIVE or FC_INIT2");
	// cover: DL_UP seen while in DL_ACTIVE or FC_INIT2
	cover property (p_link_up_in_active_states);

	// LINK_STATUS must be DL_DOWN when state is DL_INACTIVE, DL_FEATURE, or FC_INIT1
	property p_link_down_in_inactive_states;
		@(posedge lclk) disable iff (reset)
		(state inside {DL_INACTIVE, DL_FEATURE, DL_INIT1}) |->
		(DL_Down == 1'b1 && DL_Up == 1'b0);
	endproperty
	assert property (p_link_down_in_inactive_states)
	     else `uvm_error("ASSERT_FAIL", "LINK_STATUS should be DL_DOWN in DL_INACTIVE, DL_FEATURE, or FC_INIT1");
	// cover: DL_DOWN seen while in DL_INACTIVE, DL_FEATURE, or FC_INIT1
	cover property (p_link_down_in_inactive_states);

	// when pl_link_up is low → state must be INACTIVE
	property p_link_down_state_inactive;
		@(posedge lclk) disable iff (reset)
		(!pl_lnk_up) |->
		(state == DL_INACTIVE);
	endproperty
	assert property (p_link_down_state_inactive)
		else `uvm_error("ASSERT_FAIL", "State must be DL_INACTIVE when pl_link_up is low");
	// cover: pl_link_up low and state was DL_INACTIVE
	cover property (p_link_down_state_inactive);

	// when pl_link_up is high → state must be FEATURE, INIT, or ACTIVE
	property p_link_up_state_valid;
		@(posedge lclk) disable iff (reset)
		(pl_lnk_up) |->
		(state inside {DL_FEATURE, DL_INIT1, DL_INIT2, DL_ACTIVE});
	endproperty
	assert property (p_link_up_state_valid)
		else `uvm_error("ASSERT_FAIL", "State must be DL_FEATURE/DL_INIT1/DL_INIT2/DL_ACTIVE when pl_link_up is high");
	// cover: pl_link_up high and state was FEATURE/INIT/ACTIVE
	cover property (p_link_up_state_valid);

	// if pl_link_up drops in any active state → must go to DL_INACTIVE next cycle
	property p_link_drop_goes_inactive;
		@(posedge lclk)
		(state inside {DL_FEATURE, DL_INIT1, DL_INIT2, DL_ACTIVE} && !pl_lnk_up) |=>
		(state == DL_INACTIVE);
	endproperty
	assert property (p_link_drop_goes_inactive)
		else `uvm_error("ASSERT_FAIL", "State did not transition to DL_INACTIVE after pl_link_up drop");
	// cover: pl_link_up dropped in active state and went to DL_INACTIVE
	cover property (p_link_drop_goes_inactive);

	// from INACTIVE, state can only transition to FEATURE or INIT
	property p_inactive_next_state;
		@(posedge lclk)
		($past(state) == DL_INACTIVE && state != DL_INACTIVE) |->
		(state inside {DL_FEATURE, DL_INIT1});
	endproperty
	assert property (p_inactive_next_state)
		else `uvm_error("ASSERT_FAIL", "Invalid state transition from DL_INACTIVE");
	// cover: valid transition out of DL_INACTIVE
	cover property (p_inactive_next_state);

	// from FEATURE, state can only transition to INIT1 or INACTIVE
	property p_feature_next_state;
		@(posedge lclk)
		($past(state) == DL_FEATURE && state != DL_FEATURE) |->
		(state inside {DL_INIT1, DL_INACTIVE});
	endproperty
	assert property (p_feature_next_state)
		else `uvm_error("ASSERT_FAIL", "Invalid state transition from DL_FEATURE");
	// cover: valid transition out of DL_FEATURE
	cover property (p_feature_next_state);

	// from INIT2, state can only transition to ACTIVE or INACTIVE
	property p_fc_init_next_state;
		@(posedge lclk)
		($past(state) == DL_INIT2 && state != DL_INIT2) |->
		(state inside {DL_ACTIVE, DL_INACTIVE});
	endproperty
	assert property (p_fc_init_next_state)
		else `uvm_error("ASSERT_FAIL", "Invalid state transition from DL_INIT2");
	// cover: valid transition out of DL_INIT2
	cover property (p_fc_init_next_state);

	// ============================================================
    // FEATURE_04 : Transmitted Feature Supported field must equal Local DL Feature Supported register
    // ============================================================
    property p_tx_field_matches_local;
        @(posedge lclk) disable iff (reset)
        // The feature field must match the local register whenever we transmit a Feature DLLP
        tx_is_feature |-> (tx_feature_field == local_register_feature.local_feature_supported);
    endproperty

    assert_feature_04: assert property (p_tx_field_matches_local)
        else `uvm_error("ASSERT_FEATURE_04",
            $sformatf("FEATURE_04: TX feature field 0x%0h != local register 0x%0h",
                tx_feature_field,
                local_register_feature.local_feature_supported))

    cov_feature_04: cover property (p_tx_field_matches_local);

    // ============================================================
    // FEATURE_05 : Transmitted Feature Ack bit must equal Remote DL Feature Supported Valid bit 
    // ============================================================
    property p_ack_matches_valid;
        @(posedge lclk) disable iff (reset)
        tx_is_feature |-> (tx_ack_bit == remote_register_feature.remote_feature_valid);
    endproperty

    assert_feature_05: assert property (p_ack_matches_valid)
        else `uvm_error("ASSERT_FEATURE_05",
            $sformatf("FEATURE_05: Ack bit %0b != remote_feature_valid %0b",
                tx_ack_bit, remote_register_feature.remote_feature_valid))


    cov_feature_05: cover property (p_ack_matches_valid);

    // ============================================================
    // FEATURE_06 : Remote DL Feature Supported field must be recorded on the first Feature DLLP received when Valid=Clear
    // FEATURE_07 : Remote DL Feature Supported Valid bit must be set after the first valid Feature DLLP is received
    // ============================================================
    property p_remote_field_recorded_on_first_dllp;
        @(posedge lclk) disable iff (reset)
        // First Feature DLLP arrives when Valid is still 0
        (rx_is_feature && !remote_register_feature.remote_feature_valid)
        // Next cycle remote_feature_supported must equal the received feature field and valid asserted
        |=> (remote_register_feature.remote_feature_supported ==  $past(rx_feature_field) &&
            remote_register_feature.remote_feature_valid );
    endproperty

    assert_feature_06_07: assert property (p_remote_field_recorded_on_first_dllp)
        else `uvm_error("ASSERT_FEATURE_06_07",
            $sformatf("FEATURE_06_07: remote_feature_supported not updated on first DLLP. Expected 0x%0h got 0x%0h ,
                       remote_feature_valid not set after first Feature DLLP",
                 $past(rx_feature_field),
                remote_register_feature.remote_feature_supported))

    cov_feature_06_07: cover property (p_remote_field_recorded_on_first_dllp);

    // ============================================================
    // FEATURE_08 : Remote DL Feature field must NOT be updated on subsequent Feature DLLPs when Valid is already Set
    // ============================================================
    property p_no_update_after_valid_1;
        @(posedge lclk) disable iff (reset)
        // Subsequent Feature DLLP arrives when Valid already=1
        (rx_is_feature && remote_register_feature.remote_feature_valid)
        // remote_feature_supported must remain unchanged next cycle
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
    // FEATURE_09 : No ACK DLLPs must be transmitted while in DL_Feature
    // ============================================================
    property p_no_ack_in_dl_feature;
        @(posedge lclk) disable iff (reset)
        (state == DL_FEATURE)
        |-> (tx_dllp[47:40] != ACK);
    endproperty

    assert_feature_09: assert property (p_no_ack_in_dl_feature)
        else `uvm_error("ASSERT_FEATURE_09",
            "FEATURE_09: ACK DLLP transmitted during DL_Feature state")

    cov_feature_09: cover property (p_no_ack_in_dl_feature);

    // ============================================================
    // FEATURE_11
    // scaled_fc_active must be set ONLY when ALL THREE conditions:
    //   feature_exchange_cap == 1 AND
    //   local_feature_supported[0]  == 1 AND
    //   remote_feature_supported[0] == 1
    // ============================================================
    property p_scaled_fc_active_when_all_set;
        @(posedge lclk) disable iff (reset)
        (feature_exchange_cap                                    &&
         local_register_feature.local_feature_supported[0]       &&
         remote_register_feature.remote_feature_supported[0]     &&
		 remote_register_feature.remote_feature_valid )
        |-> scaled_fc_active;
    endproperty

    assert_feature_11 : assert property (p_scaled_fc_active_when_all_set)
        else `uvm_error("ASSERT_FEATURE_11",
            "FEATURE_11: All conditions met but scaled_fc_active=0")
    cov_feature_11: cover property (p_scaled_fc_active_when_all_set);

    // ============================================================
    // TRANS_FEAT_01 : Exit DL_Feature -> DL_Init when (Ack=1) + LinkUp=1
    // ============================================================
    property p_feature_to_init_on_ack;
        @(posedge lclk) disable iff (reset)
        // Ack=1 received while in DL_Feature with LinkUp=1
        (state == DL_FEATURE   &&
         rx_is_feature         &&
         rx_ack_bit == 1'b1    &&
         pl_lnk_up  == 1'b1)
        // transition to DL_INIT1 next cycle
        |=> (state == DL_INIT1);
    endproperty

    assert_trans_feat_01: assert property (p_feature_to_init_on_ack)
        else `uvm_error("ASSERT_TRANS_FEAT_01",
            "TRANS_FEAT_01: Did not transition to DL_INIT1 after Ack=1 + LinkUp=1")

    cov_trans_feat_01: cover property (p_feature_to_init_on_ack);

    // ============================================================
    // TRANS_FEAT_02 : Exit DL_Feature -> DL_Init on receipt of InitFC1 DLLP + LinkUp=1
    // ============================================================
    property p_feature_to_init_on_initfc1;
        @(posedge lclk) disable iff (reset)
        (state == DL_FEATURE &&
         rx_dllp[47:40] inside {INITFC1_P, INITFC1_NP, INITFC1_CPL} &&
         pl_lnk_up == 1'b1)
        |=> (state == DL_INIT1);
    endproperty

    assert_trans_feat_02: assert property (p_feature_to_init_on_initfc1)
        else `uvm_error("ASSERT_TRANS_FEAT_02",
            "TRANS_FEAT_02: Did not transition to DL_INIT1 after InitFC1 + LinkUp=1")

    cov_trans_feat_02: cover property (p_feature_to_init_on_initfc1);

    // ============================================================
    // TRANS_FEAT_04 : Exit DL_Feature -> DL_Inactive when Physical LinkUp=0
    // ============================================================
    property p_feature_to_inactive_on_linkdown;
        @(posedge lclk) disable iff (reset)
        (state == DL_FEATURE && !pl_lnk_up)
        |=> (state == DL_INACTIVE);
    endproperty

    assert_trans_feat_04: assert property (p_feature_to_inactive_on_linkdown)
        else `uvm_error("ASSERT_TRANS_FEAT_04",
            "TRANS_FEAT_04: Did not transition to DL_INACTIVE when LinkUp=0")

    cov_trans_feat_04: cover property (p_feature_to_inactive_on_linkdown);

    // ============================================================
    // FCINIT1_03 : InitFC1 triplet must be transmitted in strict order P->NP->CPL
    // ============================================================
    property p_InitFC1_triplet_correct_order_p_np;
        @(posedge lclk) disable iff (reset || !pl_lnk_up)
        (state == DL_INIT1 && tx_is_initfc1_p)
		// After P is sent, NP must come next
        |=> (state == DL_INIT1 && tx_is_initfc1_np);
    endproperty
	property p_InitFC1_triplet_correct_order_np_cpl;
        @(posedge lclk) disable iff (reset || !pl_lnk_up)
        (state == DL_INIT1 && tx_is_initfc1_np )
		// After NP is sent, CPL must come next
        |=> (state == DL_INIT1 && tx_is_initfc1_cpl);
	endproperty

	property p_InitFC1_triplet_correct_order_cpl_p;
        @(posedge lclk) disable iff (reset || !pl_lnk_up)
        (state == DL_INIT1 && tx_is_initfc1_cpl )
		// After CPL is sent, P must come next
        |=> (state == DL_INIT1 && tx_is_initfc1_p);
	endproperty

    assert_fcinit1_03_p_np : assert property (p_InitFC1_triplet_correct_order_p_np)
        else `uvm_error("ASSERT_FCINIT1_03",
            "FCINIT1_03: InitFC1-P-NP did not follow CORRECT order")
	assert_fcinit1_03_np_cpl : assert property (p_InitFC1_triplet_correct_order_np_cpl)
        else `uvm_error("ASSERT_FCINIT1_03",
            "FCINIT1_03: InitFC1-NP-CPL did not follow CORRECT order")
	assert_fcinit1_03_cpl_p : assert property (p_InitFC1_triplet_correct_order_cpl_p)
        else `uvm_error("ASSERT_FCINIT1_03",
            "FCINIT1_03: InitFC1-CPL-P did not follow CORRECT order")


    cov_fcinit1_03_p_np: cover property (p_InitFC1_triplet_correct_order_p_np);
	cov_fcinit1_03_np_cpl: cover property (p_InitFC1_triplet_correct_order_np_cpl);
	cov_fcinit1_03_cpl_p: cover property (p_InitFC1_triplet_correct_order_cpl_p);

    // ============================================================
    // FCINIT1_08 : HdrScale/DataScale must be 00b in InitFC1 when Scaled FC NOT active
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
    // FCINIT1_09 : HdrScale/DataScale must be != 00b in InitFC1 when Scaled FC active
    // ============================================================
    property p_scale_nonzero_when_active_init1;
        @(posedge lclk) disable iff (reset)
        (state == DL_INIT1 && tx_is_initfc1  && scaled_fc_active)
        |-> (tx_hdr_scale != 2'b00 || tx_data_scale != 2'b00);
    endproperty

    ast_fcinit1_09: assert property (p_scale_nonzero_when_active_init1)
        else `uvm_error("ASSERT_FCINIT1_09",
            "FCINIT1_09: Scale fields are 00b when Scaled FC is active")

    cov_fcinit1_09: cover property (p_scale_nonzero_when_active_init1);

    // ============================================================
    // FCINIT1_10 : HdrFC and DataFC values correctly recorded from BOTH received InitFC1 AND InitFC2 DLLPs while in FC_INIT1
    // ============================================================

    // InitFC1_P or InitFC2_P received -> Posted credits recorded correctly
    property p_initfc_p_recorded;
        @(posedge lclk) disable iff (reset)
        (state == DL_INIT1 && (rx_is_initfc1_p || rx_is_initfc2_p) )
        |=> (fc_credits_register.hdr_credits[FC_POSTED] == $past(rx_dllp[37:30]) &&
             fc_credits_register.data_credits[FC_POSTED] == $past(rx_dllp[27:16]));
    endproperty

    // InitFC1_NP or InitFC2_NP received -> Non-Posted credits recorded correctly
    property p_initfc_np_recorded;
        @(posedge lclk) disable iff (reset)
        (state == DL_INIT1 && (rx_is_initfc1_np || rx_is_initfc2_np) )
        |=> (fc_credits_register.hdr_credits[FC_NON_POSTED] == $past(rx_dllp[37:30]) &&
             fc_credits_register.data_credits[FC_NON_POSTED] == $past(rx_dllp[27:16]));
    endproperty

    // InitFC1_CPL or InitFC2_CPL received -> Completion credits recorded correctly
    property p_initfc_cpl_recorded;
        @(posedge lclk) disable iff (reset)
        (state == DL_INIT1 && (rx_is_initfc1_cpl || rx_is_initfc2_cpl) )
        |=> (fc_credits_register.hdr_credits[FC_COMPLETION]== $past(rx_dllp[37:30]) &&
             fc_credits_register.data_credits[FC_COMPLETION] == $past(rx_dllp[27:16]));
    endproperty

    
    assert_fcinit1_10_fc_p:   assert property (p_initfc_p_recorded)
        else `uvm_error("ASSERT_FCINIT1_10", "FCINIT1_10: Posted credits not recorded from InitFC1-P || InitFC2-P ")
	cov_fcinit1_10_fc_p: cover property (p_initfc_p_recorded);

    assert_fcinit1_10_fc_np:  assert property (p_initfc_np_recorded)
        else `uvm_error("ASSERT_FCINIT1_10", "FCINIT1_10: Non-Posted credits not recorded from InitFC1-NP || InitFC2-NP")
	cov_fcinit1_10_fc_np: cover property (p_initfc_np_recorded);

    assert_fcinit1_10_fc_cpl: assert property (p_initfc_cpl_recorded)
        else `uvm_error("ASSERT_FCINIT1_10", "FCINIT1_10: Completion credits not recorded from InitFC1-CPL || InitFC2-CPL")
    cov_fcinit1_10_fc_cpl: cover property (p_initfc_cpl_recorded);
    // ============================================================
    // FCINIT1_11 : HdrScale/DataScale must be recorded if Scaled FC supported
    // ============================================================
    property p_scale_recorded_p;
        @(posedge lclk) disable iff (reset)
        (state == DL_INIT1 && (rx_is_initfc1_p || rx_is_initfc2_p ) && scaled_fc_active)
        |=> (fc_credits_register.hdr_scale [FC_POSTED] == $past(rx_dllp[39:38]) &&
             fc_credits_register.data_scale[FC_POSTED] == $past(rx_dllp[29:28]));
    endproperty

    property p_scale_recorded_np;
        @(posedge lclk) disable iff (reset)
        (state == DL_INIT1 && (rx_is_initfc1_np || rx_is_initfc2_np )&& scaled_fc_active)
        |=> (fc_credits_register.hdr_scale [FC_NON_POSTED] == $past(rx_dllp[39:38]) &&
             fc_credits_register.data_scale[FC_NON_POSTED] == $past(rx_dllp[29:28]));
    endproperty

    property p_scale_recorded_cpl;
        @(posedge lclk) disable iff (reset)
        (state == DL_INIT1 && (rx_is_initfc1_cpl || rx_is_initfc2_cpl)  && scaled_fc_active)
        |=> (fc_credits_register.hdr_scale [FC_COMPLETION] == $past(rx_dllp[39:38]) &&
             fc_credits_register.data_scale[FC_COMPLETION] == $past(rx_dllp[29:28]));
    endproperty

    assert_fcinit1_11_p:   assert property (p_scale_recorded_p)
        else `uvm_error("ASSERT_FCINIT1_11", "FCINIT1_11: Posted scale not recorded from InitFC1-P")
	cov_fcinit1_11_p: cover property (p_scale_recorded_p);

    assert_fcinit1_11_np:  assert property (p_scale_recorded_np)
        else `uvm_error("ASSERT_FCINIT1_11", "FCINIT1_11: Non-Posted scale not recorded from InitFC1-NP")
    cov_fcinit1_11_np: cover property (p_scale_recorded_np);

    assert_fcinit1_11_cpl: assert property (p_scale_recorded_cpl)
        else `uvm_error("ASSERT_FCINIT1_11", "FCINIT1_11: Completion scale not recorded from InitFC1-CPL")
    cov_fcinit1_11_cpl: cover property (p_scale_recorded_cpl);

    // ============================================================
    // FCINIT1_12 : FI1 flag set ONLY after ALL of P, NP, CPL received
    // ============================================================
    property p_fi1_set_after_P_NP_CPL_init1;
        @(posedge lclk) disable iff (reset || !pl_lnk_up)
        (state == DL_INIT1 && rx_is_initfc1_p)
        |-> ##[1:$] (state == DL_INIT1 && rx_is_initfc1_np) 
		|-> ##[1:$] (state == DL_INIT1 && rx_is_initfc1_cpl)
		|=> (fi1_flag)
    endproperty

	property p_fi1_set_after_P_NP_CPL_init2;
        @(posedge lclk) disable iff (reset || !pl_lnk_up)
        (state == DL_INIT1 && rx_is_initfc2_p)
        |-> ##[1:$] (state == DL_INIT1 && rx_is_initfc2_np) 
		|-> ##[1:$] (state == DL_INIT1 && rx_is_initfc2_cpl)
		|=> (fi1_flag)
    endproperty


    assert_fcinit1_12_initfc1: assert property (p_fi1_set_after_P_NP_CPL_init1)
        else `uvm_error("ASSERT_FCINIT1_12", "FCINIT1_12: FI1 not set after all three P+NP+CPL INIT1 received")
    cov_fcinit1_12_initfc1: cover property (p_fi1_set_after_P_NP_CPL_init1);
	assert_fcinit1_12_initfc2: assert property (p_fi1_set_after_P_NP_CPL_init2)
        else `uvm_error("ASSERT_FCINIT1_12", "FCINIT1_12: FI1 not set after all three P+NP+CPL INIT2 received")
    cov_fcinit1_12_initfc2: cover property (p_fi1_set_after_P_NP_CPL_init2);
    // ============================================================
    // TRANS_INIT1_01 : Exit FC_INIT1 -> FC_INIT2 when FI1=1 and LinkUp=1
    // ============================================================
    property p_trans_init1_to_init2_on_fi1;
        @(posedge lclk) disable iff (reset)
        (state == DL_INIT1 && fi1_flag == 1'b1 && pl_lnk_up == 1'b1)
        |=> (state == DL_INIT2);
    endproperty

    assert_trans_init1_01: assert property (p_trans_init1_to_init2_on_fi1)
        else `uvm_error("ASSERT_TRANS_INIT1_01",
            "TRANS_INIT1_01: Did not transition to DL_INIT2 when FI1=1 + LinkUp=1")

    cov_trans_init1_01: cover property (p_trans_init1_to_init2_on_fi1);

    // ============================================================
    // FCINIT2_03 : InitFC2 triplet must be transmitted in strict order P->NP->CPL
    // ============================================================
    
    property p_initfc2_P_NP_in_order;
        @(posedge lclk) disable iff (reset || !pl_lnk_up)
        (state == DL_INIT2 && tx_is_initfc2_p )
		// After P is sent, NP must come next
        |=> (state == DL_INIT2 && tx_is_initfc2_np);
    endproperty
	property p_initfc2_NP_CPL_in_order;
        @(posedge lclk) disable iff (reset || !pl_lnk_up)
        (state == DL_INIT2 && tx_is_initfc2_np )
		// After NP is sent, CPL must come next
		|=> (state == DL_INIT2 && tx_is_initfc2_cpl);
    endproperty
	property p_initfc2_CPL_P_in_order;
        @(posedge lclk) disable iff (reset || !pl_lnk_up)
        (state == DL_INIT2 && tx_is_initfc2_cpl )
		// After NP is sent, CPL must come next
		|=> (state == DL_INIT2 && tx_is_initfc2_p);
    endproperty

    assert_fcinit2_03_P_NP:  assert property (p_initfc2_P_NP_in_order)
        else `uvm_error("ASSERT_FCINIT2_03",
            "FCINIT2_03: InitFC2 triplet wrong order P_NP")

    cov_fcinit2_03_P_NP: cover property (p_initfc2_P_NP_in_order);

	assert_fcinit2_03_NP_CPL:  assert property (p_initfc2_NP_CPL_in_order)
        else `uvm_error("ASSERT_FCINIT2_03",
            "FCINIT2_03: InitFC2 triplet wrong order NP_CPL")
    cov_fcinit2_03_NP_CPL: cover property (p_initfc2_NP_CPL_in_order);

	assert_fcinit2_03_CPL_P:  assert property (p_initfc2_CPL_P_in_order)
        else `uvm_error("ASSERT_FCINIT2_03",
            "FCINIT2_03: InitFC2 triplet wrong order CPL_P")

    cov_fcinit2_03_CPL_P: cover property (p_initfc2_CPL_P_in_order);

    // ============================================================
    // FCINIT2_04 / FCINIT2_05 : In DL_INIT2 state, received InitFC1/InitFC2 values must be IGNORED
    // Credits and scales must NOT change
    // ============================================================

    property p_initfc1_2_ignored;
        @(posedge lclk) disable iff (reset)

        // Receiving InitFC1 or InitFC2 dllps in INIT2 state
        (state == DL_INIT2 && (rx_is_initfc1 || rx_is_initfc2))

        // Next cycle: values must remain unchanged
        |=> (// Header credits unchanged
            fc_credits_register.hdr_credits==
            $past(fc_credits_register.hdr_credits) &&
            // Data credits unchanged  
            fc_credits_register.data_credits ==
            $past(fc_credits_register.data_credits) &&
            // Header scale unchanged
            fc_credits_register.hdr_scale ==
            $past(fc_credits_register.hdr_scale) &&
            // Data scale unchanged
            fc_credits_register.data_scale ==
            $past(fc_credits_register.data_scale)
        );
    endproperty

    assert_fcinit2_04: assert property (p_initfc1_2_ignored)
        else `uvm_error("ASSERT_FCINIT2_04",
            "FCINIT2_04: Local FC credits / scale changed on received posted initfc ")

    cov_fcinit2_04: cover property (p_initfc1_2_ignored);

    // ============================================================
    // FCINIT2_06 : FI2 flag must be set on receipt of InitFC2 DLLP for VCx
    // ============================================================
    property p_fi2_set_on_initfc2;
        @(posedge lclk) disable iff (reset)
        (state == DL_INIT2 && rx_is_initfc2)
        |=> fi2_flag;
    endproperty

    assert_fcinit2_06: assert property (p_fi2_set_on_initfc2)
        else `uvm_error("ASSERT_FCINIT2_06",
            "FCINIT2_06: FI2 not set after InitFC2 triplet received")

    cov_fcinit2_06: cover property (p_fi2_set_on_initfc2);

    // ============================================================
    // FCINIT2_08 : FI2 flag must be set when UpdateFC received
    // ============================================================
    property p_fi2_set_on_updatefc;
        @(posedge lclk) disable iff (reset)
        (state == DL_INIT2  && rx_dllp[47:40] inside {UPDATEFC_P, UPDATEFC_NP, UPDATEFC_CPL} )
        |=> fi2_flag;
    endproperty

    assert_fcinit2_08: assert property (p_fi2_set_on_updatefc)
        else `uvm_error("ASSERT_FCINIT2_08",
            "FCINIT2_08: FI2 not set after UpdateFC transmitted before InitFC2 arrived")

    cov_fcinit2_08: cover property (p_fi2_set_on_updatefc);

    // ============================================================
    // FCINIT2_09 : HdrScale/DataScale must be 00b in InitFC2 when Scaled FC NOT active
    // ============================================================
    property p_scale_zero_when_not_active;
        @(posedge lclk) disable iff (reset)
        (state == DL_INIT2  && tx_is_initfc2  && !scaled_fc_active)
        |-> (tx_hdr_scale == 2'b00 && tx_data_scale == 2'b00);
    endproperty

    assert_fcinit2_09: assert property (p_scale_zero_when_not_active)
        else `uvm_error("ASSERT_FCINIT2_09",
            $sformatf("FCINIT2_09: Scale non-zero in InitFC2 when Scaled FC inactive. HdrScale=%0b DataScale=%0b",
                rx_hdr_scale, rx_data_scale))

    cov_fcinit2_09: cover property (p_scale_zero_when_not_active);

    // ============================================================
    // FCINIT2_10 : HdrScale/DataScale must be != 00b in InitFC2 when Scaled FC active
    // ============================================================
    property p_scale_nonzero_when_active_init2;
        @(posedge lclk) disable iff (reset) //tx or rx ??
        (state == DL_INIT2  && tx_is_initfc2  && scaled_fc_active)
        |-> (tx_hdr_scale != 2'b00 && tx_data_scale != 2'b00);
    endproperty

    assert_fcinit2_10: assert property (p_scale_nonzero_when_active_init2)
        else `uvm_error("ASSERT_FCINIT2_10",
            "FCINIT2_10: Scale fields are 00b in InitFC2 when Scaled FC is active")

    cov_fcinit2_10: cover property (p_scale_nonzero_when_active_init2);

    // ============================================================
    // FCINIT2_11 : UpdateFC DLLPs must use correct HdrScale/DataScale matching what advertised during init
	// when Scaled FC active
    // ============================================================
    property p_updatefc_scale_matches_init_p;
        @(posedge lclk) disable iff (reset)
        (state == DL_ACTIVE && tx_dllp[47:40] == UPDATEFC_P  && scaled_fc_active)
		//right ? state machine doesn't change this values and ref model also so they are the same as init
		// we inject error in dllp not in cfg 
		// we can inject error in the transmitted dllp such that the hdr/data scale is changed in the dllp from the cfg 
        |-> (tx_hdr_scale  == fc_credits_register.hdr_scale [FC_POSTED] &&
             tx_data_scale == fc_credits_register.data_scale[FC_POSTED]);
    endproperty

    property p_updatefc_scale_matches_init_np;
        @(posedge lclk) disable iff (reset)
        (state == DL_ACTIVE  && tx_dllp[47:40] == UPDATEFC_NP  && scaled_fc_active)
        |-> (tx_hdr_scale  == fc_credits_register.hdr_scale [FC_NON_POSTED] &&
             tx_data_scale == fc_credits_register.data_scale[FC_NON_POSTED]);
    endproperty

    property p_updatefc_scale_matches_init_cpl;
        @(posedge lclk) disable iff (reset)
        (state == DL_ACTIVE && tx_dllp[47:40] == UPDATEFC_CPL  && scaled_fc_active)
        |-> (tx_hdr_scale  == fc_credits_register.hdr_scale [FC_COMPLETION] &&
             tx_data_scale == fc_credits_register.data_scale[FC_COMPLETION]);
    endproperty

    assert_fcinit2_11_p:   assert property (p_updatefc_scale_matches_init_p)
        else `uvm_error("ASSERT_FCINIT2_11",
            "FCINIT2_11: UpdateFC-P scale mismatch with init advertisement")

    assert_fcinit2_11_np:  assert property (p_updatefc_scale_matches_init_np)
        else `uvm_error("ASSERT_FCINIT2_11",
            "FCINIT2_11: UpdateFC-NP scale mismatch with init advertisement")

    assert_fcinit2_11_cpl: assert property (p_updatefc_scale_matches_init_cpl)
        else `uvm_error("ASSERT_FCINIT2_11",
            "FCINIT2_11: UpdateFC-CPL scale mismatch with init advertisement")

    cov_fcinit2_11_p: cover property (p_updatefc_scale_matches_init_p);
    cov_fcinit2_11_np: cover property (p_updatefc_scale_matches_init_np);
	cov_fcinit2_11_cpl: cover property (p_updatefc_scale_matches_init_cpl);
    // ============================================================
    // TRANS_INIT2_01 : Exit FC_INIT2 -> DL_Active when FI2 set 
    // ============================================================
    property p_trans_init2_to_active;
        @(posedge lclk) disable iff (reset)
        (state    == DL_INIT2  && fi2_flag == 1'b1 && pl_lnk_up == 1'b1)
        |=> (state == DL_ACTIVE);
    endproperty

    assert_trans_init2_01: assert property (p_trans_init2_to_active)
        else `uvm_error("ASSERT_TRANS_INIT2_01",
            "TRANS_INIT2_01: Did not transition to DL_ACTIVE when FI2=1 + InitFC2 + LinkUp=1")

    cov_trans_init2_01: cover property (p_trans_init2_to_active);

    // ============================================================
    // LPIF Interface Assertions
    // ============================================================
    // When link is down, TX/RX DLLP must not carry valid values (should be UNKNOWN)
    property p_tx_rx_dllp_unknown_when_link_down;
        @(posedge lclk) disable iff (reset)
        (!pl_lnk_up) |-> ($isunknown(tx_dllp) && $isunknown(rx_dllp));
    endproperty

    assert property (p_tx_rx_dllp_unknown_when_link_down)
    else `uvm_error("ASSERT_LPIF_01",
    "LPIF_01: tx_dllp or rx_dllp is not UNKNOWN when pl_lnk_up is LOW");

    cover property (p_tx_rx_dllp_unknown_when_link_down);


    // When lp_valid is high, lp_data must be valid (no X/Z allowed)
    property p_lp_valid_data_known;
        @(posedge lclk) disable iff (reset)
        (lp_valid) |-> !$isunknown(lp_data);
    endproperty

    assert property (p_lp_valid_data_known)
    else `uvm_error("ASSERT_LPIF_02",
    "LPIF_02: lp_valid is HIGH but lp_data contains X/Z");

    cover property (p_lp_valid_data_known);


    // When reset is requested, reset must be asserted
    property p_reset_request_assert_reset;
        @(posedge lclk)
        (rst_req) |=> (reset);
    endproperty

    assert property (p_reset_request_assert_reset)
    else `uvm_error("ASSERT_LPIF_03",
    "LPIF_03: reset_req asserted but reset is NOT high");

    cover property (p_reset_request_assert_reset);


    // When pl_valid is high and link is up, rx_dllp must be valid 
    property p_rx_dllp_known_when_valid;
        @(posedge lclk) disable iff (reset || !pl_lnk_up)
        (pl_valid) |=> !$isunknown(rx_dllp);
    endproperty

    assert property (p_rx_dllp_known_when_valid)
    else `uvm_error("ASSERT_LPIF_04",
    "DLLP_LPIF_04: pl_valid = 1 but rx_dllp is unknown");

endinterface : passive_interface