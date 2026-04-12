`ifndef PCIE_VIP_STATE_MACHINE
`define PCIE_VIP_STATE_MACHINE

class pcie_vip_state_machine extends uvm_component;

	parameter int DLLP_WIDTH    = 48;
    parameter int PAYLOAD_WIDTH = 32;
    parameter int CRC_WIDTH     = 16;
    parameter int BYTE 			= 8;

/*-------------------------------------------------------------------------------
-- UVM Factory register
-------------------------------------------------------------------------------*/
	// Provide implementations of virtual methods such as get_type_name and create
	`uvm_component_utils(pcie_vip_state_machine)

/*-------------------------------------------------------------------------------
-- Interface, port, fields
-------------------------------------------------------------------------------*/
	uvm_analysis_port #(pcie_state_seq_item) sm_ap; //sending data to the shared scoreboard and local scoreboard and sequencer
	pcie_state_seq_item state_seq_item;


	uvm_analysis_export #(pcie_dllp_seq_item) sm_export_tx;		//getting the data from tx monitor
	uvm_tlm_analysis_fifo #(pcie_dllp_seq_item) sm_fifo_tx;

	pcie_dllp_seq_item seq_item_tx;

	uvm_analysis_export #(pcie_dllp_seq_item) sm_export_rx;		//getting the data from rx monitor
	uvm_tlm_analysis_fifo #(pcie_dllp_seq_item) sm_fifo_rx;

	pcie_dllp_seq_item seq_item_rx;

	pcie_vip_config cfg;										//to get the configuration registers
	dl_state_t current_state, next_state;						//used for the FSM

	bit init1_p_f;
	bit init1_np_f;
	bit init1_cpl_f;								// these flags used for getting dllp with init type in order
	bit FI1;										//FI1 : initfc1 flag

	bit init2_p_f;
	bit init2_np_f;
	bit init2_cpl_f;
	bit FI2;										//FI1 : initfc2 flag
	//assign FI2 = init2_cpl_f;

	bit update_p_f;
	bit update_np_f;
	bit update_cpl_f;

	fc_type_t fc_type;								//P, NP, CPL.

	bit[PAYLOAD_WIDTH-1:0] received_dllp_payload;
	bit[CRC_WIDTH-1:0] received_crc;
	dllp_type_t received_type;		//ACK, NAK, INIT1_p ....... 

	bit[CRC_WIDTH-1:0] crc_expected;							//used in crc_checking

/*-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------*/
	// Constructor
	function new(string name = "pcie_vip_state_machine", uvm_component parent=null);
		super.new(name, parent);

		current_state = DL_INACTIVE;		//initialize states and flags
		FI1 = 0;
		FI2 = 0;
	endfunction : new

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// Get the configuration object to access the configuration registers
	    if(!uvm_config_db #(pcie_vip_config)::get(this,"","CFG_ENV",cfg))		//get configuration object from env
	      `uvm_fatal("build_phase","unable to get configuration object in SM")

	  	sm_export_tx=new("sm_export_tx",this);
		sm_fifo_tx=new("sm_fifo_tx",this);

		sm_export_rx=new("sm_export_rx",this);
		sm_fifo_rx=new("sm_fifo_rx",this);

	endfunction : build_phase

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		sm_export_tx.connect(sm_fifo_tx.analysis_export);
		sm_export_rx.connect(sm_fifo_rx.analysis_export);
	endfunction : connect_phase

	task run_phase(uvm_phase phase);
		super.run_phase(phase);
		forever begin
			// sm_fifo_tx.get(seq_item_tx);
			sm_fifo_rx.get(seq_item_rx);
			received_dllp_payload = seq_item_rx.dllp[DLLP_WIDTH-1:CRC_WIDTH];
			received_crc = seq_item_rx.dllp[CRC_WIDTH-1:0];
			get_type_sm(.received_rx(seq_item_rx.dllp), .type_rx(received_type));	//get type

			CRC_generation(received_dllp_payload,crc_expected);						//calculate the expected crc

			if (received_crc == crc_expected) begin 								//check on crc before state transition
				state_transition();
			end
		end
	endtask : run_phase

	function void get_type_sm;
		input bit [DLLP_WIDTH-1:0] received_rx;
		output dllp_type_t type_rx;

		bit [BYTE-1:0] type_;

		type_ = received_rx[DLLP_WIDTH-1:(DLLP_WIDTH-BYTE)];

		if (type_[7:4] inside {4'b0100, 4'b0101, 4'b0110, 4'b1100, 4'b1101, 4'b1110, 4'b1000, 4'b1001, 4'b1010}) begin
			type_[3:0] = 4'b0000;	//to force initfc_p, initfc_np ......
									//to consider only VC0. and disregard VC 1 2 3 ...
		end
		type_rx = dllp_type_t'(type_);
	endfunction : get_type_sm

	function void state_transition();
		case (current_state)
			DL_INACTIVE: begin 
				inactive_state();
			end
			DL_FEATURE: begin
				feature_state();
			end
			DL_INIT1: begin 
				init1_state();
			end
			DL_INIT2: begin 
				init2_state();
			end
			DL_ACTIVE: begin 
				active_state();
			end
			default :inactive_state();
		endcase
		current_state = next_state;
	endfunction : state_transition

	//Function for the Inactive state
	//checks for the required signals to exit from the inactive state
	function void inactive_state ();
		reset_conf_regs();								//resets configuration regesters
		if (seq_item_rx.reset) begin 					//requirs modeling for the reset logic
			next_state = DL_INACTIVE;
		end else 
		if (!seq_item_rx.pl_lnk_up) begin 				//comes from the LPIF
			next_state = DL_INACTIVE;
		end else if (cfg.local_register_feature.feature_exchange_enable & & cfg.feature_exchange_cap) begin
			next_state = DL_FEATURE;
		end begin
			next_state = DL_INIT1;			
		end
	endfunction : inactive_state

	function void feature_state ();
		if (seq_item_rx.reset) begin 					//requirs modeling for the reset logic
			next_state = DL_INACTIVE;
		end else 
		if (!seq_item_rx.pl_lnk_up) begin 				//comes from the LPIF
			next_state = DL_INACTIVE;
		end else if ((received_type == INITFC1_P) || (received_type == INITFC1_NP) || (received_type == INITFC1_CPL)) begin
			next_state = DL_INIT1;
		end else if ((received_type == DL_FEATURE) && (seq_item_rx.dllp[39] == 1)) begin
			next_state = DL_INIT1;
		end else begin 
			next_state = DL_FEATURE;
		end

		if ((received_type == DL_FEATURE) && (cfg.remote_register_feature.remote_feature_valid == 0)) begin
			cfg.remote_register_feature.remote_feature_valid = 1;
			cfg.remote_register_feature.remote_feature_supported = seq_item_rx.dllp[38:16];
		end
	endfunction : feature_state

	function void init1_state ();
		if (seq_item_rx.reset) begin 					//requirs modeling for the reset logic
			next_state = DL_INACTIVE;
		end else 
		if (!seq_item_rx.pl_lnk_up) begin 				//comes from the LPIF
			next_state = DL_INACTIVE;
		end else if (received_type == INITFC1_P) begin 	//raise init1_p_f
			init1_p_f = 1;
			init1_np_f = 0;
			init1_cpl_f = 0;

			fc_type = FC_POSTED;
			save_conf_scale_reg(fc_type);	//save configuration regs
			save_conf_credits_reg(fc_type);

			next_state = DL_INIT1;
		end else if ((received_type == INITFC1_NP) && init1_p_f) begin
			init1_p_f = 0;
			init1_np_f = 1;
			init1_cpl_f = 0;

			fc_type = FC_NON_POSTED;
			save_conf_scale_reg(fc_type);	//save configuration regs
			save_conf_credits_reg(fc_type);

			next_state = DL_INIT1;
		end else if ((received_type == INITFC1_CPL) && init1_np_f) begin
			init1_p_f = 0;
			init1_np_f = 0;
			init1_cpl_f = 1;

			fc_type = FC_COMPLETION;
			save_conf_scale_reg(fc_type);	//save configuration regs
			save_conf_credits_reg(fc_type);

			next_state = DL_INIT2;
		end else begin
			init1_p_f = 0;
			init1_np_f = 0;
			init1_cpl_f = 0;
			next_state = DL_INIT1;
		end
		FI1 = init1_cpl_f;	//Raise flag for initfc1
	endfunction : init1_state

	function void init2_state ();						//should be checking on regs and report error if exist
		if (seq_item_rx.reset) begin 					//requirs modeling for the reset logic
			next_state = DL_INACTIVE;
		end else 
		if (!seq_item_rx.pl_lnk_up) begin 				//comes from the LPIF
			next_state = DL_INACTIVE;
		end else if (received_type == INITFC2_P) begin
			init2_p_f = 1;
			init2_np_f = 0;
			init2_cpl_f = 0;

			fc_type = FC_POSTED;
			check_conf_scale_reg(fc_type);
			check_conf_credits_reg(fc_type);			

			next_state = DL_INIT2;
		end else if ((received_type == INITFC2_NP) && init2_p_f) begin
			init2_p_f = 0;
			init2_np_f = 1;
			init2_cpl_f = 0;

			fc_type = FC_NON_POSTED;
			check_conf_scale_reg(fc_type);
			check_conf_credits_reg(fc_type);			

			next_state = DL_INIT2;
		end else if ((received_type == INITFC2_CPL) && init2_np_f) begin
			init2_p_f = 0;
			init2_np_f = 0;
			init2_cpl_f = 1;

			fc_type = FC_COMPLETION;
			check_conf_scale_reg(fc_type);
			check_conf_credits_reg(fc_type);			

			next_state = DL_ACTIVE;
		end else begin
			init2_p_f = 0;
			init2_np_f = 0;
			init2_cpl_f = 0;
			next_state = DL_INIT2;
		end
		FI2 = init2_cpl_f;	//Raise flag for initfc2
	endfunction : init2_state

	function void active_state ();
		if (seq_item_rx.reset) begin 					//requirs modeling for the reset logic
			next_state = DL_INACTIVE;
		end else 
		if (!seq_item_rx.pl_lnk_up) begin 				//comes from the LPIF
			next_state = DL_INACTIVE;
		end else if (received_type == UPDATEFC_P) begin
			update_p_f = 1;
			update_np_f = 0;
			update_cpl_f = 0;

			fc_type = FC_POSTED;
			// check_conf_scale_reg(fc_type);
			save_conf_credits_reg(fc_type);

			next_state = DL_ACTIVE;
		end else if ((received_type == UPDATEFC_NP) && update_p_f) begin
			update_p_f = 0;
			update_np_f = 1;
			update_cpl_f = 0;

			fc_type = FC_NON_POSTED;
			// check_conf_scale_reg(fc_type);
			save_conf_credits_reg(fc_type);

			next_state = DL_ACTIVE;
		end else if ((received_type == UPDATEFC_CPL) && update_np_f) begin
			update_p_f = 0;
			update_np_f = 0;
			update_cpl_f = 1;

			fc_type = FC_COMPLETION;
			// check_conf_scale_reg(fc_type);
			save_conf_credits_reg(fc_type);

			next_state = DL_ACTIVE;
		end else begin
			update_p_f = 0;
			update_np_f = 0;
			update_cpl_f = 0;
			next_state = DL_ACTIVE;
		end
	endfunction : active_state

	function void reset_conf_regs();					//resets configuration regesters & Flags
		
		init1_p_f = 0;
		init1_np_f = 0;
		init1_cpl_f = 0;
		FI1 = 0;

		init2_p_f = 0;
		init2_np_f = 0;
		init2_cpl_f = 0;
		FI2 = 0;

		update_p_f = 0;
		update_np_f = 0;
		update_cpl_f = 0;

		for (int i = 0; i < 3; i++) begin
			cfg.fc_credits_register.hdr_scale[i] = 2'b00;
			cfg.fc_credits_register.hdr_credits[i] = {8{1'b0}};
			cfg.fc_credits_register.data_scale[i] = 2'b00;
			cfg.fc_credits_register.data_credits[i] = {12{1'b0}};
		end
	endfunction : reset_conf_regs

	function void save_conf_scale_reg(fc_type_t fc_type);	//saving configuration registers
		cfg.fc_credits_register.hdr_scale[fc_type] = seq_item_rx.dllp[39:38];
		cfg.fc_credits_register.data_scale[fc_type] = seq_item_rx.dllp[29:28];
	endfunction : save_conf_scale_reg

	function void save_conf_credits_reg(fc_type_t fc_type);	//saving configuration registers
		cfg.fc_credits_register.hdr_credits[fc_type] = seq_item_rx.dllp[37:30];
		cfg.fc_credits_register.data_credits[fc_type] = seq_item_rx.dllp[27:16];
	endfunction : save_conf_credits_reg

	function void check_conf_scale_reg(fc_type_t fc_type);	//check on configuration registers
		if(	(cfg.fc_credits_register.hdr_scale[fc_type]   != seq_item_rx.dllp[39:38]) ||
			(cfg.fc_credits_register.data_scale[fc_type]  != seq_item_rx.dllp[29:28])) begin
				
				`uvm_error("FC_init2 or FC_update scale doesn't match",
       			 $sformatf("unmatche_type: %s",fc_type))
			end
	endfunction : check_conf_scale_reg

	function void check_conf_credits_reg(fc_type_t fc_type);	//check on configuration registers
		if( (cfg.fc_credits_register.hdr_credits[fc_type] != seq_item_rx.dllp[37:30]) ||
			(cfg.fc_credits_register.data_credits[fc_type]!= seq_item_rx.dllp[27:16])) begin
				
				`uvm_error("FC_init2 credits doesn't match",
       			 $sformatf("unmatche_type: %s",fc_type))
			end
	endfunction : check_conf_credits_reg

	function void CRC_generation(input bit[PAYLOAD_WIDTH-1:0] dllp_before_crc,	//the default is {Byte 0, Byte 1, Byte 2, Byte 3}
							output bit[CRC_WIDTH-1:0] crc				//each byte (7,6,5,4,3,2,1,0)
	);

		bit [CRC_WIDTH-1:0]		crc_calc = 16'hFFFF;		//initial value
		bit	[PAYLOAD_WIDTH-1:0] dllp_before_crc_rearanged;	//rearrange each byte to be (0,1,2,3,4,5,6,7)
		bit [BYTE-1:0]			flipped_byte;				//used in the flipping loops
		bit 					feedback;					//get the last bit of the crc and add it to the input bit

	//flipping each byte in dllp_pkg as specified
		for (int i = 0; i < 4; i++) begin
			for (int j = 0; j < BYTE; j++) begin
				flipped_byte[7-j] = dllp_before_crc[(i*BYTE)+j];
			end
			dllp_before_crc_rearanged[(i*BYTE) +: BYTE] = flipped_byte;		//{Byte 0, Byte 1, Byte 2, Byte 3}
		end 																//each byte (0,1,2,3,4,5,6,7)
																			//[base +: width] (ai generated)
																			//because (msb:lsb) compile error
	//generating crc
		for (int k = 0; k < PAYLOAD_WIDTH; k++) begin
			feedback 	 =	dllp_before_crc_rearanged[PAYLOAD_WIDTH-k-1] ^ crc_calc[CRC_WIDTH-1];	//adding bit[15] with the input
			crc_calc	 =	{crc_calc[CRC_WIDTH-2:0] , feedback};			//shift and add feedback
			crc_calc[1]	 =	feedback ^ crc_calc[1];							//calculated using the polynomial 100Bh
			crc_calc[3]	 =	feedback ^ crc_calc[3];
			crc_calc[12] =	feedback ^ crc_calc[12];
		end

	//flipping each byte in crc as specified
		for (int i = 0; i < 2; i++) begin
			for (int j = 0; j < BYTE; j++) begin
				flipped_byte[7-j] = crc_calc[(i*BYTE)+j];
			end
			crc_calc[(i*BYTE) +: BYTE] = flipped_byte;	//{Byte 0, Byte 1} each byte (7,6,5,4,3,2,1,0)
		end 											//instead of (0,1,2,3,4,5,6,7)
	//inverse each bit to model the inverter in the crc
		crc = ~crc_calc;
	endfunction : CRC_generation

endclass : pcie_vip_state_machine

`endif