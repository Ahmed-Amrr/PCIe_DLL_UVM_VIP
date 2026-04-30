`ifndef PCIE_VIP_TLP_MODEL
`define PCIE_VIP_TLP_MODEL

class pcie_vip_tlp_model extends uvm_component;
	//  Parameters
	parameter int TLP_WIDTH      = 64;
	parameter int PAYLOAD_WIDTH  = 32;
	parameter int LCRC_WIDTH     = 32;
	parameter int BYTE 			 = 8;
	parameter int SEQ_WIDTH        = 12;
	parameter int QUEUE_DEPTH      = 256;
    parameter int SEQ_MAX          = 4096;
    parameter int SEQ_HALF         = 2048;
    
	parameter int generator_polynomial = 'h04C11DB7;
	parameter int PAYLOAD_IN_BYTES = PAYLOAD_WIDTH / BYTE; 

	`uvm_component_utils(pcie_vip_tlp_model)
	//  TLM ports
	uvm_analysis_export 	#(pcie_tlp_seq_item) tlp_export_tx;		
	uvm_tlm_analysis_fifo 	#(pcie_tlp_seq_item) tlp_fifo_tx;

	uvm_analysis_export 	#(pcie_tlp_seq_item) tlp_export_rx;		
	uvm_tlm_analysis_fifo 	#(pcie_tlp_seq_item) tlp_fifo_rx;

	uvm_analysis_export 	#(pcie_dllp_seq_item) dllp_export_tx;		
	uvm_tlm_analysis_fifo 	#(pcie_dllp_seq_item) dllp_fifo_tx;

	uvm_analysis_export 	#(pcie_dllp_seq_item) dllp_export_rx;		
	uvm_tlm_analysis_fifo 	#(pcie_dllp_seq_item) dllp_fifo_rx;
	//  Sequence item handles				
	pcie_dllp_seq_item 		dllp_seq_item_tx;							
	pcie_dllp_seq_item 		dllp_seq_item_rx;	
	pcie_tlp_seq_item 		tlp_seq_item_tx;							
	pcie_tlp_seq_item 		tlp_seq_item_rx;	
    
    dllp_type_t dllp_type;
	// Spec counters
   
    bit [SEQ_WIDTH-1:0] NTS;   // NEXT_TRANSMIT_SEQ  — init 000h
    bit [SEQ_WIDTH-1:0] AS;    // ACKD_SEQ           — init FFFh	

    //  Retry buffer modelled as a queue of TLP seq items
    //  Each entry is one complete TLP (seq item pointer)
    
    pcie_tlp_seq_item retry_queue[$:QUEUE_DEPTH];			

	bit 	[PAYLOAD_WIDTH-1:0] received_tlp_payload;
	bit 	[LCRC_WIDTH-1:0] 	received_lcrc;
	bit 	[LCRC_WIDTH-1:0] 	lcrc_expected;		


	// Constructor
	function new(string name = "pcie_vip_tlp_model", uvm_component parent=null);
		super.new(name, parent);
	endfunction : new


	function void build_phase(uvm_phase phase);
		super.build_phase(phase); 

	  	tlp_export_tx = new("tlp_export_tx",this);
		tlp_fifo_tx   = new("tlp_fifo_tx",this);

		tlp_export_rx  = new("tlp_export_rx",this);
		tlp_fifo_rx    = new("tlp_fifo_rx",this);

		tlp_ap = new("tlp_ap",this);

		dllp_export_tx = new("dllp_export_tx",this);
		dllp_fifo_tx   = new("dllp_fifo_tx",this);

		dllp_export_rx  = new("dllp_export_rx",this);
		dllp_fifo_rx    = new("dllp_fifo_rx",this);

		dllp_ap = new("dllp_ap",this);
		 // Init spec counters
        NTS = '0;                        // 000h
        AS  = {SEQ_WIDTH{1'b1}};         // FFFh
	endfunction : build_phase


	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		tlp_export_tx.connect(tlp_fifo_tx.analysis_export);
		tlp_export_rx.connect(tlp_fifo_rx.analysis_export);
		dllp_export_tx.connect(dllp_fifo_tx.analysis_export);
		dllp_export_rx.connect(dllp_fifo_rx.analysis_export);
	endfunction : connect_phase


	task run_phase(uvm_phase phase);
		super.run_phase(phase);

		forever begin

			tlp_fifo_tx.get(tlp_seq_item_tx);
			tlp_fifo_rx.get(tlp_seq_item_rx);

			dllp_fifo_tx.get(dllp_seq_item_tx);
			dllp_fifo_rx.get(dllp_seq_item_rx);

			//Getting the DLLP and the CRC for checking
			received_tlp_payload = tlp_seq_item_rx.tlp[TLP_WIDTH-1:LCRC_WIDTH];
			received_lcrc = tlp_seq_item_rx.tlp[LCRC_WIDTH-1:0];
	
			lcrc_expected = LCRC_generation(.tlp_without_lcrc(received_tlp_payload));	
			if (received_lcrc == lcrc_expected) begin 	
				process_tlp();	
			end else begin
				`uvm_error("TLP Model error (Illegal TLP received)",
       			$sformatf("received crc is : 0x%h, expected crc : 0x%h",received_lcrc, lcrc_expected))
			end
		end
	endtask : run_phase


    // Function: process_tlp
    // Processes the TLP and store it in retry buffer
	function void process_tlp;

	endfunction : process_tlp


    //   FUNCTION   WRAPPER :  tx_tlp
    //   all sub-functions for every TLP + DLLP pair:
    //     1. assign_sequence_number
    //     2. store_in_queue
    //     3. increment_nts
    //     4. process_dllp
    //        a. crc_calc  (DLLP CRC check)
    //        b. check_acked_seq
    //        c. update_AS          (if forward progress)
    //        d. purge_queue        (if forward progress)
    //        e. replay_from_queue  (if NAK)
    task tx_tlp(
        input pcie_tlp_seq_item  tlp_item,   // new TLP from Transaction Layer
        input pcie_dllp_seq_item dllp_item   // received ACK/NAK DLLP
    );
        pcie_tlp_seq_item sequenced_tlp;


        // FIRST PATH : New TLP from Transaction Layer

        //assign_sequence_number
        sequenced_tlp = assign_sequence_number(tlp_item, NTS);

        //store_in_queue

        store_in_queue(sequenced_tlp, retry_queue);

        // increment_nts

        NTS = increment_nts(NTS);

        // Publish stamped TLP downstream
        tlp_ap.write(sequenced_tlp);

        // SECOND PATH : Process received DLLP (ACK or NAK)

        // process_dllp

        process_dllp(dllp_item);

    endtask : tx_tlp

    //  FUNCTION 1 : assign_sequence_number
    //  ASSIGNS the current NTS value into the TLP seq item.
  
    function pcie_tlp_seq_item assign_sequence_number(
        input pcie_tlp_seq_item tlp_item,
        input bit [SEQ_WIDTH-1:0] nts
    );
        pcie_tlp_seq_item tlp_with_new_Seq_No;
        tlp_with_new_Seq_No = pcie_tlp_seq_item::type_id::create("tlp_with_new_Seq_No");
        tlp_with_new_Seq_No.copy(tlp_item);

        // Write {4'b0000, nts[11:0]} into the top 16 bits of the TLP
        // Bits [63:60] = 4'b0000  (reserved)
        // Bits [59:48] = nts      (sequence number)
        tlp_with_new_Seq_No.tlp[TLP_WIDTH-1: 48]    = {4'b0000, nts[11:0]};

        return tlp_with_new_Seq_No;
    endfunction : assign_sequence_number
    //  FUNCTION 2 : store_in_queue
    
    task store_in_queue(
        input pcie_tlp_seq_item  tlp_item,
        ref   pcie_tlp_seq_item  q[$:QUEUE_DEPTH]
    );
        if (q.size() >= QUEUE_DEPTH) begin
            `uvm_error("TLP_MODEL",
                "Retry queue full — cannot store TLP (flow-control violation)")
            return;
        end
        q.push_back(tlp_item);
        `uvm_info("TLP_MODEL",
            $sformatf("Stored TLP seq=0x%0h in retry queue  (queue size=%0d)",
                      tlp_item.tlp[TLP_WIDTH-5 -: SEQ_WIDTH], q.size()),
            UVM_HIGH)
    endtask : store_in_queue

    //  FUNCTION 3 : increment_nts
    //  Equation : NTS = (NTS + 1) mod 4096
   function logic [SEQ_WIDTH-1:0] increment_nts(
        input logic [SEQ_WIDTH-1:0] nts
    );
        return (nts + 1) % SEQ_MAX;
    endfunction

    //  FUNCTION 4 : process_dllp

    task process_dllp(
        input pcie_dllp_seq_item dllp_item,
        input dllp_type_t dllp_type
    );
        bit [1:0] seq_status;

        // ---- Step a : crc_calc — validate DLLP CRC ----
        if (!crc_calc(dllp_item)) begin
            // Bad CRC: silently discard, no further action
            `uvm_info("TLP_MODEL",
                "DLLP discarded — CRC check failed", UVM_MEDIUM)
            return;
        end

        // ---- Step b : check_acked_seq ----
        //   returns 2'b11 -> protocol error  (seq out of range)
        //   returns 2'b01 -> forward progress (AS != dllp_seq, newer)
        //   returns 2'b00 -> no progress      (AS == dllp_seq)
        seq_status = check_acked_seq(NTS, AS, dllp_item.seq_num);

        case (seq_status)

            2'b11: begin
                // Out-of-range sequence number -> Data Link Protocol Error
                `uvm_error("TLP_MODEL",
                    $sformatf("Data Link Protocol Error: dllp_seq=0x%0h out of range  NTS=0x%0h  AS=0x%0h",
                              dllp_item.seq_num, NTS, AS))
                return;
            end

            2'b01: begin
                // Forward progress confirmed
                // ---- Step c : update_AS ----
                update_AS(dllp_item.seq_num, AS);

                // ---- Step d : purge_queue ----
                purge_queue(AS, retry_queue);

                `uvm_info("TLP_MODEL",
                    $sformatf("ACK forward progress: AS updated to 0x%0h  retry queue size=%0d",
                              AS, retry_queue.size()),
                    UVM_MEDIUM)
            end

            2'b00: begin
                // AS already equals dllp_seq — no purge needed
                `uvm_info("TLP_MODEL",
                    $sformatf("DLLP seq=0x%0h matches current AS — no purge",
                              dllp_item.seq_num),
                    UVM_HIGH)
            end

            default: ;
        endcase

        // ---- Step e : replay_from_queue if NAK ----
        if (dllp_type == NACK) begin
            `uvm_info("TLP_MODEL",
                $sformatf("NAK received  seq=0x%0h — initiating replay  (%0d TLPs in queue)",
                          dllp_item.seq_num, retry_queue.size()),
                UVM_MEDIUM)
            replay_from_queue(retry_queue);
        end

    endtask : process_dllp

 //
    //  Validates DLLP seq and checks for forward progress.
    //  Returns:
    //    2'b11 -> protocol error  (seq out of valid window)
    //    2'b01 -> forward progress
    //    2'b00 -> no new progress (AS == dllp_seq)
   
    function bit [1:0] check_acked_seq(
        input bit [SEQ_WIDTH-1:0] nts,
        input bit [SEQ_WIDTH-1:0] as,
        input bit [SEQ_WIDTH-1:0] dllp_s
    );
        // Out-of-range: ((NTS-1) - dllp_s) mod 4096 > 2048
        if (((nts - 1 - dllp_s) % SEQ_MAX) > SEQ_HALF)
            return 2'b11;

        // Forward progress: dllp_s is newer than AS
        if ((dllp_s != as) &&
            (((dllp_s - as) % SEQ_MAX) < SEQ_HALF))
            return 2'b01;

        // No new progress
        return 2'b00;
    endfunction : check_acked_seq

    //  Loads ACKD_SEQ with the new sequence number from the DLLP.

    task update_AS(
        input  bit [SEQ_WIDTH-1:0] new_seq,
        output bit [SEQ_WIDTH-1:0] as
    );
        as = new_seq;
    endtask : update_AS


    //  Removes all entries from the front of the retry queue whose
    //  seq number is <= AS (using modular arithmetic for wrap-around).
    //  (ackd_seq - entry.seq) mod 4096 < 2048  =>  entry is old

	task purge_queue(
	    input bit [SEQ_WIDTH-1:0]  ackd_seq,
	    ref   pcie_tlp_seq_item    q[$:QUEUE_DEPTH]
	);
	    bit [SEQ_WIDTH-1:0] entry_seq;
	    bit [SEQ_WIDTH-1:0] diff;

	    while (q.size() > 0) begin
	        entry_seq = q[0].tlp[TLP_WIDTH-5 -: SEQ_WIDTH];
 
	        
	        diff = (ackd_seq - entry_seq) & (SEQ_MAX - 1);

	        if (diff < SEQ_HALF) begin
	            void'(q.pop_front());
	            `uvm_info("TLP_MODEL",
	                $sformatf("Purged TLP seq=0x%0h (ackd_seq=0x%0h diff=%0d queue size=%0d)",
	                          entry_seq, ackd_seq, diff, q.size()),
	                UVM_HIGH)
	        end
	        else begin
	            break; // remaining entries are newer
	        end
	    end
	endtask

   //  Retransmits all TLPs remaining in the retry queue in order
    //  (oldest first). 
    task replay_from_queue(
        ref pcie_tlp_seq_item q[$:QUEUE_DEPTH]
    );
        if (q.size() == 0) begin
            `uvm_info("TLP_MODEL",
                "Replay requested but retry queue is empty — nothing to replay",
                UVM_MEDIUM)
            return;
        end

        foreach (q[i]) begin
            `uvm_info("TLP_MODEL",
                $sformatf("Replaying TLP [%0d/%0d]  seq=0x%0h",
                          i+1, q.size(),
                          q[i].tlp[TLP_WIDTH-5 -: SEQ_WIDTH]),
                UVM_MEDIUM)
            tlp_ap.write(q[i]);
        end
    endtask : replay_from_queue




     // Function lcrc_calc : Computes the 32-bit CRC over a 32-bit TLP payload
    // Inputs   : 32-bit TLP payload (without CRC field)
    // Returns  : 32-bit LCRC
    function bit [LCRC_WIDTH-1:0] lcrc_calc (bit [PAYLOAD_WIDTH-1:0] tlp_without_lcrc);
        bit [BYTE-1:0]      data [PAYLOAD_IN_BYTES]; // Payload bytes
        bit [LCRC_WIDTH-1:0] lcrc;                     // Running LFSR state
        bit [LCRC_WIDTH-1:0] mapped_lcrc;              // Bit-reversed result
        bit                 feedback;                // XOR of MSB and current data bit

        // Split the payload into bytes.
        foreach (data[i])
            data[i] = _dllp_without_crc[(BYTE * i) +: BYTE];

        // load LFSR with initial seed 
        lcrc = 'hFFFF_FFFF; 

        // LFSR processing 
        // outer loop : bytes high-to-low  (byte[3] first, byte[0] last)
        // inner loop : bits LSB-to-MSB within each byte  ( bit 0 first, bit 7 last)
        // feedback drives the polynomial XOR only.
        for (int i = PAYLOAD_IN_BYTES - 1; i >= 0; i--) begin
            for (int j = 0; j < BYTE; j++) begin
                feedback = data[i][j] ^ lcrc[LCRC_WIDTH-1]; 
                lcrc      = lcrc << 1;                       
                if (feedback)
                    lcrc = lcrc ^ generator_polynomial;      
            end
        end
        // complement the result of the calculation
        lcrc = ~lcrc;

        // bit-reverse each byte independently 
        mapped_lcrc[7:0]   = {<<{lcrc[7:0]}};    // reverse bits [7:0]
        mapped_lcrc[15:8]  = {<<{lcrc[15:8]}};   // reverse bits [15:8]
        mapped_lcrc[23:16] = {<<{lcrc[23:16]}};  // reverse bits [23:16]
        mapped_lcrc[31:24] = {<<{lcrc[31:24]}};  // reverse bits [31:24]
        return mapped_lcrc;

    endfunction : lcrc_calc

    function void crc_calc;
            input  bit [PAYLOAD_WIDTH-1:0] _dllp_without_crc;
            output bit [CRC_WIDTH-1:0]     _crc             ;

            bit [BYTE-1:0] data [PAYLOAD_IN_BYTES];
            bit [CRC_WIDTH-1:0] crc;
            bit [CRC_WIDTH-1:0] mapped_crc;
            bit feedback;
            
            // split the payload into bytes as CRC calculation starts with bit 0 of byte 0 and proceeds from bit 0 to bit 7 of each byte
            foreach (data[i]) begin
                data[i] = _dllp_without_crc[(BYTE*i) +: BYTE];
            end
            // load the LFSR with the initial seed
            crc = initial_seed;

            // process the btes to generate the crc
            for (int i = 3; i >= 0; i--) begin            
                for (int j = 0; j < BYTE; j++) begin
                    feedback = data[i][j] ^ crc[CRC_WIDTH-1];
                    crc = crc << 1;
                    //crc[0] = feedback;
                    if (feedback) 
                        crc = crc ^ generator_polynomial;
                end
            end
            // complemet the crc "The result of the calculation is complemented"
            crc = ~crc;
            // map the bits as specs say
            mapped_crc[7:0]   = {<<{crc[7:0]}};
            mapped_crc[15:8]  = {<<{crc[15:8]}};
            _crc = mapped_crc;
        endfunction : crc_calc
endclass : pcie_vip_tlp_model
`endif