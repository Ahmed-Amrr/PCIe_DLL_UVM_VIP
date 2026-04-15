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
    
    logic scaled_fc_active;

    dllp_type_t dllp_type;
    logic [1:0] tx_hdr_scale;
    logic [1:0] tx_data_scale;

    assign tx_hdr_scale  = tx_dllp[39:38];
    assign tx_data_scale = tx_dllp[29:28];


    covergroup cg_state_transitions @(posedge lclk);

    cp_state: coverpoint state {
        bins inactive  = {DL_INACTIVE};
        bins active    = {DL_ACTIVE};
        bins feature   = {DL_FEATURE};
        bins init1     = {DL_INIT1};
        bins init2   = {DL_INIT2};
    }

    cp_reset: coverpoint reset {
        bins reset_enabled  = {1'b1};
        bins reset_disabled = {1'b0};
    }

    cp_local_register_feature: coverpoint local_register_feature {
        bins reset_enabled  = {1'b1};
        bins reset_disabled = {1'b0};
    }

     // bit 31 — remote feature valid
    cp_remote_feature_valid: coverpoint dl_feature_status.remote_feature_valid {
        bins valid   = {1'b1};
        bins invalid = {1'b0};
    }

    // bits 30:23 — reserved, should always be zero
    cp_rsvdz: coverpoint dl_feature_status.rsvdz {
        bins zero    = {8'h00};
        illegal_bins non_zero = {[8'h01 : 8'hFF]}; 
    }

    // bits 22:0 — remote features 
    cp_remote_feature_supported: coverpoint dl_feature_status.remote_feature_supported {
        bins all_zeros     = {23'h000000};
    }

    cp_dl_down: coverpoint dl_down {
        bins dl_down_asserted   = {1'b1};
        bins dl_down_deasserted = {1'b0};
    }

    cp_inactive_entry_reset: cross cp_state, cp_reset {
        bins inactive_reset = binsof(cp_state.inactive) && binsof(cp_reset.reset_enabled);
    }

    cp_remote_feature_valid_cleared: cross cp_state, cp_reset, cp_remote_feature_valid {
        bins remote_feature_valid_cleared = binsof(cp_state.inactive) && binsof(cp_remote_feature_valid.invalid);
    }

    cp_dl_down_reported_inactive: cross cp_state, cp_dl_down {
        bins dl_down_inactive = binsof(cp_state.inactive) && binsof(cp_dl_down.dl_down_asserted);
    }

    cp_remote_feature_field_cleared: cross cp_state, cp_reset, cp_remote_feature_supported {
        bins remote_feature_supported_cleared = binsof(cp_state.inactive) && binsof(cp_remote_feature_supported.all_zeros);
    }
    endgroup

    
    // FEATURE Exchange Coverage
   
    covergroup cg_feature @(posedge clk);

        // FEATURE_04 : Transmitted Feature field must equal local register
        cp_tx_feature_field_matches_local: coverpoint
            (tx_dllp[38:16] == local_register_feature.local_feature_supported)
            iff (tx_dllp[47:40] == FEATURE)
        {
            bins feature_field_matches_local    = {1'b1};
            illegal_bins feature_field_mismatch_with_local = {1'b0};
        }

        // FEATURE_05 : Ack bit must equal remote_feature_valid
        // Must seen for both Valid=0 and Valid=1

        cp_ack_bit_matches_valid: coverpoint
            (tx_dllp[39] == remote_register_feature.remote_feature_valid)
            iff (tx_dllp[47:40] == FEATURE)
        {
            bins ack_equals_remote_valid    = {1'b1};
            illegal_bins ack_not_equal_remote_valid = {1'b0};
        }

        // Cover both 0 and 1
        cp_remote_valid_value: coverpoint
            remote_register_feature.remote_feature_valid
            iff (tx_dllp[47:40] == FEATURE)
        {
            bins valid_0 = {1'b0};
            bins valid_1 = {1'b1};
        }

        // Ack matched valid for both values of valid
        cp_ack_matches_both_valid_values: cross cp_ack_bit_matches_valid,
                                               cp_remote_valid_value;

        // FEATURE_06 : Remote DL Feature Supported field recorded on first valid Feature DLLP when Valid=Clear
        cp_remote_feature_recorded_first_dllp: coverpoint
            remote_register_feature.remote_feature_valid
            iff (rx_dllp[47:40] == FEATURE)
        {
            bins first_dllp_captured = {1'b0};   // Valid=0 when FEATURE DLLP arrived
            bins subsequent_dllp_captured    = {1'b1};   // Valid=1 — subsequent FEATURE DLLPs
        }

        // FEATURE_07 :  Remote DL Feature Supported Valid bit set after first valid Feature DLLP
        cp_remote_feature_valid_set: coverpoint
            remote_register_feature.remote_feature_valid
        {
            bins valid_0    = {1'b0};
            bins valid_1    = {1'b1};
            bins valid_rose = (1'b0 => 1'b1);   // transition bin
        }

        // FEATURE_08 : Remote DL Feature field NOT updated on subsequent Feature DLLPs when Valid already Set
        cp_remote_feature_no_update_after_valid: coverpoint
            (rx_dllp[38:16] != remote_register_feature.remote_feature_supported)
            iff (rx_dllp[47:40] == FEATURE &&
                 remote_register_feature.remote_feature_valid)
        {
            bins different_remote_feature_supp_value_seen = {1'b1};
        }

        // --------------------------------------------------------
        // FEATURE_11 : scaled_fc_active is activated ONLY when:
        //   feature_exchange_cap == 1 AND
        //   local_feature_supported[0]  == 1 AND
        //   remote_feature_supported[0] == 1
        // --------------------------------------------------------
        cp_feature_exchange_cap: coverpoint feature_exchange_cap {
            bins cap_supported     = {1'b1};
            bins cap_not_supported = {1'b0};
        }

        cp_local_scaled_fc: coverpoint
            local_register_feature.local_feature_supported[0]
        {
            bins local_set     = {1'b1};
            bins local_not_set = {1'b0};
        }

        cp_remote_scaled_fc: coverpoint
            remote_register_feature.remote_feature_supported[0]
        {
            bins remote_set     = {1'b1};
            bins remote_not_set = {1'b0};
        }

        cp_scaled_fc_active: coverpoint scaled_fc_active {
            bins active     = {1'b1};
            bins not_active = {1'b0};
        }

        cp_feature_activated_both_sides_only: cross cp_scaled_fc_active,
                                                    cp_feature_exchange_cap,
                                                    cp_local_scaled_fc,
                                                    cp_remote_scaled_fc
        {
            // all conditions met -> active
            bins all_set_active =
                binsof(cp_scaled_fc_active.active)            &&
                binsof(cp_feature_exchange_cap.cap_supported) &&
                binsof(cp_local_scaled_fc.local_set)          &&
                binsof(cp_remote_scaled_fc.remote_set);

            // cap not supported -> not active
            bins cap_not_supported_not_active =
                binsof(cp_scaled_fc_active.not_active)             &&
                binsof(cp_feature_exchange_cap.cap_not_supported);

            // local not set -> not active
            bins local_not_set_not_active =
                binsof(cp_scaled_fc_active.not_active)        &&
                binsof(cp_feature_exchange_cap.cap_supported) &&
                binsof(cp_local_scaled_fc.local_not_set);

            // remote not set -> not active
            bins remote_not_set_not_active =
                binsof(cp_scaled_fc_active.not_active)        &&
                binsof(cp_feature_exchange_cap.cap_supported) &&
                binsof(cp_remote_scaled_fc.remote_not_set);

            // Illegal: active without cap
            illegal_bins active_without_cap =
                binsof(cp_scaled_fc_active.active)                 &&
                binsof(cp_feature_exchange_cap.cap_not_supported);

            // Illegal: active without local bit set
            illegal_bins active_without_local =
                binsof(cp_scaled_fc_active.active)            &&
                binsof(cp_feature_exchange_cap.cap_supported) &&
                binsof(cp_local_scaled_fc.local_not_set);

            // Illegal: active without remote bit set
            illegal_bins active_without_remote =
                binsof(cp_scaled_fc_active.active)            &&
                binsof(cp_feature_exchange_cap.cap_supported) &&
                binsof(cp_remote_scaled_fc.remote_not_set);
        }

    endgroup : cg_feature

    
    // FEATURE State Transition Coverage
   
    covergroup cg_feature_transitions @(posedge clk);

        // transition bins for all feature state transitions 
        cp_state_transitions: coverpoint state {
            bins feature_to_init1    = (DL_FEATURE => DL_INIT1);    // TRANS_FEAT_01/02/03
            bins feature_to_inactive = (DL_FEATURE => DL_INACTIVE); // TRANS_FEAT_04/05
        }

        // TRANS_FEAT_01: Ack=1 caused the transition
        cp_ack_bit_rx: coverpoint rx_dllp[39]
            iff (state == DL_FEATURE)
        {
            bins ack_set     = {1'b1};
            bins ack_not_set = {1'b0};
        }

        // TRANS_FEAT_02: InitFC1 received caused the transition
        cp_initfc1_received: coverpoint
            (rx_dllp[47:40] inside {INITFC1_P, INITFC1_NP, INITFC1_CPL})
            iff (state == DL_FEATURE)
        {
            bins initfc1_seen = {1'b1};
            bins no_initfc1   = {1'b0};
        }

        // TRANS_FEAT_04/05: LinkUp dropped
        cp_linkup: coverpoint pl_lnk_up {
            bins link_up   = {1'b1};
            bins link_down = {1'b0};
        }

        // TRANS_FEAT_01: feature->init1 on Ack=1 + LinkUp=1
        cp_trans_feature_to_init_on_ack: cross cp_state_transitions,
                                              cp_ack_bit_rx,
                                              cp_linkup
        {
            bins trans_feat_01 =
                binsof(cp_state_transitions.feature_to_init1) &&
                binsof(cp_ack_bit_rx.ack_set)                 &&
                binsof(cp_linkup.link_up);
                
        // TRANS_FEAT_05: LinkUp dropped while Ack=1 received (feature-> inactive)
            bins trans_feat_05_ack =
                 binsof(cp_state_transitions.feature_to_inactive) &&
                 binsof(cp_ack_bit_rx.ack_set)                    &&
                 binsof(cp_linkup.link_down);
        // Illegal: must NEVER go to init1 when LinkUp=0 
            illegal_bins init1_with_linkdown_on_ack =
                 binsof(cp_state_transitions.feature_to_init1) &&
                 binsof(cp_ack_bit_rx.ack_set)                 &&
                 binsof(cp_linkup.link_down);
        }

        // TRANS_FEAT_02: feature->init1 on InitFC1 + LinkUp=1
        cp_trans_feature_to_init_on_initfc1: cross cp_state_transitions,
                                                  cp_initfc1_received,
                                                  cp_linkup
        {
            bins trans_feat_02 =
                 binsof(cp_state_transitions.feature_to_init1)   &&
                 binsof(cp_initfc1_received.initfc1_seen)         &&
                 binsof(cp_linkup.link_up);
        // TRANS_FEAT_05: LinkUp dropped when InitFC1 received -> inactive
             bins trans_feat_05_initfc1 =
                 binsof(cp_state_transitions.feature_to_inactive) &&
                 binsof(cp_initfc1_received.initfc1_seen)         &&
                 binsof(cp_linkup.link_down);
        // Illegal: must NEVER go to init1 when LinkUp=0 
            illegal_bins init1_with_linkdown_on_initfc1 =
                 binsof(cp_state_transitions.feature_to_init1)   &&
                 binsof(cp_initfc1_received.initfc1_seen)         &&
                 binsof(cp_linkup.link_down);
        }

        // TRANS_FEAT_04: feature->inactive on LinkUp=0
        cp_trans_feature_to_inactive_linkup_0: cross cp_state_transitions,
                                                    cp_linkup
        {
            bins trans_feat_04 =
                binsof(cp_state_transitions.feature_to_inactive) &&
                binsof(cp_linkup.link_down);
        }

        
    endgroup : cg_feature_transitions

    // FC_INIT1 Coverage

    covergroup cg_fc_init1 @(posedge lclk);

 cp_state: coverpoint state 
 {
        bins inactive  = {DL_INACTIVE};
        bins active    = {DL_ACTIVE};
        bins feature   = {DL_FEATURE};
        bins init1     = {DL_INIT1};
        bins init2     = {DL_INIT2};
 }
  // FCINIT1_02 — DL_Down reported during FC_INIT1
 
  cp_dl_down_in_fc_init1: coverpoint DL_Down iff (state == DL_INIT1) 
  {
    bins dl_down_asserted = {1'b1} ;
    illegal_bins wrong    = {1'b0};
  }

  // FCINIT1_03 — InitFC1 triplet transmitted in correct order P → NP → Cpl
  
  cp_initfc1_sequence_order: coverpoint dllp_type
      iff (state == DL_INIT1 && pl_valid) 
  {
      bins initfc1_seq = 
          (INITFC1_P => INITFC1_NP => INITFC1_CPL);
  }

  // FCINIT1_04 — TLP transmission blocked on VC0 during FC_INIT1

  // cp_vc0_tlp_blocked_fc_init1: coverpoint is_tlp_tx_vc0 iff (state == DL_INIT1) {
  //      bins blocked = {0}; // no TLP forwarded
  //  }
  // FCINIT1_05 — TLPs on other VCs NOT blocked during their FC_INIT1
  // FCINIT1_06 — Physical Layer transmissions not blocked
  // cp_phy_tx_not_blocked: coverpoint phy_tx_active {
  //  bins phy_passes = {1'b1} iff (fc_sub_state == FC_INIT1);
  // }
  // FCINIT1_07 — Ack/Nak DLLPs not blocked during FC_INIT1

  cp_ack_nak_not_blocked_fc_init1: coverpoint dllp_type
    iff (state == DL_INIT1 && pl_valid) 
  {

    bins ack_sent = {ACK};
    bins nak_sent = {NAK};
  }

  // FCINIT1_08 — HdrScale/DataScale = 00b when Scaled FC not active
 
  cp_initfc1_scale_00b: coverpoint {tx_hdr_scale, tx_data_scale}
    iff (state == DL_INIT1 && pl_valid &&
         (dllp_type inside {INITFC1_P, INITFC1_NP, INITFC1_CPL}) &&
         !scaled_fc_active)
  {

    bins scale_zero = {4'b0000};
    illegal_bins wrong_scale = default;
  }


  // FCINIT1_09 — HdrScale/DataScale != 00b when Scaled FC active

  cp_initfc1_scale_nonzero: coverpoint {tx_hdr_scale, tx_data_scale}
    iff (state == DL_INIT1 && pl_valid &&
         (dllp_type inside {INITFC1_P, INITFC1_NP, INITFC1_CPL}) && scaled_fc_active)
   {

    bins non_zero[] = {4'b0101, 4'b0110, 4'b0111,
                       4'b1001, 4'b1010, 4'b1011,
                       4'b1111, 4'b1101, 4'b1110}; // any non-zero combo
    illegal_bins wrong_scale = default;
   }


  
  // FCINIT1_10 — HdrFC/DataFC recorded from both InitFC1 and InitFC2 in FC_INIT1
  // FCINIT1_11 — HdrScale/DataScale recorded if Scaled FC supported
  // FCINIT1_12 — FI1 flag set ONLY after ALL of P, NP, Cpl received
  // TRANS_INIT1_01 — Exit FC_INIT1 → FC_INIT2 when FI1=1 and LinkUp=1
 
  cp_trans_fcinit1_to_fcinit2_on_fi1: coverpoint state {
    bins trans_to_fcinit2 = (FC_INIT1 => FC_INIT2) iff (fi1_flag  == 1'b1
                                                          && link_up == 1'b1);
  }

 
  // TRANS_INIT1_02 — Exit FC_INIT1 → DL_Inactive when LinkUp=0

  cp_trans_fcinit1_to_inactive_linkup_0: coverpoint state {
    bins trans_to_inactive_on_linkdown = (FC_INIT1 => DL_INACTIVE)
                                          iff (link_up == 1'b0);
  }

  // TRANS_INIT1_03 — LinkUp=0 takes priority over FI1 simultaneous assertion
  //it is redundant

  cp_trans_fcinit1_linkup_vs_fi1: coverpoint fc_sub_state {
    // Must go to DL_INACTIVE, NOT FC_INIT2, when both events coincide
    bins priority_inactive = (FC_INIT1 => DL_INACTIVE)
                              iff (link_up == 1'b0 && fi1_flag == 1'b1);

    // Illegal: must never advance to FC_INIT2 when LinkUp dropped simultaneously
    illegal_bins illegal_to_fcinit2 = (FC_INIT1 => FC_INIT2)
                                       iff (link_up == 1'b0);
  }

endgroup : cg_fc_init1
           
	       
endinterface : passive_interface