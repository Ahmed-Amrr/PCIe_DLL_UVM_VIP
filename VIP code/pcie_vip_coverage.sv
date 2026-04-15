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


	// Constructor
	function new(string name = "pcie_vip_coverage", uvm_component parent=null);
		super.new(name, parent);
		CovGp=new();
	endfunction : new

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// Get the configuration object to access the configuration registers
	    if(!uvm_config_db #(pcie_vip_config)::get(this,"","CFG_ENV",cfg))
	      `uvm_fatal("build_phase","unable to get configuration object in cov")

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

	covergroup CovGp ();
		cp_state : coverpoint state_seq_item.vip_state{
			bins dl_inactive_b = DL_INACTIVE;
			bins dl_feature_b = DL_FEATURE;
			bins dl_init1_b = DL_INIT1;
			bins dl_init2_b = DL_INIT2;
			bins dl_active_b = DL_ACTIVE;
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
		rx_type_c : coverpoint seq_item_rx.dllp[47:40]{
			bins ACK_b             = ACK;
        	bins NACK_b            = NACK;
        	bins NOP_b             = NOP;
        	bins VENDOR_SPECIFIC_b = VENDOR_SPECIFIC;
        	bins FEATURE_b         = FEATURE;
        	bins INITFC1_P_b       = INITFC1_P;
        	bins INITFC1_NP_b      = INITFC1_NP;
        	bins INITFC1_CPL_b     = INITFC1_CPL;
        	bins INITFC2_P_b       = INITFC2_P;
        	bins INITFC2_NP_b      = INITFC2_NP;
        	bins INITFC2_CPL_b     = INITFC2_CPL;
        	bins UPDATEFC_P_b      = UPDATEFC_P;
        	bins UPDATEFC_NP_b     = UPDATEFC_NP;
        	bins UPDATEFC_CPL_b    = UPDATEFC_CPL;
		}
		tx_type_c : coverpoint seq_item_tx.dllp[47:40]{
			bins ACK_b             = ACK;
        	bins NACK_b            = NACK;
        	bins NOP_b             = NOP;
        	bins VENDOR_SPECIFIC_b = VENDOR_SPECIFIC;
        	bins FEATURE_b         = FEATURE;
        	bins INITFC1_P_b       = INITFC1_P;
        	bins INITFC1_NP_b      = INITFC1_NP;
        	bins INITFC1_CPL_b     = INITFC1_CPL;
        	bins INITFC2_P_b       = INITFC2_P;
        	bins INITFC2_NP_b      = INITFC2_NP;
        	bins INITFC2_CPL_b     = INITFC2_CPL;
        	bins UPDATEFC_P_b      = UPDATEFC_P;
        	bins UPDATEFC_NP_b     = UPDATEFC_NP;
        	bins UPDATEFC_CPL_b    = UPDATEFC_CPL;
		}
		FI2_c : coverpoint state_seq_item.FI2 {
			bins zero = {0};
			bins one = {1};
		}
		cp_dl_up : coverpoint {state_seq_item.DL_Up, state_seq_item.DL_Down} {
			bins dl_up   = {2'b10};
			bins dl_down = {2'b01};
		}
		cp_linkup: coverpoint seq_item_rx.pl_lnk_up {
            bins link_up   = {1'b1};
            bins link_down = {1'b0};
        }
		cp_link_not_disable: coverpoint cfg.link_not_disabled {
			bins not_disabled = {1};
			bins disabled     = {0};
		}
		// el reset hena gaya mn el phi sah? rx or tx transaction?
		cp_multiple_resets : coverpoint seq_item_rx.reset {
			bins reset_asserted   = {1};
        	bins reset_deasserted = {0};	
			bins assert_reset     = {0 => 1};
            bins multiple_reset   = {0 => 1 => 1 => 1};
        }
		cp_feature_exchange_cap: coverpoint cfg.feature_exchange_cap {
            bins cap_supported     = {1};
            bins cap_not_supported = {0};
        }
		cp_feature_exchange_en: coverpoint cfg.local_register_feature.feature_exchange_enable {
			bins enabled  = {1};
            bins disabled = {0};
        }
		cp_local_scaled_fc: coverpoint cfg.local_register_feature.local_feature_supported[0] {
            bins local_set     = {1};
            bins local_not_set = {0};
        }
		cp_remote_scaled_fc: coverpoint cfg.remote_register_feature.remote_feature_supported[0] iff (remote_register_feature.remote_feature_valid == 1) {
            bins remote_set     = {1};
            bins remote_not_set = {0};
        }
		cp_remote_feature_valid: coverpoint cfg.remote_register_feature.remote_feature_valid {
			bins valid   = {1};
			bins invalid = {0};
		}
		cp_remote_feature_supported: coverpoint cfg.remote_register_feature.remote_feature_supported {
			bins all_zeros     = {23'h000000};
		}

		cp_remote_feature_valid_cleared: cross cp_state, cp_remote_feature_valid {
			bins remote_feature_valid_cleared = binsof(cp_state.dl_inactive_b) && binsof(cp_remote_feature_valid.invalid);
		}

		cp_dl_down_reported_inactive: cross cp_state, cp_dl_up {
			bins dl_down_inactive = binsof(cp_state.dl_inactive_b) && binsof(cp_dl_up.dl_down);
		}

		cp_remote_feature_field_cleared: cross cp_state, cp_remote_feature_supported {
			bins remote_feature_supported_cleared = binsof(cp_state.dl_inactive_b) && binsof(cp_remote_feature_supported.all_zeros);
		}
		
		cx_trans_inactive_to_feature_all_conditions : cross cp_state, cp_feature_exchange_cap, cp_feature_exchange_en, cp_link_not_disable, cp_linkup {
            bins TRANS_INACT = binsof(cp_state.dl_inactive_b) &&
							binsof(cp_feature_exchange_cap.cap_supported) &&
							binsof(cp_feature_exchange_en.enabled) &&
							binsof(cp_link_not_disable.not_disabled) &&
							binsof(cp_linkup.link_up);
        }

		// I think we don't need to do so, we already check them in fer model?
		// FEATURE_04 : Transmitted Feature field must equal local register
        cp_tx_feature_field_matches_local: coverpoint (seq_item_tx.dllp[38:16] == cfg.local_register_feature.local_feature_supported) iff (state_seq_item.vip_state == FEATURE) {
            bins         feature_field_matches_local       = {1};
            illegal_bins feature_field_mismatch_with_local = {0};
        }

        // FEATURE_05 : Ack bit must equal remote_feature_valid
        cp_ack_bit_matches_valid: coverpoint (seq_item_rx.dllp[39] == cfg.remote_register_feature.remote_feature_valid) iff (state_seq_item.vip_state == FEATURE){
            bins         ack_equals_remote_valid    = {1};
            illegal_bins ack_not_equal_remote_valid = {0};
        }
		// FEATURE_07 :  Remote DL Feature Supported Valid bit set after receiving Feature DLLP
        cp_remote_feature_valid_set: coverpoint cfg.remote_register_feature.remote_feature_valid iff (state_seq_item.vip_state == DL_FEATURE && seq_item_rx.dllp[47:40] == FEATURE) {
            bins valid_rose = (1'b0 => 1'b1);   // transition bin
			illegal_bins invalid_trans = (1'b1 => 1'b0);
        }


		// cp_dl_up_in_fc_init2 : cross cp_state.dl_init2_b, state_seq_item.DL_Up{
		// ignore_bins init = binsof(cp_state.);
		// }
		// //row 65 skipped (needs TLP)
		// cp_initfc1_sequence_order : coverpoint rx_type_c iff(state_seq_item.vip_state==DL_FEATURE){
		// 	bins seq_order = (binsof(rx_type_c.INITFC2_P_b) => binsof(rx_type_c.INITFC2_NP_b) => binsof(rx_type_c.INITFC2_CPL_b));
		// } 
		// //row 67 & 68
		// cp_fi2_set_on_initfc2 : cross cp_initfc1_sequence_order.seq_order, FI2_c.one
		// //row 70 skipped (needs TLP)
		// //row 71 is it valid???
		// //rows 72 & 73 needs assertions?
		// //row 74///////////////
		// cp_trans_fcinit2_to_active_on_initfc2 : cross cp_state.dl_init2_dl_active_t, FI2_c.one, DL_Up_c.one
		// //row 76 skipped (needs TLP)
		// //row 77 not sure
		// cp_trans_fcinit2_to_inactive_linkup_0 : cross cp_state.dl_init2_dl_inactive_t, 

	endgroup : CovGp

endclass : pcie_vip_coverage

`endif