interface passive_interface (input logic clk);
    import dll_pkg::*;

	bit [47:0] tx_dllp;
	bit [47:0] rx_dllp;

	logic pl_valid;
	logic lp_valid;

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


	
endinterface : passive_interface