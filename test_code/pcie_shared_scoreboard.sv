`ifndef PCIE_SHARED_SCOREBOARD
`define PCIE_SHARED_SCOREBOARD

class pcie_shared_scoreboard extends uvm_scoreboard;
    // UVM Factory register
    `uvm_component_utils(pcie_shared_scoreboard)

    
    //  ANALYSIS FIFOs 
    uvm_tlm_analysis_fifo #(pcie_dllp_seq_item)  upper_tx_fifo;   // Upper TX monitor 
    uvm_tlm_analysis_fifo #(pcie_dllp_seq_item)  upper_rx_fifo;   // Upper RX monitor
    uvm_tlm_analysis_fifo #(pcie_dllp_seq_item)  lower_tx_fifo;   // Lower TX monitor 
    uvm_tlm_analysis_fifo #(pcie_dllp_seq_item)  lower_rx_fifo;   // Lower RX monitor 

    uvm_tlm_analysis_fifo #(pcie_state_seq_item)  upper_sm_fifo;   // Upper SM 
    uvm_tlm_analysis_fifo #(pcie_state_seq_item)  lower_sm_fifo;   // Lower SM 

    
    //  Internal Matching Queues
    pcie_dllp_seq_item  u2l_queue[$];
    pcie_dllp_seq_item  l2u_queue[$];

    
    //  State Pair Tracking
    dl_state_t  upper_state;
    dl_state_t  lower_state;

    
    //  Statistics
    int  u2l_matches;
    int  u2l_mismatches;
    int  u2l_drops;       

    int  l2u_matches;
    int  l2u_mismatches;
    int  l2u_drops;

    int  state_pair_checks;
    int  illegal_pair_count;

    
    //  Timing Check
    localparam time RX_TIMEOUT        = 1000us;


    time tx_u_time;
    time tx_l_time;
    time rx_u_time;
    time rx_l_time;

    time last_upper_sm_activity;
    time last_lower_sm_activity ;

    
    //  Constructor
    function new(string name = "pcie_shared_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction


    
    //  Build Phase
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
        u2l_matches    = 0;  u2l_mismatches = 0;  u2l_drops   = 0;  
        l2u_matches    = 0;  l2u_mismatches = 0;  l2u_drops   = 0;  
        state_pair_checks = 0;  illegal_pair_count = 0;
    endfunction


    
    //  Run Phase 
    task run_phase(uvm_phase phase);
        fork
        process_upper_tx();       // Thread 1: Upper TX → enqueue into u2l_queue
        process_lower_rx();       // Thread 2: Lower RX → match against u2l_queue
        process_lower_tx();       // Thread 3: Lower TX → enqueue into l2u_queue
        process_upper_rx();       // Thread 4: Upper RX → match against l2u_queue
        process_upper_sm();       // Thread 5: Upper SM state transitions
        process_lower_sm();       // Thread 6: Lower SM state transitions
        join_none
    endtask

    // Task    : process_upper_tx
    // Inputs  : TX DLLP transactions from upper layer
    // Outputs : None
    // Description:
    // This task continuously receives TX DLLP transactions from the upper layer FIFO.
    // Each received transaction is logged and pushed into the U2L queue for further processing.
    task process_upper_tx();
    pcie_dllp_seq_item txn;
    forever begin
        // Get transaction from upper layer FIFO
        upper_tx_fifo.get(txn);
        `uvm_info(get_type_name(), $sformatf("[U2L-TX] Enqueued Upper TX: %s", txn.convert2string()), UVM_HIGH)

        // Store transaction in U2L queue
        u2l_queue.push_back(txn);

        // Capture transmission time
        tx_u_time = $time;
    end
    endtask


    
    // Task    : process_lower_rx
    // Inputs  : RX DLLP transactions from lower layer
    // Outputs : None
    // Description:
    // This task continuously receives RX DLLP transactions from the lower layer FIFO.
    // If an RX transaction is received, its arrival time is recorded and it is passed for matching.
    // If no RX is received within RX_TIMEOUT, an error is reported.
    task process_lower_rx();
        pcie_dllp_seq_item rx_txn;
        forever begin
            // Wait for RX packet or timeout
            time start_time = tx_u_time;
            forever begin
                // Try to get RX with small step
                if(lower_rx_fifo.try_get(rx_txn)) begin
                    rx_l_time = $time; // store RX arrival time
                    `uvm_info(get_type_name(),
                        $sformatf("[U2L-RX] Received Lower RX: %s at time %0t", rx_txn.convert2string(), rx_l_time),
                        UVM_HIGH);
                    match_u2l(rx_txn); // process RX
                    break; // exit inner loop after RX received
                end
                // Timeout check
                if($time - start_time >= RX_TIMEOUT) begin
                    `uvm_error(get_type_name(),
                        $sformatf("[U2L-RX] Timeout! No RX received within %0t", RX_TIMEOUT));
                    break; // exit inner loop after timeout
                end
                //Avoid zero-time busy spinning when FIFO is empty
                #1step;
            end
        end
    endtask


    
    // Task    : process_lower_tx
    // Inputs  : TX DLLP transactions from upper layer
    // Outputs : None
    // Description:
    // This task continuously receives TX DLLP transactions from the lower layer FIFO.
    // Each received transaction is logged and pushed into the L2U queue for further processing.
    task process_lower_tx();
        pcie_dllp_seq_item txn;
        forever begin
        // Get transaction from lower layer FIFO
        lower_tx_fifo.get(txn);
        `uvm_info(get_type_name(), $sformatf("[L2U-TX] Enqueued Lower TX: %s", txn.convert2string()), UVM_HIGH)

        // Store transaction in U2L queue
        l2u_queue.push_back(txn);

        // Capture transmission time
        tx_l_time = $time;
        end
    endtask


    
    // Task    : process_upper_rx
    // Inputs  : RX DLLP transactions from upper layer
    // Outputs : None
    // Description:
    // This task continuously receives RX DLLP transactions from the upper layer FIFO.
    // If an RX transaction is received, its arrival time is recorded and it is passed for matching.
    // If no RX is received within RX_TIMEOUT, an error is reported.
    task process_upper_rx();
        pcie_dllp_seq_item rx_txn;
        forever begin
            // Wait for RX packet or timeout
            time start_time = tx_l_time;
            forever begin
                // Try to get RX with small step
                if(upper_rx_fifo.try_get(rx_txn)) begin
                    rx_u_time = $time; // store RX arrival time
                    `uvm_info(get_type_name(), $sformatf("[L2U-RX] Received UPPER RX: %s at time %0t", rx_txn.convert2string(), rx_u_time),UVM_HIGH)
                    match_l2u(rx_txn); // process RX
                    break; // exit inner loop after RX received
                end
                // Timeout check
                if($time - start_time >= RX_TIMEOUT) begin
                    `uvm_error(get_type_name(), $sformatf("[L2U-RX] Timeout! No RX received within %0t", RX_TIMEOUT));
                    break; // exit inner loop after timeout
                end
                //Avoid zero-time busy spinning when FIFO is empty
                #1step;
            end
        end
    endtask


    
    //  Upper SM — state pair validation
    task process_upper_sm();
        pcie_state_seq_item sm_txn;
        forever begin
        upper_sm_fifo.get(sm_txn);
        last_upper_sm_activity = $time;
        upper_state = sm_txn.vip_state;
        `uvm_info(get_type_name(), $sformatf("[SM-UPPER] %s ", sm_txn.vip_state.name()), UVM_MEDIUM)
        validate_state_pair();
        end
    endtask


    
    //  Lower SM — state pair validation
    task process_lower_sm();
        pcie_state_seq_item sm_txn;
        forever begin
        lower_sm_fifo.get(sm_txn);
        last_lower_sm_activity = $time;
        lower_state = sm_txn.vip_state;
        `uvm_info(get_type_name(), $sformatf("[SM-LOWER] %s ", sm_txn.vip_state.name()), UVM_MEDIUM)
        validate_state_pair();
        end
    endtask

    
    //  Match Logic
    function void match_u2l(pcie_dllp_seq_item rx_item);
        pcie_dllp_seq_item tx_item;
        int match_idx = -1;

        foreach (u2l_queue[i]) begin
        if (u2l_queue[i].dllp === rx_item.dllp) begin
            match_idx = i;
            break;
        end
        end

        if (match_idx == -1) begin
        u2l_mismatches++;
        `uvm_error(get_type_name(),
            $sformatf("[U2L-CORRUPT] No matching TX found for RX: 0x%012h", rx_item.dllp))
        return;
        end

        tx_item = u2l_queue[match_idx];
        u2l_queue.delete(match_idx);
        u2l_matches++;
        `uvm_info(get_type_name(),
        $sformatf("[U2L-MATCH] OK. TX: 0x%012h", tx_item.dllp), UVM_MEDIUM)
    endfunction

    function void match_l2u(pcie_dllp_seq_item rx_item);
    pcie_dllp_seq_item tx_item;
    int match_idx = -1;
    foreach (l2u_queue[i]) begin
        if (l2u_queue[i].dllp === rx_item.dllp) begin
        match_idx = i;
        break;
        end
    end

    if (match_idx == -1) begin
        l2u_mismatches++;
        `uvm_error(get_type_name(),
        $sformatf("[L2U-CORRUPT] No matching TX found for RX: 0x%012h", rx_item.dllp))
        return;
    end

    tx_item = l2u_queue[match_idx];
    l2u_queue.delete(match_idx);
    l2u_matches++;
    `uvm_info(get_type_name(),
        $sformatf("[L2U-MATCH] OK. TX: 0x%012h", tx_item.dllp), UVM_MEDIUM)
    endfunction


    
    //  State Pair Validation
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
            return (lower_state == DL_INACTIVE ||
                    lower_state == DL_FEATURE ||
                    lower_state == DL_INIT1);
            end

            DL_FEATURE: begin
            return (lower_state == DL_INACTIVE||
                    lower_state == DL_FEATURE ||
                    lower_state == DL_INIT1);
            end

            DL_INIT1: begin
            return (lower_state == DL_INACTIVE||
                    lower_state == DL_FEATURE ||
                    lower_state == DL_INIT1 ||
                    lower_state == DL_INIT2);
            end

            DL_INIT2: begin
            return (lower_state == DL_INACTIVE||
                    lower_state == DL_INIT1 ||
                    lower_state == DL_INIT2 ||
                    lower_state == DL_ACTIVE);
            end

            DL_ACTIVE: begin
            return (lower_state == DL_INACTIVE||
                    lower_state == DL_INIT2 ||
                    lower_state == DL_ACTIVE);
            end

            default: return 0;
        endcase
    endfunction



    
    //  Report Phase — summary
    function void report_phase(uvm_phase phase);
        string report;
        super.report_phase(phase);

        report = "\n==== PCIe Shared Scoreboard Report ====\n";

        report = {report, $sformatf("\nU2L:\n")};
        report = {report, $sformatf("  Matches    : %0d\n", u2l_matches)};
        report = {report, $sformatf("  Mismatches : %0d (corruption)\n", u2l_mismatches)};

        report = {report, $sformatf("\nL2U:\n")};
        report = {report, $sformatf("  Matches    : %0d\n", l2u_matches)};
        report = {report, $sformatf("  Mismatches : %0d (corruption)\n", l2u_mismatches)};

        report = {report, $sformatf("\nState Pair Check:\n")};
        report = {report, $sformatf("  Total   : %0d\n", state_pair_checks)};
        report = {report, $sformatf("  Illegal : %0d\n", illegal_pair_count)};

        report = {report, "======================================\n"};
        `uvm_info(get_type_name(), {report, "  * SCOREBOARD Check *"}, UVM_LOW)
    endfunction

endclass
`endif