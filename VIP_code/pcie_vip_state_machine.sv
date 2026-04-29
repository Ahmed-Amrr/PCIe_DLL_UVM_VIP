`ifndef PCIE_VIP_STATE_MACHINE
`define PCIE_VIP_STATE_MACHINE

class pcie_vip_state_machine extends uvm_component;

	parameter int DLLP_WIDTH    = 48;
	parameter int PAYLOAD_WIDTH = 32;
	parameter int CRC_WIDTH     = 16;
	parameter int BYTE 			= 8;
	parameter int PAYLOAD_IN_BYTES = PAYLOAD_WIDTH / BYTE;  //Equals 4

/*-------------------------------------------------------------------------------
-- UVM Factory register
-------------------------------------------------------------------------------*/
	// Provide implementations of virtual methods such as get_type_name and create
	`uvm_component_utils(pcie_vip_state_machine)

/*-------------------------------------------------------------------------------
-- Interface, port, fields
-------------------------------------------------------------------------------*/

	pcie_vip_config 		cfg;									//To get the configuration registers

/*------------------Ports------------------*/
	uvm_analysis_port 		#(pcie_state_seq_item) sm_ap; 			//Sending data to the shared scoreboard and local scoreboard and sequencer

	uvm_analysis_export 	#(pcie_dllp_seq_item) sm_export_tx;		//Getting the data from tx monitor
	uvm_tlm_analysis_fifo 	#(pcie_dllp_seq_item) sm_fifo_tx;


	uvm_analysis_export 	#(pcie_dllp_seq_item) sm_export_rx;		//Getting the data from rx monitor
	uvm_tlm_analysis_fifo 	#(pcie_dllp_seq_item) sm_fifo_rx;

/*------------------Items------------------*/

	pcie_state_seq_item 	state_seq_item;							//Holds the state and control signals
	pcie_dllp_seq_item 		seq_item_tx;							//Transmited item
	pcie_dllp_seq_item 		seq_item_rx;							//Received item

/*------------------Flags------------------*/
	//These flags used for getting DLLP with INITFC1 type in order
	bit init1_p_f;				//Posetd
	bit init1_np_f;				//Non-Posted
	bit init1_cpl_f;			//Compeletion							
	bit FI1;					//FI1 : INITFC1 flag

	//These flags used for getting DLLP with INITFC2 type in order
	bit init2_p_f;				//Posetd
	bit init2_np_f;				//Non-Posted
	bit init2_cpl_f;			//Compeletion
	bit FI2;					//FI1 : initfc2 flag

	//These flags used for getting DLLP with UPDATE type in order
	bit update_p_f;				//Posetd
	bit update_np_f;			//Non-Posted
	bit update_cpl_f;			//Compeletion

	bit scaled_fc_cfg_done;		//Used for generating the scaled FC registers
	bit illegal_type_bit;		//Check the legallity of received DLLP depending on the state

/*------------------Signals------------------*/
	bit 	[PAYLOAD_WIDTH-1:0] received_dllp_payload;
	bit 	[CRC_WIDTH-1:0] 	received_crc;
	bit 	[CRC_WIDTH-1:0] 	crc_expected;			//used in crc_checking

	
	logic 						DL_Up;
	logic 						DL_Down;
	logic 						surprise_down_event;
	
	fc_type_t 					fc_type;				//P, NP, CPL.
	dllp_type_t 				received_type;			//ACK, NAK, INIT1_p ....... 

	dl_state_t 					current_state;			//Used for the FSM
	dl_state_t 					next_state;				
	dl_state_t 					prev_state;				//for reporting the transitions between states

	int 						count = 2;
/*-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------*/

	// Constructor
	function new(string name = "pcie_vip_state_machine", uvm_component parent=null);
		super.new(name, parent);

		//initialize states and flags
		current_state = DL_INACTIVE;		
		FI1 = 0;
		FI2 = 0;
		illegal_type_bit = 0;
		scaled_fc_cfg_done = 0;
	endfunction : new


	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// Get the configuration object from env to access the configuration registers
	    if(!uvm_config_db #(pcie_vip_config)::get(this,"","CFG_ENV",cfg))
	      `uvm_fatal("build_phase","unable to get configuration object in SM")

	  	sm_export_tx = new("sm_export_tx",this);
		sm_fifo_tx 	 = new("sm_fifo_tx",this);

		sm_export_rx = new("sm_export_rx",this);
		sm_fifo_rx 	 = new("sm_fifo_rx",this);

		sm_ap = new("sm_ap",this);
	endfunction : build_phase


	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		sm_export_tx.connect(sm_fifo_tx.analysis_export);
		sm_export_rx.connect(sm_fifo_rx.analysis_export);
	endfunction : connect_phase


	task run_phase(uvm_phase phase);
		super.run_phase(phase);

		forever begin
			state_seq_item = pcie_state_seq_item::type_id::create("state_seq_item");
			sm_fifo_rx.get(seq_item_rx);

			`uvm_info("SM_DEBUG",$sformatf(
				"SM_IN pkt_id=%0d t=%0t dllp=0x%012h top=0x%02h state=%s pl_lnk_up=%0b reset=%0b",
				seq_item_rx.pkt_id,
				$time,
			    seq_item_rx.dllp,
			    seq_item_rx.dllp[47:40],
			    current_state.name(),
			    seq_item_rx.pl_lnk_up,
			    cfg.reset), UVM_HIGH)

			//Getting the DLLP and the CRC for checking
			received_dllp_payload = seq_item_rx.dllp[DLLP_WIDTH-1:CRC_WIDTH];
			received_crc = seq_item_rx.dllp[CRC_WIDTH-1:0];

			get_type_sm(.received_rx(seq_item_rx.dllp), .type_rx(received_type));			//Get type
			CRC_generation(.dllp_before_crc(received_dllp_payload), .crc(crc_expected));	//Calculate the expected crc

			//State transition from INACTIVE doesn't depend on CRC
			if ((received_crc == crc_expected) || (current_state == DL_INACTIVE)) begin 	//Check on crc before state transition
				type_legal_check(.current_state_r(current_state), .type_rx_r(received_type), .illegal_type_r(illegal_type_bit));	//Check the legallity
				prev_state = current_state;	
				
				state_transition();						//The FSM logic

                if (prev_state != current_state) begin 	//check on transitions
                    `uvm_info("STATE_TRANS", $sformatf("Transition: %s -> %s", prev_state, current_state), UVM_MEDIUM)
                end
			end else begin
				`uvm_error("State_Machine rx_crc error (Illegal DLLP received)",
       			$sformatf("received crc is : 0x%h, expected crc : 0x%h, state: %s",received_crc, crc_expected, current_state))
			end

			configure_scaled_fc_once();		//If Scaled FC is active, configure the registers once per reset.
			save_seq_item(state_seq_item);	//Store the state values in the state-seq-item
			sm_ap.write(state_seq_item);
		end
	endtask : run_phase

/*-----------------------------FSM-Functions-----------------------------*/

    // Function: state_transition
    // Processes the DLLP and decides our next state (FSM)
	function void state_transition;
		case (current_state)
			DL_INACTIVE	:	inactive_state();
			DL_FEATURE	: 	feature_state();
			DL_INIT1	:  	init1_state();
			DL_INIT2	:	init2_state();
			DL_ACTIVE 	:  	active_state();

			default 	:	inactive_state();
		endcase

		current_state = next_state;
	endfunction : state_transition


    // Function: inactive_state
	// Checks for the required signals to exit from the inactive state
	function void inactive_state;
		reset_conf_regs();		//resets configuration registers

		if (cfg.reset || !cfg.link_not_disabled) begin
			next_state = DL_INACTIVE;
			`uvm_info("SM_STATUS", "asserted reset", UVM_MEDIUM)
		end else if (!seq_item_rx.pl_lnk_up) begin 					//comes from the LPIF
			next_state = DL_INACTIVE;
			`uvm_info("SM_STATUS", "Waiting for Physical Layer (pl_lnk_up)", UVM_HIGH)
		end else if (cfg.local_register_feature.feature_exchange_enable && cfg.feature_exchange_cap) begin
			next_state = DL_FEATURE;	//If the link supports feature exchange
		end else begin
			next_state = DL_INIT1;			
		end
	endfunction : inactive_state


    // Function: feature_state
	// Checks for the required signals to exit from the feature state
	function void feature_state;

		if (cfg.reset) begin 
			next_state = DL_INACTIVE;
			`uvm_info("SM_STATUS", "asserted reset", UVM_MEDIUM)
		end else if (!seq_item_rx.pl_lnk_up) begin
			next_state = DL_INACTIVE;
			`uvm_info("SM_STATUS", "Waiting for Physical Layer (pl_lnk_up)", UVM_HIGH)
		end else if (received_type == INITFC1_P && seq_item_rx.pl_valid) begin
			//If we received DLLP INITFC1 then the remote link doesn't support feature exchange
			next_state = DL_INIT1;
		end else if (((received_type == FEATURE) && (seq_item_rx.dllp[39] == 1)) && seq_item_rx.pl_valid) begin
			//If we received ACK bit 1, this means the remote link received our feature DLLP
			next_state = DL_INIT1;
		end else begin 
			next_state = DL_FEATURE;
		end

		//For the first received feature DLLP, store the values in the register
		if (((received_type == FEATURE) && (cfg.remote_register_feature.remote_feature_valid == 0)) && seq_item_rx.pl_valid) begin
			cfg.remote_register_feature.remote_feature_valid = 1;
			cfg.remote_register_feature.remote_feature_supported = seq_item_rx.dllp[38:16];
		end
	endfunction : feature_state


    // Function: init1_state
	// Checks for the required signals to exit from the INITFC1 state
	function void init1_state;
		if (cfg.reset) begin
			next_state = DL_INACTIVE;
			`uvm_info("SM_STATUS", "asserted reset", UVM_MEDIUM)
		end else 
		if (!seq_item_rx.pl_lnk_up) begin
			next_state = DL_INACTIVE;
			`uvm_info("SM_STATUS", "Waiting for Physical Layer (pl_lnk_up)", UVM_HIGH)
		end else if (received_type == INITFC1_P && seq_item_rx.pl_valid) begin
			init1_p_f 	= 1;	//First in order
			init1_np_f 	= 0;
			init1_cpl_f = 0;

			//To store the scale and creadits received (POSTED)
			fc_type = FC_POSTED;
			save_conf_scale_reg(fc_type);
			save_conf_credits_reg(fc_type);

			next_state = DL_INIT1;
		end else if ((received_type == INITFC1_NP) && init1_p_f && seq_item_rx.pl_valid) begin
			init1_p_f 	= 0;
			init1_np_f 	= 1;	//Second in order
			init1_cpl_f = 0;

			//To store the scale and creadits received (NON-POSTED)
			fc_type = FC_NON_POSTED;
			save_conf_scale_reg(fc_type);
			save_conf_credits_reg(fc_type);

			next_state = DL_INIT1;
		end else if ((received_type == INITFC1_CPL) && init1_np_f && seq_item_rx.pl_valid) begin
			init1_p_f 	= 0;
			init1_np_f 	= 0;
			init1_cpl_f = 1;	//Third in order

			//To store the scale and creadits received (COMPELETION)
			fc_type = FC_COMPLETION;
			save_conf_scale_reg(fc_type);
			save_conf_credits_reg(fc_type);

			next_state = DL_INIT2;
		end else begin
			//In case the sequence was wrong, start from the beginning
			init1_p_f = 0;
			init1_np_f = 0;
			init1_cpl_f = 0;
			next_state = DL_INIT1;
		end
		FI1 = init1_cpl_f;	//Raise flag for initfc1
	endfunction : init1_state


    // Function: init2_state
	// Checks for the required signals to exit from the INITFC2 state and the expected registered values
	function void init2_state;
		if (cfg.reset) begin
			next_state = DL_INACTIVE;
			`uvm_info("SM_STATUS", "asserted reset", UVM_MEDIUM)
		end else if (!seq_item_rx.pl_lnk_up) begin
			next_state = DL_INACTIVE;
			`uvm_info("SM_STATUS", "Waiting for Physical Layer (pl_lnk_up)", UVM_HIGH)
		end else if (received_type == UPDATEFC_P && seq_item_rx.pl_valid) begin
			//If received any update in initefc_2 raise Fl2 and next state is Active
			init2_p_f 	= 0;
			init2_np_f 	= 0;
			init2_cpl_f = 1;

			next_state 	= DL_INIT2;
		end else if (received_type == INITFC2_P && seq_item_rx.pl_valid) begin
			init2_p_f 	= 1;	//First in order
			init2_np_f 	= 0;
			init2_cpl_f = 0;

			//Checks if the DLLP has the correct scale and credits values
			fc_type 	= FC_POSTED;
			check_conf_scale_reg(fc_type);
			check_conf_credits_reg(fc_type);

			next_state = DL_INIT2;
		end else if ((received_type == INITFC2_NP) && init2_p_f && seq_item_rx.pl_valid) begin
			init2_p_f 	= 0;
			init2_np_f 	= 1;	//Second in order
			init2_cpl_f = 0;

			//Checks if the DLLP has the correct scale and credits values
			fc_type 	= FC_NON_POSTED;
			check_conf_scale_reg(fc_type);
			check_conf_credits_reg(fc_type);

			next_state = DL_INIT2;
		end else if ((received_type == INITFC2_CPL) && init2_np_f && seq_item_rx.pl_valid) begin
			init2_p_f 	= 0;
			init2_np_f 	= 0;
			init2_cpl_f = 1;	//Third in order

			//Checks if the DLLP has the correct scale and credits values
			fc_type = FC_COMPLETION;
			check_conf_scale_reg(fc_type);
			check_conf_credits_reg(fc_type);

			next_state = DL_ACTIVE;
		end else begin
			//In case the sequence was wrong, start from the beginning
			init2_p_f = 0;
			init2_np_f = 0;
			init2_cpl_f = 0;
			next_state = DL_INIT2;
		end
		FI2 = init2_cpl_f; //Raise flag for initfc2
	endfunction : init2_state


    // Function: active_state
	// Checks for the signals that can change the state to inactive and checks for the expected registered values
	function void active_state;
		if (cfg.reset) begin
			next_state = DL_INACTIVE;
			`uvm_info("SM_STATUS", "asserted reset", UVM_MEDIUM)
		end else if (!(seq_item_rx.pl_lnk_up)) begin
			surprise_down_event = 1;
			next_state = DL_INACTIVE;
			`uvm_info("SM_STATUS", "Waiting for Physical Layer (pl_lnk_up)", UVM_HIGH)
		end else if (received_type == UPDATEFC_P && seq_item_rx.pl_valid) begin
			update_p_f 	= 1;	//First in order
			update_np_f = 0;
			update_cpl_f= 0;

			//Save the updated credits
			fc_type 	= FC_POSTED;
			save_conf_credits_reg(fc_type);

			next_state = DL_ACTIVE;
		end else if ((received_type == UPDATEFC_NP) && update_p_f && seq_item_rx.pl_valid) begin
			update_p_f 	= 0;
			update_np_f = 1;	//Second in order
			update_cpl_f= 0;

			//Save the updated credits
			fc_type 	= FC_NON_POSTED;
			save_conf_credits_reg(fc_type);

			next_state = DL_ACTIVE;
		end else if ((received_type == UPDATEFC_CPL) && update_np_f && seq_item_rx.pl_valid) begin
			update_p_f 	= 0;
			update_np_f = 0;
			update_cpl_f= 1;

			//Save the updated credits
			fc_type 	= FC_COMPLETION;
			save_conf_credits_reg(fc_type);

			next_state = DL_ACTIVE;
		end else begin
			//In case the sequence was wrong, start from the beginning
			update_p_f 	= 0;
			update_np_f = 0;
			update_cpl_f= 0;
			next_state 	= DL_ACTIVE;
		end
	endfunction : active_state

/*-----------------------------User-Functions-----------------------------*/


    // Function: get_type_sm
    // Inputs  : the full dllp
    // Outputs : the type of the dllp
    // gets the type of the dllp and forces only VC0 to be active
	function void get_type_sm;
		input 	logic [DLLP_WIDTH-1:0] 	received_rx;	//The received DLLP
		output 	dllp_type_t 			type_rx;		//The type of the DLLP

		logic 	[BYTE-1:0] 				type_;

		type_ = received_rx[DLLP_WIDTH-1:(DLLP_WIDTH-BYTE)];	//Stores the first byte holding the type

		if (type_[7:4] inside {4'b0100, 4'b0101, 4'b0110, 4'b1100, 4'b1101, 4'b1110, 4'b1000, 4'b1001, 4'b1010}) begin
			type_[3:0] = 4'b0000;	//to force initfc_p, initfc_np ......
									//to consider only VC0. and disregard VC 1 2 3 ...
		end
		type_rx = dllp_type_t'(type_);
	endfunction : get_type_sm


    // Function: type_legal_check
    // Inputs  : The current state, and the received DLLP type
    // Outputs : Flag for the legallity of the DLLP
    // If the receive type is illegal depending on the current state raise the flag
	function void type_legal_check;
		input 	dl_state_t  	current_state_r;
		input 	dllp_type_t 	type_rx_r;
		output 	bit 			illegal_type_r;

		illegal_type_r = 0;
		if (!$isunknown(type_rx_r) ) begin 	//To ensure that tha type has a value
			case (current_state)
				DL_INACTIVE: begin
					illegal_type_r = 1;	//We can't receive DLLP in inactive state
				 end
			    DL_FEATURE: begin
					if(!(type_rx_r inside {FEATURE,INITFC1_P,INITFC1_NP,INITFC1_CPL})) begin
						illegal_type_r = 1;
						`uvm_info("State_Machine rx_type error (Illegal DLLP receiving in state DL_FEATURE)",
							$sformatf("received type is : %s",type_rx_r), UVM_LOW)
					end
				end
			    DL_INIT1: begin
					if(!(type_rx_r inside {FEATURE, INITFC1_P, INITFC1_NP, INITFC1_CPL, INITFC2_P, INITFC2_NP, INITFC2_CPL})) begin
						illegal_type_r = 1;
						`uvm_info("State_Machine rx_type error (Illegal DLLP receiving in state DL_INIT1)",
							$sformatf("received type is : %s",type_rx_r), UVM_LOW)
					end
				end
			    DL_INIT2: begin
					if(type_rx_r inside {FEATURE, ACK, NACK}) begin
						illegal_type_r = 1;
						`uvm_info("State_Machine rx_type error (Illegal DLLP receiving in state DL_INIT2)",
							$sformatf("received type is : %s",type_rx_r), UVM_LOW)
					end
				end
			    DL_ACTIVE: begin
					if(type_rx_r == FEATURE) begin
						illegal_type_r = 1;
						`uvm_info("State_Machine rx_type error (Illegal DLLP receiving in state DL_ACTIVE)",
							$sformatf("received type is : %s",type_rx_r), UVM_LOW)
					end
				end
			endcase	
		end
	endfunction : type_legal_check


    // Function: reset_conf_regs
    // Reset all configurations, registers and flags
	function void reset_conf_regs;
		init1_p_f 	= 0;
		init1_np_f 	= 0;
		init1_cpl_f = 0;
		FI1 		= 0;

		init2_p_f 	= 0;
		init2_np_f 	= 0;
		init2_cpl_f = 0;
		FI2 		= 0;

		update_p_f 	= 0;
		update_np_f = 0;
		update_cpl_f= 0;

		surprise_down_event = 0;
		scaled_fc_cfg_done 	= 0;
		cfg.scaled_fc_active= 0;

		cfg.local_fc_credits_register.hdr_scale  = '0;
		cfg.local_fc_credits_register.data_scale = '0;

		cfg.remote_register_feature.remote_feature_valid 	= 0;
		cfg.remote_register_feature.remote_feature_supported= 0;

		 for (int i = 0; i < 3; i++) begin
			cfg.remote_fc_credits_register.hdr_scale[i] 	= 2'b00;
			cfg.remote_fc_credits_register.hdr_credits[i] 	= {8{1'b0}};
			cfg.remote_fc_credits_register.data_scale[i] 	= 2'b00;
			cfg.remote_fc_credits_register.data_credits[i] 	= {12{1'b0}};
		end
	endfunction : reset_conf_regs


    // Function: configure_scaled_fc_once
    // Generate the values stored in the local FC Scale register one time per reset
	function void configure_scaled_fc_once;
		if (scaled_fc_cfg_done || (cfg.remote_register_feature.remote_feature_valid == 0)) begin
			//If the registers are generated once we exit the funtions
			return;
		end

		if (cfg.remote_register_feature.remote_feature_supported[0] & cfg.local_register_feature.local_feature_supported[0]) begin
			cfg.scaled_fc_active = 1;	//Both local and remote links support scaled fc
			cfg.local_fc_credits_register.hdr_scale[0] 	= $urandom_range(1,3);
			cfg.local_fc_credits_register.hdr_scale[1] 	= $urandom_range(1,3);
			cfg.local_fc_credits_register.hdr_scale[2] 	= $urandom_range(1,3);
			cfg.local_fc_credits_register.data_scale[0] = $urandom_range(1,3);
			cfg.local_fc_credits_register.data_scale[1] = $urandom_range(1,3);
			cfg.local_fc_credits_register.data_scale[2] = $urandom_range(1,3);
			`uvm_info("FC_CREDITS", "Scaled FC enabled after remote Feature capture", UVM_LOW)
		end else begin
			cfg.scaled_fc_active = 0;
			cfg.local_fc_credits_register.hdr_scale = '0;
			cfg.local_fc_credits_register.data_scale= '0;
			`uvm_info("FC_CREDITS", "Scaled FC disabled after remote Feature capture", UVM_LOW)
		end
		scaled_fc_cfg_done = 1;	//Flag indicating that the generation is compeleted only one time
	endfunction : configure_scaled_fc_once


    // Function: save_conf_scale_reg
    // Inputs  : The type of the FC DLLP (POSTED, NONPOSTED, COMPELETION)
    // Stores the Hdrscale and Datascale of the received DLLP
	function void save_conf_scale_reg;
		input fc_type_t fc_type;
		cfg.remote_fc_credits_register.hdr_scale[fc_type] 	= seq_item_rx.dllp[39:38];
		cfg.remote_fc_credits_register.data_scale[fc_type] 	= seq_item_rx.dllp[29:28];
	endfunction : save_conf_scale_reg


    // Function: save_conf_credits_reg
    // Inputs  : The type of the FC DLLP (POSTED, NONPOSTED, COMPELETION)
    // Stores the Hdrcredits and Datacredits of the received DLLP
	function void save_conf_credits_reg;
		input fc_type_t fc_type;
		cfg.remote_fc_credits_register.hdr_credits[fc_type] 	= seq_item_rx.dllp[37:30];
		cfg.remote_fc_credits_register.data_credits[fc_type] 	= seq_item_rx.dllp[27:16];
	endfunction : save_conf_credits_reg


    // Function: check_conf_scale_reg
    // Inputs  : The type of the FC DLLP (POSTED, NONPOSTED, COMPELETION)
    // Checks on the received Hdrscale and Datascale to match the one in the registers
	function void check_conf_scale_reg;
		input fc_type_t fc_type;
		if(	(cfg.remote_fc_credits_register.hdr_scale[fc_type]   != seq_item_rx.dllp[39:38]) ||
			(cfg.remote_fc_credits_register.data_scale[fc_type]  != seq_item_rx.dllp[29:28])) begin
				
				`uvm_error("FC_init2 or FC_update scale doesn't match",
       			 $sformatf("unmatche_type: %s",fc_type))
			end
	endfunction : check_conf_scale_reg


    // Function: check_conf_credits_reg
    // Inputs  : The type of the FC DLLP (POSTED, NONPOSTED, COMPELETION)
    // Checks on the received Hdrcredits and Datacredits to match the one in the registers
	function void check_conf_credits_reg;
		input fc_type_t fc_type;
		if( (cfg.remote_fc_credits_register.hdr_credits[fc_type] != seq_item_rx.dllp[37:30]) ||
			(cfg.remote_fc_credits_register.data_credits[fc_type]!= seq_item_rx.dllp[27:16])) begin
				
				`uvm_error("FC_init2 credits doesn't match",
       			 $sformatf("unmatche_type: %s",fc_type))
			end
	endfunction : check_conf_credits_reg


    // Function: save_seq_item
    // Inputs  : The state item that we are sending
    // Stores all processed values in the item before seding
	function void save_seq_item;
		input pcie_state_seq_item state_seq_item;

		DL_Up = ((current_state == DL_INIT2) || (current_state == DL_ACTIVE));
		DL_Down = ~DL_Up;
		
		state_seq_item.vip_state 			= current_state;
		state_seq_item.DL_Up 				= DL_Up;
		state_seq_item.DL_Down 				= DL_Down;
		state_seq_item.FI1 					= FI1;
		state_seq_item.FI2 					= FI2;
		state_seq_item.surprise_down_event 	= surprise_down_event;
	endfunction : save_seq_item


    // Function: CRC_generation
    // Inputs  : The DLLP without the crc
    // Outputs : The calculated crc
    // Calculates and generates the crc for the received DLLP
	function void CRC_generation;
		input 	bit[PAYLOAD_WIDTH-1:0] 	dllp_before_crc;
		output 	bit[CRC_WIDTH-1:0] 		crc;

        bit [CRC_WIDTH-1:0]     crc_calc = 16'hFFFF;        	//initial value
        bit [PAYLOAD_WIDTH-1:0] dllp_before_crc_rearanged;  	//each byte (7,6,5,4,3,2,1,0) by default
        bit [BYTE-1:0]          flipped_byte;
        bit [BYTE-1:0]          order_bytes [PAYLOAD_IN_BYTES];	//used in the flipping loops
        bit                     feedback;                   	//get the last bit of the crc and add it to the input bit

    	//flipping each byte in dllp_pkg as specified
        for (int i = 0; i < PAYLOAD_IN_BYTES; i++) begin
        	order_bytes[i] = dllp_before_crc[(i*BYTE) +: BYTE];			//{Byte 0, Byte 1, Byte 2, Byte 3}
        end
        for (int i = 0; i < PAYLOAD_IN_BYTES; i++) begin
        	dllp_before_crc_rearanged[(i*BYTE) +: BYTE] = order_bytes[PAYLOAD_IN_BYTES-1-i];
        end                                                             //needed {Byte 3, Byte 2, Byte 1, Byte 0}            
                                                                         
    	//generating crc
        for (int k = 0; k < PAYLOAD_WIDTH; k++) begin
            feedback     =  dllp_before_crc_rearanged[k] ^ crc_calc[CRC_WIDTH-1];   //adding bit[15] with the input
            crc_calc     =  {crc_calc[CRC_WIDTH-2:0] , feedback};           		//shift and add feedback
            crc_calc[1]  =  feedback ^ crc_calc[1];                         		//calculated using the polynomial 100Bh
            crc_calc[3]  =  feedback ^ crc_calc[3];
            crc_calc[12] =  feedback ^ crc_calc[12];
        end

   		//flipping each byte in crc as specified
        for (int i = 0; i < 2; i++) begin
	        for (int j = 0; j < BYTE; j++) begin
	            flipped_byte[7-j] = crc_calc[(i*BYTE)+j];
	        end
        	crc_calc[(i*BYTE) +: BYTE] = flipped_byte;  //maping each byte to (7,6,5,4,3,2,1,0)
        end                                          	//instead of (0,1,2,3,4,5,6,7)
    	//inverse each bit to model the inverter in the crc
        crc = ~crc_calc;
    endfunction : CRC_generation
endclass : pcie_vip_state_machine
`endif