`ifndef PCIE_VIP_COVERAGE
`define PCIE_VIP_COVERAGE

class pcie_vip_coverage extends uvm_component;
	`uvm_component_utils(pcie_vip_coverage)


	uvm_analysis_export #(pcie_dllp_seq_item) cov_export_tx;		//getting the data from tx monitor
	uvm_tlm_analysis_fifo #(pcie_dllp_seq_item) cov_fifo_tx;

	pcie_dllp_seq_item seq_item_tx;

	uvm_analysis_export #(pcie_dllp_seq_item) cov_export_rx;		//getting the data from rx monitor
	uvm_tlm_analysis_fifo #(pcie_dllp_seq_item) cov_fifo_rx;

	pcie_dllp_seq_item seq_item_rx;

	uvm_analysis_export #(pcie_state_seq_item) cov_export_sm;     //getting the data from tx monitor
    uvm_tlm_analysis_fifo #(pcie_state_seq_item) cov_fifo_sm;

    pcie_state_seq_item state_seq_item;

	pcie_vip_config cfg;										//to get the configuration registers

	covergroup CovGp ();
	// State Coverage — all states and all legal transitions
		cp_state : coverpoint state_seq_item.vip_state{
			bins dl_inactive_b = {DL_INACTIVE};
			bins dl_feature_b = {DL_FEATURE};
			bins dl_init1_b = {DL_INIT1};
			bins dl_init2_b = {DL_INIT2};
			bins dl_active_b = {DL_ACTIVE};
			bins dl_inactive_dl_feature_t = (DL_INACTIVE => DL_FEATURE);
			bins dl_inactive_dl_init1_t = (DL_INACTIVE => DL_INIT1);
			bins dl_feature_dl_init1_t = (DL_FEATURE => DL_INIT1);
			bins dl_init1_dl_init2_t = (DL_INIT1 => DL_INIT2);
			bins dl_init2_dl_active_t = (DL_INIT2 => DL_ACTIVE);
			bins dl_feature_dl_inactive_t = (DL_FEATURE => DL_INACTIVE);
			bins dl_init1_dl_inactive_t = (DL_INIT1 => DL_INACTIVE);
			bins dl_init2_dl_inactive_t = (DL_INIT2 => DL_INACTIVE);
			bins dl_active_dl_inactive_t = (DL_ACTIVE => DL_INACTIVE);
		}
		// RX and TX DLLP type coverage
		rx_type_c : coverpoint seq_item_rx.dllp[47:40]{
			bins ACK_b             = {ACK};
        	bins NACK_b            = {NACK};
        	bins NOP_b             = {NOP};
        	bins VENDOR_SPECIFIC_b = {VENDOR_SPECIFIC};
        	bins FEATURE_b         = {FEATURE};
        	bins INITFC1_P_b       = {INITFC1_P};
        	bins INITFC1_NP_b      = {INITFC1_NP};
        	bins INITFC1_CPL_b     = {INITFC1_CPL};
        	bins INITFC2_P_b       = {INITFC2_P};
        	bins INITFC2_NP_b      = {INITFC2_NP};
        	bins INITFC2_CPL_b     = {INITFC2_CPL};
        	bins UPDATEFC_P_b      = {UPDATEFC_P};
        	bins UPDATEFC_NP_b     = {UPDATEFC_NP};
        	bins UPDATEFC_CPL_b    = {UPDATEFC_CPL};
		}
		tx_type_c : coverpoint seq_item_tx.dllp[47:40]{
			bins ACK_b             = {ACK};
        	bins NACK_b            = {NACK};
        	bins NOP_b             = {NOP};
        	bins VENDOR_SPECIFIC_b = {VENDOR_SPECIFIC};
        	bins FEATURE_b         = {FEATURE};
        	bins INITFC1_P_b       = {INITFC1_P};
        	bins INITFC1_NP_b      = {INITFC1_NP};
        	bins INITFC1_CPL_b     = {INITFC1_CPL};
        	bins INITFC2_P_b       = {INITFC2_P};
        	bins INITFC2_NP_b      = {INITFC2_NP};
        	bins INITFC2_CPL_b     = {INITFC2_CPL};
        	bins UPDATEFC_P_b      = {UPDATEFC_P};
        	bins UPDATEFC_NP_b     = {UPDATEFC_NP};
        	bins UPDATEFC_CPL_b    = {UPDATEFC_CPL};
		}
		// FI2 flag coverage
		FI2_c : coverpoint state_seq_item.FI2 {
			bins zero = {0};
			bins one = {1};
		}
		// FI1 flag coverage
		FI1_c : coverpoint state_seq_item.FI1 {
			bins zero = {0};
			bins one = {1};
		}
		// DL_Up / DL_Down status
		cp_dl_up : coverpoint {state_seq_item.DL_Up, state_seq_item.DL_Down} {
			bins dl_up   = {2'b10};
			bins dl_down = {2'b01};
		}
		 // LinkUp signal from RX item 
		cp_linkup: coverpoint seq_item_rx.pl_lnk_up {
            bins link_up   = {1'b1};
            bins link_down = {1'b0};
        }
		// Link not disabled from cfg
		cp_link_not_disable: coverpoint cfg.link_not_disabled {
			bins not_disabled = {1};
			bins disabled     = {0};
		}
		// reset from phy - come on rx_seq
		cp_multiple_resets : coverpoint cfg.reset {
			bins reset_asserted   = {1};
        	bins reset_deasserted = {0};	
			bins assert_reset     = (0 => 1);
            bins multiple_reset   = (0 => 1 => 1 => 1);
        }
		// Feature exchange capability and enable from cfg
		cp_feature_exchange_cap: coverpoint cfg.feature_exchange_cap {
            bins cap_supported     = {1};
            bins cap_not_supported = {0};
        }
		cp_feature_exchange_en: coverpoint cfg.local_register_feature.feature_exchange_enable {
			bins enabled  = {1};
            bins disabled = {0};
        }
		// Scaled FC local bit[0] from cfg
		cp_local_scaled_fc: coverpoint cfg.local_register_feature.local_feature_supported[0] {
            bins local_set     = {1};
            bins local_not_set = {0};
        }
       	// Scaled FC remote bit[0] from cfg
		cp_remote_scaled_fc: coverpoint cfg.remote_register_feature.remote_feature_supported[0] iff (cfg.remote_register_feature.remote_feature_valid == 1) {
            bins remote_set     = {1};
            bins remote_not_set = {0};
        }
	    // Scaled FC active from cfg
		cp_scaled_fc_active: coverpoint state_seq_item.scaled_fc_active {
            bins active     = {1};
            bins not_active = {0};
        }
		// Remote feature register fields from cfg
		cp_remote_feature_valid: coverpoint cfg.remote_register_feature.remote_feature_valid {
			bins valid   = {1};
			bins invalid = {0};
		}
		cp_remote_feature_supported: coverpoint cfg.remote_register_feature.remote_feature_supported {
			bins all_zeros     = {23'h000000};
			bins non_zero = default;
		}
        // DL_INACTIVE entry conditions
		cp_remote_feature_valid_cleared: cross cp_state, cp_remote_feature_valid {
			bins remote_feature_valid_cleared = binsof(cp_state.dl_inactive_b) && binsof(cp_remote_feature_valid.invalid);
			// Illegal: valid=1 while in DL_INACTIVE
            //////////////////illegal_bins valid_set_while_inactive = binsof(cp_state.dl_inactive_b) && binsof(cp_remote_feature_valid.valid);
            option.cross_auto_bin_max = 0;
        }

		cp_dl_down_reported_inactive: cross cp_state, cp_dl_up {
			bins dl_down_inactive = binsof(cp_state.dl_inactive_b) && binsof(cp_dl_up.dl_down);
			option.cross_auto_bin_max = 0;
		}

		cp_remote_feature_field_cleared: cross cp_state, cp_remote_feature_supported {
			bins remote_feature_supported_cleared = binsof(cp_state.dl_inactive_b) && binsof(cp_remote_feature_supported.all_zeros);
			// Illegal: non-zero feature field while inactive
            //illegal_bins field_set_while_inactive = binsof(cp_state.dl_inactive_b) && binsof(cp_remote_feature_supported.non_zero);
            option.cross_auto_bin_max = 0;
		}
		// Transition from INACTIVE to FEATURE — all conditions must be met
		cx_trans_inactive_to_feature_all_conditions : cross cp_state, cp_feature_exchange_cap, cp_feature_exchange_en, cp_link_not_disable, cp_linkup {
            bins TRANS_INACT = binsof(cp_state.dl_inactive_b) &&
							binsof(cp_feature_exchange_cap.cap_supported) &&
							binsof(cp_feature_exchange_en.enabled) &&
							binsof(cp_link_not_disable.not_disabled) &&
							binsof(cp_linkup.link_up);
			option.cross_auto_bin_max = 0;
        }

        // FEATURE_01: DL_Down reported during DL_FEATURE
		cp_dl_down_reported_feature: cross cp_state, cp_dl_up {
			bins dl_down_feature = binsof(cp_state.dl_feature_b) && binsof(cp_dl_up.dl_down);
			option.cross_auto_bin_max = 0;
		}
        // FEATURE_03 : While in DL_FEATURE, received DLLPs must be of type (FEATURE,INITFC1_P,INITFC1_NP,INITFC1_CPL)
        cp_feature_dllp_type: coverpoint seq_item_rx.dllp[47:40] iff (state_seq_item.vip_state == DL_FEATURE)
        {
           bins valid_dllp_in_feature = {FEATURE, INITFC1_P, INITFC1_NP, INITFC1_CPL};
        // Illegal: any other DLLP type shouldn't be received in DL_FEATURE
           //illegal_bins invalid_dllp_in_feature = default;
        }
		
		// FEATURE_04 : Transmitted Feature field must equal local register
        cp_tx_feature_field_matches_local: coverpoint (seq_item_tx.dllp[38:16] == cfg.local_register_feature.local_feature_supported) iff (state_seq_item.vip_state == FEATURE
		&& seq_item_tx.dllp[47:40] == FEATURE) {
            bins         feature_field_matches_local       = {1};
            illegal_bins feature_field_mismatch_with_local = {0};
        }

        // FEATURE_05 : Ack bit must equal remote_feature_valid
        cp_ack_bit_matches_valid: coverpoint (seq_item_rx.dllp[39] == cfg.remote_register_feature.remote_feature_valid) iff (state_seq_item.vip_state == FEATURE 
		&& seq_item_tx.dllp[47:40] == FEATURE){
            bins         ack_equals_remote_valid    = {1};
            ///////////illegal_bins ack_not_equal_remote_valid = {0};
        }
		// FEATURE_07 :  Remote DL Feature Supported Valid bit set after receiving Feature DLLP
        cp_remote_feature_valid_set: coverpoint cfg.remote_register_feature.remote_feature_valid iff (state_seq_item.vip_state == DL_FEATURE && seq_item_rx.dllp[47:40] == FEATURE) {
            bins valid_rose = (1'b0 => 1'b1);   // transition bin
			///////////illegal_bins invalid_trans = (1'b1 => 1'b0);
        }
        // FEATURE_11: scaled_fc_active ONLY when all three conditions met
        cp_feature_activated_both_sides_only: cross cp_scaled_fc_active,cp_feature_exchange_cap,cp_local_scaled_fc,cp_remote_scaled_fc
        {
            bins all_set_active =
                binsof(cp_scaled_fc_active.active)            &&
                binsof(cp_feature_exchange_cap.cap_supported) &&
                binsof(cp_local_scaled_fc.local_set)          &&
                binsof(cp_remote_scaled_fc.remote_set);

            bins cap_not_supported_not_active =
                binsof(cp_scaled_fc_active.not_active)        &&
                binsof(cp_feature_exchange_cap.cap_not_supported);

            bins local_not_set_not_active =
                binsof(cp_scaled_fc_active.not_active)        &&
                binsof(cp_feature_exchange_cap.cap_supported) &&
                binsof(cp_local_scaled_fc.local_not_set);

            bins remote_not_set_not_active =
                binsof(cp_scaled_fc_active.not_active)        &&
                binsof(cp_feature_exchange_cap.cap_supported) &&
                binsof(cp_remote_scaled_fc.remote_not_set);

            illegal_bins active_without_cap =
                binsof(cp_scaled_fc_active.active)            &&
                binsof(cp_feature_exchange_cap.cap_not_supported);

            illegal_bins active_without_local =
                binsof(cp_scaled_fc_active.active)            &&
                binsof(cp_feature_exchange_cap.cap_supported) &&
                binsof(cp_local_scaled_fc.local_not_set);

            illegal_bins active_without_remote =
                binsof(cp_scaled_fc_active.active)            &&
                binsof(cp_feature_exchange_cap.cap_supported) &&
                binsof(cp_remote_scaled_fc.remote_not_set);
            option.cross_auto_bin_max = 0;
        }

        // TRANS_FEAT_01 : Exit DL_Feature → DL_Init when Feature Exchange completes (Ack=Set) + LinkUp=1
		// TRANS_FEAT_02 : Exit DL_Feature → DL_Init on receipt of InitFC1 DLLP + LinkUp=1
        // Cause of feature->init1 transition coverpoints 
        cp_ack_bit_rx: coverpoint seq_item_rx.dllp[39]
            iff (state_seq_item.vip_state == DL_FEATURE && seq_item_rx.dllp[47:40] == FEATURE)
        {
            bins ack_set     = {1'b1};
            bins ack_not_set = {1'b0};
        }

        cp_initfc1_received: coverpoint
            (seq_item_rx.dllp[47:40] inside {INITFC1_P, INITFC1_NP, INITFC1_CPL})
            iff (state_seq_item.vip_state == DL_FEATURE)
        {
            bins initfc1_seen = {1'b1};
            bins no_initfc1   = {1'b0};
        }

        // TRANS_FEAT_01: feature->init1 on Ack=1 + LinkUp=1
        // TRANS_FEAT_05: LinkUp=0 + Ack=1 -> inactive
        cp_trans_feature_to_init_on_ack: cross cp_state, cp_ack_bit_rx, cp_linkup {
            bins trans_feat_01 =
                binsof(cp_state.dl_feature_dl_init1_t) &&
                binsof(cp_ack_bit_rx.ack_set)          &&
                binsof(cp_linkup.link_up);

            bins trans_feat_05_ack =
                binsof(cp_state.dl_feature_dl_inactive_t) &&
                binsof(cp_ack_bit_rx.ack_set)             &&
                binsof(cp_linkup.link_down);

            illegal_bins init1_with_linkdown_on_ack =
                binsof(cp_state.dl_feature_dl_init1_t) &&
                binsof(cp_ack_bit_rx.ack_set)          &&
                binsof(cp_linkup.link_down);
            option.cross_auto_bin_max = 0;
        }

        // TRANS_FEAT_02: feature->init1 on InitFC1 + LinkUp=1
        // TRANS_FEAT_05: LinkUp=0 + InitFC1 -> inactive
        cp_trans_feature_to_init_on_initfc1: cross cp_state, cp_initfc1_received, cp_linkup {
            bins trans_feat_02 =
                binsof(cp_state.dl_feature_dl_init1_t)    &&
                binsof(cp_initfc1_received.initfc1_seen)   &&
                binsof(cp_linkup.link_up);

            bins trans_feat_05_initfc1 =
                binsof(cp_state.dl_feature_dl_inactive_t) &&
                binsof(cp_initfc1_received.initfc1_seen)   &&
                binsof(cp_linkup.link_down);

            illegal_bins init1_with_linkdown_on_initfc1 =
                binsof(cp_state.dl_feature_dl_init1_t)    &&
                binsof(cp_initfc1_received.initfc1_seen)   &&
                binsof(cp_linkup.link_down);
            option.cross_auto_bin_max = 0;
        }

        // TRANS_FEAT_04: feature->inactive on LinkUp=0
        cp_trans_feature_to_inactive_linkup_0: cross cp_state, cp_linkup {
            bins trans_feat_04 =
                binsof(cp_state.dl_feature_dl_inactive_t) &&
                binsof(cp_linkup.link_down);
            option.cross_auto_bin_max = 0;
        }

	    // FCINIT1_02: DL_Down reported during FC_INIT1
		cp_dl_down_reported_fc_init1: cross cp_state, cp_dl_up {
			bins dl_down_fc_init1 = binsof(cp_state.dl_init1_b) && binsof(cp_dl_up.dl_down);
			option.cross_auto_bin_max = 0;
		}

        // FCINIT1_03: InitFC1 triplet order P->NP->CPL
        cp_initfc1_sequence_order: coverpoint seq_item_tx.dllp[47:40]
            iff (state_seq_item.vip_state == DL_INIT1)
        {
            bins initfc1_seq = (INITFC1_P => INITFC1_NP => INITFC1_CPL);
        }

        // FCINIT1_07: ACK/NACK not blocked during FC_INIT1
		// we don't send acks and nacks so it maybe not covered
        cp_ack_nak_not_blocked_fc_init1: coverpoint seq_item_tx.dllp[47:40]
            iff (state_seq_item.vip_state == DL_INIT1)
        {
            bins ack_sent  = {ACK};
            bins nack_sent = {NACK};
        }

        // FCINIT1_08: Scale=00b when Scaled FC not active
        cp_initfc1_scale_00b: coverpoint
            {seq_item_tx.dllp[39:38], seq_item_tx.dllp[29:28]}
            iff (state_seq_item.vip_state == DL_INIT1 &&
                 seq_item_tx.dllp[47:40] inside {INITFC1_P, INITFC1_NP, INITFC1_CPL} &&
                 !state_seq_item.scaled_fc_active)
        {
            bins scale_zero = {4'b0000};
            /////////////illegal_bins wrong_scale = default;
        }

        // FCINIT1_09: Scale!=00b when Scaled FC active
        cp_initfc1_scale_nonzero: coverpoint
            {seq_item_tx.dllp[39:38], seq_item_tx.dllp[29:28]}
            iff (state_seq_item.vip_state == DL_INIT1 &&
                 seq_item_tx.dllp[47:40] inside {INITFC1_P, INITFC1_NP, INITFC1_CPL} &&
                 state_seq_item.scaled_fc_active)
        {
            bins non_zero[] = {4'b0101, 4'b0110, 4'b0111,
                               4'b1001, 4'b1010, 4'b1011,
                               4'b1111, 4'b1101, 4'b1110};
            //illegal_bins wrong_scale = default;
        }

        // TRANS_INIT1_01: FC_INIT1->FC_INIT2 when FI1=1 + LinkUp=1
        cp_trans_fcinit1_to_fcinit2_on_fi1: cross cp_state, FI1_c, cp_linkup {
            bins trans_init1_01 =
                binsof(cp_state.dl_init1_dl_init2_t) &&
                binsof(FI1_c.one)                    &&
                binsof(cp_linkup.link_up);
            option.cross_auto_bin_max = 0;
        }

        // TRANS_INIT1_02: FC_INIT1->DL_Inactive when LinkUp=0
        cp_trans_fcinit1_to_inactive_linkup_0: cross cp_state, cp_linkup {
            bins trans_init1_02 =
                binsof(cp_state.dl_init1_dl_inactive_t) &&
                binsof(cp_linkup.link_down);
            option.cross_auto_bin_max = 0;
        }

        // FCINIT2_01
		cp_dl_up_in_fc_init2 : cross cp_state, cp_dl_up{
			bins init2_DL_up = binsof(cp_state.dl_init2_b) && binsof(cp_dl_up.dl_up);
			option.cross_auto_bin_max = 0;
		}

		// FCINIT2_03
		cp_initfc2_sequence_order : coverpoint seq_item_rx.dllp[47:40] iff(state_seq_item.vip_state == DL_INIT2) {
			bins seq_order_P_NP_CPL = (INITFC2_P => INITFC2_NP => INITFC2_CPL);
		}

		// FCINIT2_03 (For TX)
		cp_initfc2_sequence_order_TX : coverpoint seq_item_tx.dllp[47:40] iff(state_seq_item.vip_state == DL_INIT2) {
			bins seq_order_P_NP_CPL = (INITFC2_P => INITFC2_NP => INITFC2_CPL);
		}

		// FCINIT2_06
		cp_fi2_set_on_initfc2 : cross cp_initfc2_sequence_order, FI2_c{
			bins right_seq_Fl2 = binsof(cp_initfc2_sequence_order.seq_order_P_NP_CPL) && binsof(FI2_c.one);
			illegal_bins right_seq_no_Fl2 = binsof(cp_initfc2_sequence_order.seq_order_P_NP_CPL) && binsof(FI2_c.zero);
			option.cross_auto_bin_max = 0;
		}

		// TRANS_INIT2_01
		cp_trans_fcinit2_to_active_on_initfc2 : cross cp_state, FI2_c, cp_dl_up{
			bins in2_active_Fl2_up = binsof(cp_state.dl_init2_dl_active_t) && binsof(FI2_c.one) && binsof(cp_dl_up.dl_up);
			option.cross_auto_bin_max = 0;
		}

		// TRANS_INIT2_03
		cp_trans_fcinit2_to_active_on_updatefc : cross cp_state, FI2_c, rx_type_c{
			bins in2_active_Fl2_update = binsof(cp_state.dl_init2_dl_active_t) && binsof(FI2_c.one) &&
										(binsof(rx_type_c.UPDATEFC_P_b)  ||
										 binsof(rx_type_c.UPDATEFC_NP_b) ||
										 binsof(rx_type_c.UPDATEFC_CPL_b));
			option.cross_auto_bin_max = 0;
		}

		// TRANS_INIT2_04
		cp_trans_fcinit2_to_inactive_linkup_0 : cross cp_state, cp_dl_up{
			bins in2_inactive_down = binsof(cp_state.dl_init2_dl_inactive_t) && binsof(cp_dl_up.dl_down);
			option.cross_auto_bin_max = 0;
		}

	endgroup : CovGp

		// Constructor
	function new(string name = "pcie_vip_coverage", uvm_component parent=null);
		super.new(name, parent);
				// Get the configuration object to access the configuration registers
	    if(!uvm_config_db #(pcie_vip_config)::get(this,"","CFG_ENV",cfg))
	      `uvm_fatal("build_phase","unable to get configuration object in cov")

		CovGp = new();
	endfunction : new

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

	  	cov_export_tx=new("cov_export_tx",this);
		cov_fifo_tx=new("cov_fifo_tx",this);

		cov_export_rx=new("cov_export_rx",this);
		cov_fifo_rx=new("cov_fifo_rx",this);

		cov_export_sm=new("cov_export_sm",this);
		cov_fifo_sm=new("cov_fifo_sm",this);

	endfunction : build_phase

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		cov_export_tx.connect(cov_fifo_tx.analysis_export);
		cov_export_rx.connect(cov_fifo_rx.analysis_export);
		cov_export_sm.connect(cov_fifo_sm.analysis_export);
	endfunction : connect_phase

	task run_phase(uvm_phase phase);
		super.run_phase(phase);
		forever begin
			cov_fifo_tx.get(seq_item_tx);
			cov_fifo_rx.get(seq_item_rx);
			cov_fifo_sm.get(state_seq_item);
			CovGp.sample();
		end
	endtask : run_phase


endclass : pcie_vip_coverage

`endif
