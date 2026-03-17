`ifndef PCIE_VIP_STATE_MACHINE
`define PCIE_VIP_STATE_MACHINE

class pcie_vip_state_machine extends uvm_component;

/*-------------------------------------------------------------------------------
-- UVM Factory register
-------------------------------------------------------------------------------*/
	// Provide implementations of virtual methods such as get_type_name and create
	`uvm_component_utils(pcie_vip_state_machine)

/*-------------------------------------------------------------------------------
-- Interface, port, fields
-------------------------------------------------------------------------------*/
	uvm_analysis_port #(pcie_state_seq_item) sm_ap; //sending data to the shared scoreboard and local scoreboard
	pcie_state_seq_item state_seq_item;


	uvm_analysis_export #(pcie_dllp_seq_item) sm_export_tx;		//getting the data from tx monitor
	uvm_tlm_analysis_fifo #(pcie_dllp_seq_item) sm_fifo_tx;

	pcie_dllp_seq_item seq_item_tx;

	uvm_analysis_export #(pcie_dllp_seq_item) sm_export_rx;		//getting the data from rx monitor
	uvm_tlm_analysis_fifo #(pcie_dllp_seq_item) sm_fifo_rx;

	pcie_dllp_seq_item seq_item_rx;

	pcie_vip_config cfg;										//to get the configuration registers
	dl_state_t current_state, next_state;						//used for the FSM

	logic[23:0] fc_registers;

	bit init1_p_f;
	bit init1_np_f;
	bit init1_cpl_f;
	bit FI1;
	assign FI1 = init1_cpl_f;

	bit init2_p_f;
	bit init2_np_f;
	bit init2_cpl_f;
	bit FI2;
	assign FI2 = init2_cpl_f;

	bit[15:0] crc_expected;

/*-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------*/
	// Constructor
	function new(string name = "pcie_vip_state_machine", uvm_component parent=null);
		super.new(name, parent);
	endfunction : new

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// Get the configuration object to access the configuration registers
	    if(!uvm_config_db #(pcie_vip_config)::get(this,"","CFG_ENV",cfg))
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
			CRC_generation(seq_item_rx.dllp[47:16],crc_expected);
			if (seq_item_rx.dllp[15:0] == crc_expected) begin
				state_transition();
			end
		end
	endtask : run_phase

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
		// if (/* reset */) begin 						//requirs modeling for the reset logic
		// 	next_state = DL_INACTIVE;
		// end else 
		if (!seq_item_rx.pl_lnk_up) begin 	//comes from the LPIF
			next_state = DL_INACTIVE;
		end else if (!cfg.local_register_feature.feature_exchange_enable) begin
			next_state = DL_INIT1;
		end begin
			next_state = DL_FEATURE;
		end
	endfunction : inactive_state

	function void feature_state ();
		// if (/* reset */) begin 						//requirs modeling for the reset logic
		// 	next_state = DL_INACTIVE;
		// end else 
		if (!seq_item_rx.pl_lnk_up) begin 	//comes from the LPIF
			next_state = DL_INACTIVE;
		end else if ((seq_item_rx.dllp[47:43] == 5'b01000) || (seq_item_rx.dllp[47:43] == 5'b01010) || (seq_item_rx.dllp[47:43] == 5'b01100)) begin
			next_state = DL_INIT1;
		end else if ((seq_item_rx.dllp[47:40] == 00000010) && (seq_item_rx.dllp[39] == 1)) begin
			next_state = DL_INIT1;
		end else begin 
			next_state = DL_FEATURE;
		end

		if ((seq_item_rx.dllp[47:40] == 00000010) && (cfg.remote_register_feature.remote_feature_valid == 0)) begin
			cfg.remote_register_feature.remote_feature_valid = 1;
			cfg.remote_register_feature.remote_feature_supported = seq_item_rx.dllp[38:16];
		end
	endfunction : feature_state

	function void init1_state ();
		// if (/* reset */) begin 						//requirs modeling for the reset logic
		// 	next_state = DL_INACTIVE;
		// end else 
		if (!seq_item_rx.pl_lnk_up) begin 	//comes from the LPIF
			next_state = DL_INACTIVE;
		end else if (seq_item_rx.dllp[47:43] == 5'b01000) begin
			init1_p_f = 1;
			init1_np_f = 0;
			init1_cpl_f = 0;

			fc_registers = seq_item_rx.dllp[39:16];

			next_state = DL_INIT1;
		end else if ((seq_item_rx.dllp[47:43] == 5'b01010) && init1_p_f && (seq_item_rx.dllp[39:16] == fc_registers)) begin
			init1_p_f = 0;
			init1_np_f = 1;
			init1_cpl_f = 0;
			next_state = DL_INIT1;
		end else if ((seq_item_rx.dllp[47:43] == 5'b01100) && init1_np_f && (seq_item_rx.dllp[39:16] == fc_registers)) begin
			init1_p_f = 0;
			init1_np_f = 0;
			init1_cpl_f = 1;
			next_state = DL_INIT2;
			cfg.fc_credits_register.hdr_scale = seq_item_rx.dllp[39:38];
			cfg.fc_credits_register.hdr_credits = seq_item_rx.dllp[37:30];
			cfg.fc_credits_register.data_scale = seq_item_rx.dllp[29:28];
			cfg.fc_credits_register.data_credits = seq_item_rx.dllp[27:16];
		end else begin
			init1_p_f = 0;
			init1_np_f = 0;
			init1_cpl_f = 0;
			fc_registers = 0;
			next_state = DL_INIT1;
		end
	endfunction : init1_state

	function void init2_state ();
		// if (/* reset */) begin 						//requirs modeling for the reset logic
		// 	next_state = DL_INACTIVE;
		// end else 
		if (!seq_item_rx.pl_lnk_up) begin 	//comes from the LPIF
			next_state = DL_INACTIVE;
		end else if (seq_item_rx.dllp[47:43] == 5'b11000) begin
			init2_p_f = 1;
			init2_np_f = 0;
			init2_cpl_f = 0;
			next_state = DL_INIT2;
		end else if ((seq_item_rx.dllp[47:43] == 5'b11010) && init2_p_f) begin
			init2_p_f = 0;
			init2_np_f = 1;
			init2_cpl_f = 0;
			next_state = DL_INIT2;
		end else if ((seq_item_rx.dllp[47:43] == 5'b11100) && init2_np_f) begin
			init2_p_f = 0;
			init2_np_f = 0;
			init2_cpl_f = 1;
			next_state = DL_ACTIVE;
		end else begin
			init2_p_f = 0;
			init2_np_f = 0;
			init2_cpl_f = 0;
			next_state = DL_INIT2;
		end
	endfunction : init2_state

	function void active_state ();
		// if (/* reset */) begin 						//requirs modeling for the reset logic
		// 	next_state = DL_INACTIVE;
		// end else 
		if (!seq_item_rx.pl_lnk_up) begin 	//comes from the LPIF
			next_state = DL_INACTIVE;
		end
	endfunction : active_state

	function CRC_generation(input bit[31:0] dllp_before_crc,	//the default is {Byte 0, Byte 1, Byte 2, Byte 3}
							output bit[15:0] crc				//each byte (7,6,5,4,3,2,1,0)
	);

		bit 		[15:0]	crc_calc = 16'hFFFF;		//initial value
		bit			[31:0] 	dllp_before_crc_rearanged;	//rearrange each byte to be (0,1,2,3,4,5,6,7)
		bit 		[7:0]	flipped_byte;				//used in the flipping loops
		bit 				feedback;					//get the last bit of the crc and add it to the input bit

	//flipping each byte in dllp_pkg as specified
		for (int i = 0; i < 4; i++) begin
			for (int j = 0; j < 8; j++) begin
				flipped_byte[7-j] = dllp_before_crc[(i*8)+j];
			end
			dllp_before_crc_rearanged[((i*8)+7):(i*8)] = flipped_byte;		//{Byte 0, Byte 1, Byte 2, Byte 3}
		end 																//each byte (0,1,2,3,4,5,6,7)

	//generating crc
		for (int k = 0; k < 32; k++) begin
			feedback 	 =	dllp_before_crc_rearanged[31-k] ^ crc_calc[15];	//adding bit[15] with the input
			crc_calc	 =	{crc_calc[14:0] , feedback};
			crc_calc[1]	 =	feedback ^ crc_calc[1];							//calculated using the polynomial 100Bh
			crc_calc[3]	 =	feedback ^ crc_calc[3];
			crc_calc[12] =	feedback ^ crc_calc[12];
		end

	//flipping each byte in crc as specified
		for (int i = 0; i < 2; i++) begin
			for (int j = 0; j < 8; j++) begin
				flipped_byte[7-j] = crc_calc[(i*8)+j];
			end
			crc_calc[((i*8)+7):(i*8)] = flipped_byte;	//{Byte 0, Byte 1} each byte (7,6,5,4,3,2,1,0)
		end 											//instead of (0,1,2,3,4,5,6,7)
	//inverse each bit to model the inverter in the crc
		crc = ~crc_calc;
	endfunction : CRC_generation

endclass : pcie_vip_state_machine

`endif