class pcie_shared_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(pcie_shared_scoreboard)

  // ════════════════════════════════════════════════════════════════════════
  //  ANALYSIS FIFOs
  // ════════════════════════════════════════════════════════════════════════
  uvm_tlm_analysis_fifo #(pcie_dllp_seq_item)  upper_tx_fifo;   // Upper TX monitor → here
  uvm_tlm_analysis_fifo #(pcie_dllp_seq_item)  upper_rx_fifo;   // Upper RX monitor → here
  uvm_tlm_analysis_fifo #(pcie_dllp_seq_item)  lower_tx_fifo;   // Lower TX monitor → here
  uvm_tlm_analysis_fifo #(pcie_dllp_seq_item)  lower_rx_fifo;   // Lower RX monitor → here

  uvm_tlm_analysis_fifo #(pcie_state_seq_item)  upper_sm_fifo;   // Upper SM → here
  uvm_tlm_analysis_fifo #(pcie_state_seq_item)  lower_sm_fifo;   // Lower SM → here

  // ════════════════════════════════════════════════════════════════════════
  //  Internal Matching Queues
  // ════════════════════════════════════════════════════════════════════════
  pcie_dllp_seq_item  u2l_queue[$];
  pcie_dllp_seq_item  l2u_queue[$];

  // ════════════════════════════════════════════════════════════════════════
  //  State Pair Tracking
  // ════════════════════════════════════════════════════════════════════════
  dl_state_t  upper_state;
  dl_state_t  lower_state;

  // ════════════════════════════════════════════════════════════════════════
  //  Statistics
  // ════════════════════════════════════════════════════════════════════════
  int  u2l_matches;
  int  u2l_mismatches;
  int  u2l_drops;       // TX with no RX (leftover in check_phase)
  int  u2l_phantoms;    // RX with no TX

  int  l2u_matches;
  int  l2u_mismatches;
  int  l2u_drops;
  int  l2u_phantoms;

  int  state_pair_checks;
  int  illegal_pair_count;

  // ════════════════════════════════════════════════════════════════════════
  //  Timing Check
  // ════════════════════════════════════════════════════════════════════════
	localparam time FC_UPDATE_TIMEOUT = 34us ;
  localparam time RX_TIMEOUT        = 100us;

  time last_fc1_p;
  time last_fc1_np;
	time last_fc1_cpl;

	time last_fc2_p;
	time last_fc2_np;
	time last_fc2_cpl;

	time last_upfc_p;
	time last_upfc_np;
	time last_upfc_cpl;

	time last_dlf;

  time tx_u_time;
  time tx_l_time;
  time rx_u_time;
  time rx_l_time;

  // ════════════════════════════════════════════════════════════════════════
  //  Constructor
  // ════════════════════════════════════════════════════════════════════════
  function new(string name = "pcie_shared_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  // ════════════════════════════════════════════════════════════════════════
  //  Build Phase
  // ════════════════════════════════════════════════════════════════════════
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create all 6 FIFOs
    upper_tx_fifo = new("upper_tx_fifo", this);
    upper_rx_fifo = new("upper_rx_fifo", this);
    lower_tx_fifo = new("lower_tx_fifo", this);
    lower_rx_fifo = new("lower_rx_fifo", this);
    upper_sm_fifo = new("upper_sm_fifo", this);
    lower_sm_fifo = new("lower_sm_fifo", this);

    last_upper_sm_activity = 0;
    last_lower_sm_activity = 0;

    // Zero all counters
    u2l_matches    = 0;  u2l_mismatches = 0;  u2l_drops   = 0;  u2l_phantoms    = 0;
    l2u_matches    = 0;  l2u_mismatches = 0;  l2u_drops   = 0;  l2u_phantoms    = 0;
    state_pair_checks = 0;  illegal_pair_count = 0;
    last_fc1_p    = 0;
    last_fc1_np   = 0;
	  last_fc1_cpl  = 0;
	  last_fc2_p    = 0;
    last_fc2_np   = 0;
	  last_fc2_cpl  = 0;
	  last_upfc_p   = 0;
	  last_upfc_np  = 0;
	  last_upfc_cpl = 0;
	  last_dlf      = 0;
  endfunction


  // ════════════════════════════════════════════════════════════════════════
  //  Run Phase 
  // ════════════════════════════════════════════════════════════════════════
  task run_phase(uvm_phase phase);
    fork
      // --- DLLP Processing (4 threads) ---
      process_upper_tx();       // Thread 1: Upper TX → enqueue into u2l_queue
      process_lower_rx();       // Thread 2: Lower RX → match against u2l_queue
      process_lower_tx();       // Thread 3: Lower TX → enqueue into l2u_queue
      process_upper_rx();       // Thread 4: Upper RX → match against l2u_queue

      // --- State Machine Processing (2 threads) ---
      process_upper_sm();       // Thread 5: Upper SM state transitions
      process_lower_sm();       // Thread 6: Lower SM state transitions
    join_none
  endtask


  // ════════════════════════════════════════════════════════════════════════
  //  Thread 1: Upper TX — enqueue into u2l_queue
  // ════════════════════════════════════════════════════════════════════════
  task process_upper_tx();
    pcie_dllp_seq_item txn;
    forever begin
      upper_tx_fifo.get(txn);
      `uvm_info(get_type_name(),
        $sformatf("[U2L-TX] Enqueued Upper TX: %s", txn.convert2string()), UVM_HIGH)
      u2l_queue.push_back(txn);
      tx_u_time = $time;
      timing_check(txn);
    end
  endtask


  // ════════════════════════════════════════════════════════════════════════
  //  Thread 2: Lower RX — match against u2l_queue
  // ════════════════════════════════════════════════════════════════════════
  task process_lower_rx();
    pcie_dllp_seq_item rx_txn;
    forever begin
        // Wait for RX packet or timeout
        forever begin
            // Try to get RX with small step (1ns)
            if(lower_rx_fifo.try_get(rx_txn, 1ns)) begin
                rx_l_time = $time; // store RX arrival time
                `uvm_info(get_type_name(),
                    $sformatf("[U2L-RX] Received Lower RX: %s at time %0t", rx_txn.convert2string(), rx_l_time),
                    UVM_HIGH);

                match_u2l(rx_txn); // process RX
                break; // exit inner loop after RX received
            end

            // Timeout check
            if($time - tx_u_time >= RX_TIMEOUT) begin
                `uvm_error(get_type_name(),
                    $sformatf("[U2L-RX] Timeout! No RX received within %0t", RX_TIMEOUT));
                break; // exit inner loop after timeout
            end
        end
    end
  endtask


  // ════════════════════════════════════════════════════════════════════════
  //  Thread 3: Lower TX — enqueue into l2u_queue
  // ════════════════════════════════════════════════════════════════════════
  task process_lower_tx();
    pcie_dllp_seq_item txn;
    forever begin
      lower_tx_fifo.get(txn);
      `uvm_info(get_type_name(),
        $sformatf("[L2U-TX] Enqueued Lower TX: %s", txn.convert2string()), UVM_HIGH)
      l2u_queue.push_back(txn);
      timing_check(txn);
    end
  endtask


  // ════════════════════════════════════════════════════════════════════════
  //  Thread 4: Upper RX — match against l2u_queue
  // ════════════════════════════════════════════════════════════════════════
  task process_upper_rx();
    pcie_dllp_seq_item rx_txn;
    forever begin
      upper_rx_fifo.get(rx_txn);
      `uvm_info(get_type_name(),
        $sformatf("[L2U-RX] Received Upper RX: %s", rx_txn.convert2string()), UVM_HIGH)
      match_l2u(rx_txn);
    end
  endtask


  // ════════════════════════════════════════════════════════════════════════
  //  Thread 5: Upper SM — state pair validation
  // ════════════════════════════════════════════════════════════════════════
  task process_upper_sm();
    pcie_state_seq_item sm_txn;
    forever begin
      upper_sm_fifo.get(sm_txn);
      last_upper_sm_activity = $time;
      upper_state = sm_txn.vip_state;
      `uvm_info(get_type_name(),
        $sformatf("[SM-UPPER] %s → %s", sm_txn.vip_state.name()), UVM_MEDIUM)
      validate_state_pair();
    end
  endtask


  // ════════════════════════════════════════════════════════════════════════
  //  Thread 6: Lower SM — state pair validation
  // ════════════════════════════════════════════════════════════════════════
  task process_lower_sm();
    pcie_state_seq_item sm_txn;
    forever begin
      lower_sm_fifo.get(sm_txn);
      last_lower_sm_activity = $time;
      lower_state = sm_txn.vip_state;
      `uvm_info(get_type_name(),
        $sformatf("[SM-LOWER] %s → %s", sm_txn.vip_state.name()), UVM_MEDIUM)
      validate_state_pair();
    end
  endtask

  // ════════════════════════════════════════════════════════════════════════
  //  Match Logic: Upper-to-Lower (u2l) direction
  // ════════════════════════════════════════════════════════════════════════
  function void match_u2l(pcie_dllp_seq_item rx_item);
    pcie_dllp_seq_item tx_item;
    string mismatch_msg;

    if (u2l_queue.size() == 0) begin
      // Phantom: RX arrived but no TX was enqueued
      u2l_phantoms++;
      `uvm_error(get_type_name(),
        $sformatf("[U2L-PHANTOM] Lower RX item with no matching Upper TX!\n  RX: %s",
                  rx_item.convert2string()))
      return;
    end

    // Dequeue the oldest TX item (FIFO match)
    tx_item = u2l_queue.pop_front();

    // Field-by-field comparison
    if (tx_item.fields_match(rx_item, mismatch_msg)) begin
      u2l_matches++;
      `uvm_info(get_type_name(),
        $sformatf("[U2L-MATCH] OK. TX: %s", tx_item.convert2string()), UVM_MEDIUM)
    end else begin
      u2l_mismatches++;
      `uvm_error(get_type_name(),
        $sformatf("[U2L-CORRUPT] Fields mismatch!\n  TX: %s\n  RX: %s\n  Detail: %s",
                  tx_item.convert2string(), rx_item.convert2string(), mismatch_msg))
    end
  endfunction


  // ════════════════════════════════════════════════════════════════════════
  //  Match Logic: Lower-to-Upper (l2u) direction
  // ════════════════════════════════════════════════════════════════════════
  function void match_l2u(pcie_dllp_seq_item rx_item);
    pcie_dllp_seq_item tx_item;
    string mismatch_msg;

    if (l2u_queue.size() == 0) begin
      l2u_phantoms++;
      `uvm_error(get_type_name(),
        $sformatf("[L2U-PHANTOM] Upper RX item with no matching Lower TX!\n  RX: %s",
                  rx_item.convert2string()))
      return;
    end

    tx_item = l2u_queue.pop_front();

    if (tx_item.fields_match(rx_item, mismatch_msg)) begin
      l2u_matches++;
      `uvm_info(get_type_name(),
        $sformatf("[L2U-MATCH] OK. TX: %s", tx_item.convert2string()), UVM_MEDIUM)
    end else begin
      l2u_mismatches++;
      `uvm_error(get_type_name(),
        $sformatf("[L2U-CORRUPT] Fields mismatch!\n  TX: %s\n  RX: %s\n  Detail: %s",
                  tx_item.convert2string(), rx_item.convert2string(), mismatch_msg))
    end
  endfunction


  // ════════════════════════════════════════════════════════════════════════
  //  State Pair Validation
  // ════════════════════════════════════════════════════════════════════════
    function void validate_state_pair();
    state_pair_checks++;

    if (is_legal_pair(upper_state, lower_state)) begin
      `uvm_info(get_type_name(),
        $sformatf("[STATE-PAIR] Legal: Upper=%s, Lower=%s (check #%0d)",
                  upper_state.name(), lower_state.name(), state_pair_checks), UVM_MEDIUM)
    end else begin
      illegal_pair_count++;
      `uvm_error(get_type_name(),
        $sformatf("[STATE-PAIR] ILLEGAL: Upper=%s, Lower=%s (check #%0d)",
                  upper_state.name(), lower_state.name(), state_pair_checks))
    end
    endfunction

    function bit is_legal_pair(dl_state_t upper_state, dl_state_t lower_state);

      case (upper_state)

        DL_INACTIVE: begin
          return (lower_state == DL_INACTIVE);
        end

        DL_FEATURE: begin
          return (lower_state == DL_FEATURE ||
                  lower_state == FC_INIT1);
        end

        FC_INIT1: begin
          return (lower_state == DL_FEATURE ||
                  lower_state == FC_INIT1 ||
                  lower_state == FC_INIT2);
        end

        FC_INIT2: begin
          return (lower_state == FC_INIT1 ||
                  lower_state == FC_INIT2 ||
                  lower_state == DL_ACTIVE);
        end

        DL_ACTIVE: begin
          return (lower_state == FC_INIT2 ||
                  lower_state == DL_ACTIVE);
        end

        default: return 0;
      endcase

    endfunction

  // ════════════════════════════════════════════════════════════════════════
  //  Check Timeout
  // ════════════════════════════════════════════════════════════════════════
  function void timing_check(pcie_dllp_seq_item txn);
  //timing check 
    case(txn.dllp_type) ///////////////////////////////////////
      INITFC1_P: begin
        if(last_fc1_p != 0 && ($time - last_fc1_p) > FC_UPDATE_TIMEOUT) 
                `uvm_error("FC_TIMEOUT", $sformatf("InitFC1-P timeout: %0t", $time-last_fc1_p))
        last_fc1_p = $time;
      end
      INITFC1_NP: begin
      	if(last_fc1_np != 0 && ($time - last_fc1_np) > FC_UPDATE_TIMEOUT)
          `uvm_error("FC_TIMEOUT", $sformatf("InitFC1-NP timeout: %0t", $time-last_fc1_np))
        last_fc1_np = $time;
      end
      INITFC1_CPL: begin
        if(last_fc1_cpl != 0 && ($time - last_fc1_cpl) > FC_UPDATE_TIMEOUT)
          `uvm_error("FC_TIMEOUT", $sformatf("InitFC1-CPL timeout: %0t", $time-last_fc1_cpl))
        last_fc1_cpl = $time;
      end
      INITFC2_P: begin
        if(last_fc2_p != 0 && ($time - last_fc2_p) > FC_UPDATE_TIMEOUT) 
                `uvm_error("FC_TIMEOUT", $sformatf("InitFC2-P timeout: %0t", $time-last_fc2_p))
        last_fc2_p = $time;
      end
      INITFC2_NP: begin
      	if(last_fc2_np != 0 && ($time - last_fc1_np) > FC_UPDATE_TIMEOUT)
          `uvm_error("FC_TIMEOUT", $sformatf("InitFC2-NP timeout: %0t", $time-last_fc2_np))
        last_fc2_np = $time;
      end
      INITFC2_CPL: begin
        if(last_fc2_cpl != 0 && ($time - last_fc2_cpl) > FC_UPDATE_TIMEOUT)
          `uvm_error("FC_TIMEOUT", $sformatf("InitFC2-CPL timeout: %0t", $time-last_fc2_cpl))
        last_fc2_cpl = $time;
      end
      UPDATE_FC_P: begin
        if(last_upfc_p != 0 && ($time - last_upfc_p) > FC_UPDATE_TIMEOUT)
          `uvm_error("FC_TIMEOUT", $sformatf("InitFC2-CPL timeout: %0t", $time-last_upfc_p))
        last_upfc_p = $time;
      end
      UPDATE_FC_NP: begin
        if(last_upfc_np != 0 && ($time - last_upfc_np) > FC_UPDATE_TIMEOUT)
          `uvm_error("FC_TIMEOUT", $sformatf("InitFC2-CPL timeout: %0t", $time-last_upfc_np))
        last_upfc_np = $time;
      end
      UPDATE_FC_CPL: begin
        if(last_upfc_cpl != 0 && ($time - last_upfc_cpl) > FC_UPDATE_TIMEOUT)
          `uvm_error("FC_TIMEOUT", $sformatf("InitFC2-CPL timeout: %0t", $time-last_upfc_cpl))
        last_upfc_cpl = $time;
      end
      FEATURE_DLLP: begin
        if(last_dlf != 0 && ($time - last_dlf) > FC_UPDATE_TIMEOUT)
          `uvm_error("DLF_TIMEOUT",$sformatf("DL Feature DLLP interval exceeded: %0t",$time-last_dlf))
        last_dlf = $time;
      end
			default:begin
				last_fc1_p   = 0;
  			last_fc1_np  = 0;
				last_fc1_cpl = 0;
				last_fc2_p   = 0;
  			last_fc2_np  = 0;
				last_fc2_cpl = 0;
				last_up_fc   = 0;
				last_dlf     = 0;
			end
    endcase
    
  endfunction

  task wait_rx( 
    input string pkt_name,
    output bit rx_received
  );
      // Wait for an item with a small timeout step
      if(upper_rx_fifo.try_get(rx_txn, 1us)) begin
        `uvm_info(get_type_name(),
              $sformatf("[%0t] RX received for: %s", $time, rx_txn.convert2string()), UVM_HIGH)
            match_u2l(rx_txn); // call your matching function
            disable wait_rx_after_tx; // exit task after RX
        end

        // Check time
        if($time - tx_time >= RX_TIMEOUT) begin
            `uvm_error(get_type_name(),
              $sformatf("[%0t] Timeout! No RX received within %0t", $time, RX_TIMEOUT))
            disable wait_rx_after_tx; // exit task after timeout
        end
      
  endtask

  // ════════════════════════════════════════════════════════════════════════
  //  Check Phase — report unmatched items
  // ════════════════════════════════════════════════════════════════════════
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);

    // ── Report leftover TX items as drops ──
    if (u2l_queue.size() > 0) begin
      u2l_drops = u2l_queue.size();
      foreach (u2l_queue[i]) begin
        `uvm_error(get_type_name(),
          $sformatf("[U2L-DROP] Unmatched Upper TX item #%0d/%0d: %s",
                    i+1, u2l_drops, u2l_queue[i].convert2string()))
      end
    end

    if (l2u_queue.size() > 0) begin
      l2u_drops = l2u_queue.size();
      foreach (l2u_queue[i]) begin
        `uvm_error(get_type_name(),
          $sformatf("[L2U-DROP] Unmatched Lower TX item #%0d/%0d: %s",
                    i+1, l2u_drops, l2u_queue[i].convert2string()))
      end
    end
  endfunction



  // ════════════════════════════════════════════════════════════════════════
  //  Report Phase — summary
  // ════════════════════════════════════════════════════════════════════════
  function void report_phase(uvm_phase phase);
    string report;
    super.report_phase(phase);

    report = "\n";
    report = {report, "╔══════════════════════════════════════════════════════════════╗\n"};
    report = {report, "║          PCIe Shared Scoreboard — Final Report              ║\n"};
    report = {report, "╠══════════════════════════════════════════════════════════════╣\n"};
    report = {report, $sformatf("║  Upper-to-Lower (U2L):                                     ║\n")};
    report = {report, $sformatf("║    Matches    : %6d                                      ║\n", u2l_matches)};
    report = {report, $sformatf("║    Mismatches : %6d  (corruption)                         ║\n", u2l_mismatches)};
    report = {report, $sformatf("║    Drops      : %6d  (TX with no RX)                      ║\n", u2l_drops)};
    report = {report, $sformatf("║    Phantoms   : %6d  (RX with no TX)                      ║\n", u2l_phantoms)};
    report = {report, "╠══════════════════════════════════════════════════════════════╣\n"};
    report = {report, $sformatf("║  Lower-to-Upper (L2U):                                     ║\n")};
    report = {report, $sformatf("║    Matches    : %6d                                      ║\n", l2u_matches)};
    report = {report, $sformatf("║    Mismatches : %6d  (corruption)                         ║\n", l2u_mismatches)};
    report = {report, $sformatf("║    Drops      : %6d  (TX with no RX)                      ║\n", l2u_drops)};
    report = {report, $sformatf("║    Phantoms   : %6d  (RX with no TX)                      ║\n", l2u_phantoms)};
    report = {report, "╠══════════════════════════════════════════════════════════════╣\n"};
    report = {report, $sformatf("║  State Pair Validation:                                    ║\n")};
    report = {report, $sformatf("║    Total checks  : %6d                                   ║\n", state_pair_checks)};
    report = {report, $sformatf("║    Illegal pairs : %6d                                   ║\n", illegal_pair_count)};
    report = {report, "╚══════════════════════════════════════════════════════════════╝\n"};

    // Use appropriate severity for the summary line
    if ((u2l_mismatches + u2l_drops + u2l_phantoms +
         l2u_mismatches + l2u_drops + l2u_phantoms +
         illegal_pair_count) == 0) begin
      `uvm_info(get_type_name(), {report, "  * SCOREBOARD PASSED *"}, UVM_LOW)
    end else begin
      `uvm_error(get_type_name(), {report, "  * SCOREBOARD FAILED *"})
    end
  endfunction

endclass