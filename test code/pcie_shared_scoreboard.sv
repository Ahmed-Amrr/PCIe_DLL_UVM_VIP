class pcie_shared_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(pcie_shared_scoreboard)

  //---------------------------------------------------------------------
  // TLM Analysis FIFOs 
  //---------------------------------------------------------------------
  uvm_tlm_analysis_fifo #(pcie_seq_item) upper_tx_fifo;   // from upper env TX monitor
  uvm_tlm_analysis_fifo #(pcie_seq_item) upper_rx_fifo;   // from upper env RX monitor
  uvm_tlm_analysis_fifo #(pcie_seq_item) lower_tx_fifo;   // from lower env TX monitor
  uvm_tlm_analysis_fifo #(pcie_seq_item) lower_rx_fifo;   // from lower env RX monitor

  //---------------------------------------------------------------------
  // Internal matching queues  (Upper→Lower and Lower→Upper)
  //---------------------------------------------------------------------
  pcie_seq_item u2l_tx_queue[$];   // Upper TX  → expect at Lower RX
  pcie_seq_item l2u_tx_queue[$];   // Lower TX  → expect at Upper RX

  //---------------------------------------------------------------------
  // Counters
  //---------------------------------------------------------------------
  int u2l_match_cnt;
  int u2l_mismatch_cnt;
  int l2u_match_cnt;
  int l2u_mismatch_cnt;
  int u2l_tx_cnt;
  int u2l_rx_cnt;
  int l2u_tx_cnt;
  int l2u_rx_cnt;

  //---------------------------------------------------------------------
  // Milestone flags
  //---------------------------------------------------------------------
  bit feature_exchange_done;
  bit fc_init1_complete;
  bit fc_init2_complete;
  bit dl_active_reached;

  // Internal milestone sub-flags for FC_INIT tracking
  // Upper→Lower direction
  bit u2l_fi1_p_seen, u2l_fi1_np_seen, u2l_fi1_cpl_seen;
  bit u2l_fi2_p_seen, u2l_fi2_np_seen, u2l_fi2_cpl_seen;
  // Lower→Upper direction
  bit l2u_fi1_p_seen, l2u_fi1_np_seen, l2u_fi1_cpl_seen;
  bit l2u_fi2_p_seen, l2u_fi2_np_seen, l2u_fi2_cpl_seen;

  // Feature tracking
  bit u2l_feature_req_seen, u2l_feature_ack_seen;
  bit l2u_feature_req_seen, l2u_feature_ack_seen;

  //---------------------------------------------------------------------
  // Configuration
  //---------------------------------------------------------------------
  int match_timeout_ns = 10000;  // max wait for RX after TX enqueued

  //---------------------------------------------------------------------
  // Constructor
  //---------------------------------------------------------------------
  function new(string name = "pcie_shared_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  //---------------------------------------------------------------------
  // Build Phase — create FIFOs, init counters
  //---------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    upper_tx_fifo = new("upper_tx_fifo", this);
    upper_rx_fifo = new("upper_rx_fifo", this);
    lower_tx_fifo = new("lower_tx_fifo", this);
    lower_rx_fifo = new("lower_rx_fifo", this);

    u2l_match_cnt    = 0;
    u2l_mismatch_cnt = 0;
    l2u_match_cnt    = 0;
    l2u_mismatch_cnt = 0;
    u2l_tx_cnt       = 0;
    u2l_rx_cnt       = 0;
    l2u_tx_cnt       = 0;
    l2u_rx_cnt       = 0;

    feature_exchange_done = 0;
    fc_init1_complete     = 0;
    fc_init2_complete     = 0;
    dl_active_reached     = 0;

    u2l_fi1_p_seen = 0; u2l_fi1_np_seen = 0; u2l_fi1_cpl_seen = 0;
    u2l_fi2_p_seen = 0; u2l_fi2_np_seen = 0; u2l_fi2_cpl_seen = 0;
    l2u_fi1_p_seen = 0; l2u_fi1_np_seen = 0; l2u_fi1_cpl_seen = 0;
    l2u_fi2_p_seen = 0; l2u_fi2_np_seen = 0; l2u_fi2_cpl_seen = 0;

    u2l_feature_req_seen = 0; u2l_feature_ack_seen = 0;
    l2u_feature_req_seen = 0; l2u_feature_ack_seen = 0;
  endfunction

  //---------------------------------------------------------------------
  // Run Phase
  //---------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    fork
      process_upper_tx();
      process_lower_rx();
      process_lower_tx();
      process_upper_rx();
    join
  endtask

  //---------------------------------------------------------------------
  // Upper TX processing — enqueue into u2l_tx_queue
  //---------------------------------------------------------------------
  task process_upper_tx();
    pcie_seq_item txn;
    forever begin
      upper_tx_fifo.get(txn);
      u2l_tx_cnt++;
      `uvm_info("SHARED_SB", $sformatf("[U_TX] #%0d Enqueued: %s",
                u2l_tx_cnt, txn.convert2string()), UVM_MEDIUM)
      u2l_tx_queue.push_back(txn);
      update_milestones_tx(txn, "U2L");
    end
  endtask

  //---------------------------------------------------------------------
  // Lower RX processing — match against u2l_tx_queue head
  //---------------------------------------------------------------------
  task process_lower_rx();
    pcie_seq_item txn;
    forever begin
      lower_rx_fifo.get(txn);
      u2l_rx_cnt++;
      `uvm_info("SHARED_SB", $sformatf("[L_RX] #%0d Received: %s",
                u2l_rx_cnt, txn.convert2string()), UVM_MEDIUM)
      match_rx_against_queue(txn, u2l_tx_queue, "U2L", u2l_match_cnt, u2l_mismatch_cnt);
    end
  endtask

  //---------------------------------------------------------------------
  // Lower TX processing — enqueue into l2u_tx_queue
  //---------------------------------------------------------------------
  task process_lower_tx();
    pcie_seq_item txn;
    forever begin
      lower_tx_fifo.get(txn);
      l2u_tx_cnt++;
      `uvm_info("SHARED_SB", $sformatf("[L_TX] #%0d Enqueued: %s",
                l2u_tx_cnt, txn.convert2string()), UVM_MEDIUM)
      l2u_tx_queue.push_back(txn);
      update_milestones_tx(txn, "L2U");
    end
  endtask

  //---------------------------------------------------------------------
  // Upper RX processing — match against l2u_tx_queue head
  //---------------------------------------------------------------------
  task process_upper_rx();
    pcie_seq_item txn;
    forever begin
      upper_rx_fifo.get(txn);
      l2u_rx_cnt++;
      `uvm_info("SHARED_SB", $sformatf("[U_RX] #%0d Received: %s",
                l2u_rx_cnt, txn.convert2string()), UVM_MEDIUM)
      match_rx_against_queue(txn, l2u_tx_queue, "L2U", l2u_match_cnt, l2u_mismatch_cnt);
    end
  endtask

  //---------------------------------------------------------------------
  // Match helper — compare RX txn against head of expected TX queue
  //---------------------------------------------------------------------
  function void match_rx_against_queue(
    pcie_seq_item          rx_txn,
    ref pcie_seq_item      tx_queue[$],
    input string          direction,
    ref int      match_cnt,
    ref int      mismatch_cnt
  );
    pcie_seq_item exp_txn;
    string       mismatch_detail;

    if (tx_queue.size() == 0) begin
      `uvm_error("SHARED_SB", $sformatf("[%s] RX received but TX queue empty! Unexpected DLLP: %s",
                 direction, rx_txn.convert2string()))
      mismatch_cnt++;
      return;
    end

    exp_txn = tx_queue.pop_front();

    if (exp_txn.fields_match(rx_txn, mismatch_detail)) begin
      match_cnt++;
      `uvm_info("SHARED_SB", $sformatf("[%s] MATCH #%0d: %s",
                direction, match_cnt, rx_txn.convert2string()), UVM_HIGH)
    end else begin
      mismatch_cnt++;
      `uvm_error("SHARED_SB", $sformatf("[%s] MISMATCH #%0d:\n  EXP: %s\n  GOT: %s\n  Detail: %s",
                 direction, mismatch_cnt, exp_txn.convert2string(),
                 rx_txn.convert2string(), mismatch_detail))
    end
  endfunction

  //---------------------------------------------------------------------
  // Milestone tracking — called on TX enqueue
  //---------------------------------------------------------------------
  function void update_milestones_tx(pcie_seq_item txn, string direction);

    // --- Feature milestone ---
    if (txn.is_feature()) begin // will edit it to check the type
      if (direction == "U2L") begin
        if (txn.feature_ack)
          u2l_feature_ack_seen = 1;
        else
          u2l_feature_req_seen = 1;
      end else begin
        if (txn.feature_ack)
          l2u_feature_ack_seen = 1;
        else
          l2u_feature_req_seen = 1;
      end
      if (!feature_exchange_done &&
          u2l_feature_req_seen && u2l_feature_ack_seen &&
          l2u_feature_req_seen && l2u_feature_ack_seen) begin
        feature_exchange_done = 1;
        `uvm_info("SHARED_SB", "[MILESTONE] Feature exchange complete (both directions REQ+ACK)", UVM_LOW)
      end
    end

    // --- FC_INIT1 milestone ---
    if (txn.is_initfc1()) begin // will edit it to check the type
      if (direction == "U2L") begin
        case (txn.fc_type)
          FC_POSTED:     u2l_fi1_p_seen   = 1;
          FC_NONPOSTED:  u2l_fi1_np_seen  = 1;
          FC_COMPLETION:  u2l_fi1_cpl_seen = 1;
          default: ;
        endcase
      end else begin
        case (txn.fc_type)
          FC_POSTED:     l2u_fi1_p_seen   = 1;
          FC_NONPOSTED:  l2u_fi1_np_seen  = 1;
          FC_COMPLETION:  l2u_fi1_cpl_seen = 1;
          default: ;
        endcase
      end
      if (!fc_init1_complete &&
          u2l_fi1_p_seen && u2l_fi1_np_seen && u2l_fi1_cpl_seen &&
          l2u_fi1_p_seen && l2u_fi1_np_seen && l2u_fi1_cpl_seen) begin
        fc_init1_complete = 1;
        `uvm_info("SHARED_SB", "[MILESTONE] FC_INIT1 complete (P+NP+Cpl both directions)", UVM_LOW)
      end
    end

    // --- FC_INIT2 milestone ---
    if (txn.is_initfc2()) begin // will edit it to check the type
      if (direction == "U2L") begin
        case (txn.fc_type)
          FC_POSTED:     u2l_fi2_p_seen   = 1;
          FC_NONPOSTED:  u2l_fi2_np_seen  = 1;
          FC_COMPLETION:  u2l_fi2_cpl_seen = 1;
          default: ;
        endcase
      end else begin
        case (txn.fc_type)
          FC_POSTED:     l2u_fi2_p_seen   = 1;
          FC_NONPOSTED:  l2u_fi2_np_seen  = 1;
          FC_COMPLETION:  l2u_fi2_cpl_seen = 1;
          default: ;
        endcase
      end
      if (!fc_init2_complete &&
          u2l_fi2_p_seen && u2l_fi2_np_seen && u2l_fi2_cpl_seen &&
          l2u_fi2_p_seen && l2u_fi2_np_seen && l2u_fi2_cpl_seen) begin
        fc_init2_complete = 1;
        `uvm_info("SHARED_SB", "[MILESTONE] FC_INIT2 complete (P+NP+Cpl both directions)", UVM_LOW)
      end
    end

    // --- ACTIVE milestone ---
    if (/* condition */) begin
      if (fc_init2_complete && !dl_active_reached) begin
        dl_active_reached = 1;
        `uvm_info("SHARED_SB", "[MILESTONE] DL_Active reached", UVM_LOW)
      end
    end
  endfunction



  //---------------------------------------------------------------------
  // Check Phase — drain any remaining items in queues
  //---------------------------------------------------------------------
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);

    // Check for unmatched TX items (sent but never received)
    if (u2l_tx_queue.size() > 0) begin
      `uvm_error("SHARED_SB", $sformatf("[U2L] %0d TX DLLPs never received at Lower RX!",
                 u2l_tx_queue.size()))
      foreach (u2l_tx_queue[i])
        `uvm_info("SHARED_SB", $sformatf("  Unmatched U2L[%0d]: %s",
                  i, u2l_tx_queue[i].convert2string()), UVM_LOW)
    end

    if (l2u_tx_queue.size() > 0) begin
      `uvm_error("SHARED_SB", $sformatf("[L2U] %0d TX DLLPs never received at Upper RX!",
                 l2u_tx_queue.size()))
      foreach (l2u_tx_queue[i])
        `uvm_info("SHARED_SB", $sformatf("  Unmatched L2U[%0d]: %s",
                  i, l2u_tx_queue[i].convert2string()), UVM_LOW)
    end

    // Check for items stuck in TLM FIFOs (monitor sent but run_phase didn't process)
    if (upper_tx_fifo.used() > 0)
      `uvm_warning("SHARED_SB", $sformatf("[U_TX FIFO] %0d items unprocessed", upper_tx_fifo.used()))
    if (lower_rx_fifo.used() > 0)
      `uvm_warning("SHARED_SB", $sformatf("[L_RX FIFO] %0d items unprocessed", lower_rx_fifo.used()))
    if (lower_tx_fifo.used() > 0)
      `uvm_warning("SHARED_SB", $sformatf("[L_TX FIFO] %0d items unprocessed", lower_tx_fifo.used()))
    if (upper_rx_fifo.used() > 0)
      `uvm_warning("SHARED_SB", $sformatf("[U_RX FIFO] %0d items unprocessed", upper_rx_fifo.used()))
  endfunction



  //---------------------------------------------------------------------
  // Report Phase — summary
  //---------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    `uvm_info("SHARED_SB", "============================================", UVM_LOW)
    `uvm_info("SHARED_SB", "   SHARED SCOREBOARD SUMMARY", UVM_LOW)
    `uvm_info("SHARED_SB", "============================================", UVM_LOW)
    `uvm_info("SHARED_SB", $sformatf("  Upper→Lower: TX=%0d  RX=%0d  Match=%0d  Mismatch=%0d",
              u2l_tx_cnt, u2l_rx_cnt, u2l_match_cnt, u2l_mismatch_cnt), UVM_LOW)
    `uvm_info("SHARED_SB", $sformatf("  Lower→Upper: TX=%0d  RX=%0d  Match=%0d  Mismatch=%0d",
              l2u_tx_cnt, l2u_rx_cnt, l2u_match_cnt, l2u_mismatch_cnt), UVM_LOW)
    `uvm_info("SHARED_SB", "--------------------------------------------", UVM_LOW)
    `uvm_info("SHARED_SB", $sformatf("  Milestones:"), UVM_LOW)
    `uvm_info("SHARED_SB", $sformatf("    Feature Exchange : %s", feature_exchange_done ? "DONE" : "NOT DONE"), UVM_LOW)
    `uvm_info("SHARED_SB", $sformatf("    FC_INIT1 Complete: %s", fc_init1_complete     ? "DONE" : "NOT DONE"), UVM_LOW)
    `uvm_info("SHARED_SB", $sformatf("    FC_INIT2 Complete: %s", fc_init2_complete     ? "DONE" : "NOT DONE"), UVM_LOW)
    `uvm_info("SHARED_SB", $sformatf("    DL_Active Reached: %s", dl_active_reached     ? "YES"  : "NO"),       UVM_LOW)
    `uvm_info("SHARED_SB", "============================================", UVM_LOW)

    if (u2l_mismatch_cnt > 0 || l2u_mismatch_cnt > 0)
      `uvm_error("SHARED_SB", $sformatf("TOTAL MISMATCHES: %0d — TEST FAIL",
                 u2l_mismatch_cnt + l2u_mismatch_cnt))
    else
      `uvm_info("SHARED_SB", "All matched — DATA INTEGRITY PASSED", UVM_LOW)
  endfunction

endclass