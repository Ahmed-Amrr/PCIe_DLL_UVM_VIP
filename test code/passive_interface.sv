interface passive_interface (input logic clk);
    import dll_pkg::*;

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

	logic DL_Up;
	logic DL_Down;

	logic surprise_down_capable;
	logic link_not_disabled;
	logic surprise_down_event;


	// PROPERTIES
	// check remote feature signals are cleared one cycle after reset
	property p_reset_clears_remote_feature;
		@(posedge lclk)
		(reset == 1) |=>
		(dl_feature_status.remote_feature_valid    == 0 &&
		dl_feature_status.remote_feature_supported == 0);
	endproperty

	// LINK_STATUS must be DL_UP when state is DL_ACTIVE or FC_INIT2
	property p_link_up_in_active_states;
		@(posedge lclk) disable iff (reset)
		(state == DL_ACTIVE || state == FC_INIT2) |->
		(DL_Up == 1'b1 && DL_Down == 1'b0);
	endproperty

	// LINK_STATUS must be DL_DOWN when state is DL_INACTIVE, DL_FEATURE, or FC_INIT1
	property p_link_down_in_inactive_states;
		@(posedge lclk) disable iff (reset)
		(state inside {DL_INACTIVE, DL_FEATURE, FC_INIT1}) |->
		(DL_Down == 1'b1 && DL_Up == 1'b0);
	endproperty

	// when pl_link_up is low → state must be INACTIVE
	property p_link_down_state_inactive;
		@(posedge clk) disable iff (reset)
		(!pl_lnk_up) |->
		(state == DL_INACTIVE);
	endproperty

	// when pl_link_up is high → state must be FEATURE, INIT, or ACTIVE
	property p_link_up_state_valid;
		@(posedge clk) disable iff (reset)
		(pl_lnk_up) |->
		(state inside {DL_FEATURE, DL_INIT1, DL_INIT2, DL_ACTIVE});
	endproperty

	// if pl_link_up drops in any active state → must go to DL_INACTIVE next cycle
	property p_link_drop_goes_inactive;
		@(posedge clk)
		(state inside {DL_FEATURE, DL_INIT1, DL_INIT2, DL_ACTIVE} && !pl_lnk_up) |=>
		(state == DL_INACTIVE);
	endproperty

	// from INACTIVE, state can only transition to FEATURE or INIT
	property p_inactive_next_state;
		@(posedge lclk)
		($past(state) == DL_INACTIVE && state != DL_INACTIVE) |->
		(state inside {DL_FEATURE, DL_INIT1});
	endproperty

	// from FEATURE, state can only transition to INIT1 or INACTIVE
	property p_feature_next_state;
		@(posedge lclk)
		($past(state) == DL_FEATURE && state != DL_FEATURE) |->
		(state inside {DL_INIT1, DL_INACTIVE});
	endproperty

	// from INIT2, state can only transition to ACTIVE or INACTIVE
	property p_fc_init_next_state;
		@(posedge lclk)
		($past(state) == DL_INIT2 && state != DL_INIT2) |->
		(state inside {DL_ACTIVE, DL_INACTIVE});
	endproperty

	// ASSERTIONS
	assert property (p_reset_clears_remote_feature)
		else `uvm_error("ASSERT_FAIL", "Remote feature signals not cleared after reset");

	assert property (p_link_up_in_active_states)
		else `uvm_error("ASSERT_FAIL", "LINK_STATUS should be DL_UP in DL_ACTIVE or FC_INIT2");

	assert property (p_link_down_in_inactive_states)
		else `uvm_error("ASSERT_FAIL", "LINK_STATUS should be DL_DOWN in DL_INACTIVE, DL_FEATURE, or FC_INIT1");

	assert property (p_link_down_state_inactive)
		else `uvm_error("ASSERT_FAIL", "State must be DL_INACTIVE when pl_link_up is low");

	assert property (p_link_up_state_valid)
		else `uvm_error("ASSERT_FAIL", "State must be DL_FEATURE/DL_INIT1/DL_INIT2/DL_ACTIVE when pl_link_up is high");

	assert property (p_link_drop_goes_inactive)
		else `uvm_error("ASSERT_FAIL", "State did not transition to DL_INACTIVE after pl_link_up drop");

	assert property (p_inactive_next_state)
		else `uvm_error("ASSERT_FAIL", "Invalid state transition from DL_INACTIVE");

	assert property (p_feature_next_state)
		else `uvm_error("ASSERT_FAIL", "Invalid state transition from DL_FEATURE");

	assert property (p_fc_init_next_state)
		else `uvm_error("ASSERT_FAIL", "Invalid state transition from DL_INIT2");



	// COVER POINTS
	// cover: reset occurred and remote feature signals were cleared next cycle
	cover property (p_reset_clears_remote_feature);

	// cover: DL_UP seen while in DL_ACTIVE or FC_INIT2
	cover property (p_link_up_in_active_states);

	// cover: DL_DOWN seen while in DL_INACTIVE, DL_FEATURE, or FC_INIT1
	cover property (p_link_down_in_inactive_states);

	// cover: pl_link_up low and state was DL_INACTIVE
	cover property (p_link_down_state_inactive);

	// cover: pl_link_up high and state was FEATURE/INIT/ACTIVE
	cover property (p_link_up_state_valid);

	// cover: pl_link_up dropped in active state and went to DL_INACTIVE
	cover property (p_link_drop_goes_inactive);

	// cover: valid transition out of DL_INACTIVE
	cover property (p_inactive_next_state);

	// cover: valid transition out of DL_FEATURE
	cover property (p_feature_next_state);

	// cover: valid transition out of DL_INIT2
	cover property (p_fc_init_next_state);
endinterface : passive_interface