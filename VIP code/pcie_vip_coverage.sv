`ifndef PCIE_VIP_COVERAGE
`define PCIE_VIP_COVERAGE

class pcie_vip_coverage extends uvm_component;

/*-------------------------------------------------------------------------------
-- UVM Factory register
-------------------------------------------------------------------------------*/
	// Provide implementations of virtual methods such as get_type_name and create
	`uvm_component_utils(pcie_vip_coverage)

/*-------------------------------------------------------------------------------
-- Interface, port, fields
-------------------------------------------------------------------------------*/
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
/*-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------*/
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
		states_c : coverpoint state_seq_item.vip_state{
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
		FI2_c : coverpoint state_seq_item.FI2 {
			bins zero = {0};
			bins one = {1};
		}
		DL_Up_c : coverpoint state_seq_item.DL_Up {
			bins zero = {0};
			bins one = {1};
		}
		// cp_dl_up_in_fc_init2 : cross states_c.dl_init2_b, state_seq_item.DL_Up{
		// ignore_bins init = binsof(states_c.);
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
		// cp_trans_fcinit2_to_active_on_initfc2 : cross states_c.dl_init2_dl_active_t, FI2_c.one, DL_Up_c.one
		// //row 76 skipped (needs TLP)
		// //row 77 not sure
		// cp_trans_fcinit2_to_inactive_linkup_0 : cross states_c.dl_init2_dl_inactive_t, 

	endgroup : CovGp

endclass : pcie_vip_coverage

`endif