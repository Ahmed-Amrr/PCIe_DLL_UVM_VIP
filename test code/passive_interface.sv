interface passive_interface (input logic clk);

    // Data Link Layer state machine states
    typedef enum { 
        DL_INACTIVE,
        DL_FEATURE,
        DL_INIT1,
        DL_INIT2,
        DL_ACTIVE
    } dl_state_t;
  
    // DLLP Types
    typedef enum logic [7:0] { 
        // Acknowledgement 
        ACK             = 8'b0000_0000,
        NACK            = 8'b0001_0000,
        // Misc
        NOP             = 8'b0011_0001,
        VENDOR_SPECIFIC = 8'b0011_0000,
        FEATURE         = 8'b0000_0010,
        // Flow-control initialisation
        INITFC1_P       = 8'b0100_0000,   // VC bits [2:0] are masked
        INITFC1_NP      = 8'b0101_0000,
        INITFC1_CPL     = 8'b0110_0000,
        INITFC2_P       = 8'b1100_0000,
        INITFC2_NP      = 8'b1101_0000,
        INITFC2_CPL     = 8'b1110_0000,
        // Flow-control update
        UPDATEFC_P      = 8'b1000_0000,
        UPDATEFC_NP     = 8'b1001_0000,
        UPDATEFC_CPL    = 8'b1010_0000
    } dllp_type_t;

    //  fc_type_t
    //  Posted / Non-Posted / Completion – used to index credit arrays
    typedef enum {
        FC_POSTED,
        FC_NON_POSTED,
        FC_COMPLETION
    } fc_type_t;

    typedef struct packed {
        logic [7:0]  [2:0] hdr_credits;   // [FC_POSTED], [FC_NON_POSTED], [FC_COMPLETION]
        logic [11:0] [2:0] data_credits;
        logic [1:0]  [2:0] hdr_scale;
        logic [1:0]  [2:0] data_scale;
    } fc_credits_t;

    typedef struct packed {
        logic        feature_exchange_enable;   // bit 31
        logic [7:0]  rsvdp;                      // bits 30:23
        logic [22:0] local_feature_supported;   // bits 22:0
    } dl_feature_cap_reg_t;

   typedef struct packed {
        logic        remote_feature_valid;      // bit 31
        logic [7:0]  rsvdz;                      // bits 30:23
        logic [22:0] remote_feature_supported;  // bits 22:0
    } dl_feature_status_reg_t;

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
	logic pl_valid;

	logic reset;

	logic DL_Up;
	logic DL_Down;

	logic surprise_down_capable;
	logic link_not_disabled;
	logic surprise_down_event;


	
endinterface : passive_interface