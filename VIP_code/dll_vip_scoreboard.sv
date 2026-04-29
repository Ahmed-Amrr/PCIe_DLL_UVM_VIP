`ifndef DLL_VIP_SCOREBOARD_SV
`define DLL_VIP_SCOREBOARD_SV


// declare analysis imp tags for each monitor
`uvm_analysis_imp_decl(_rx_mon)
`uvm_analysis_imp_decl(_tx_mon)
`uvm_analysis_imp_decl(_sm_mon)

class dll_vip_scoreboard extends uvm_scoreboard;

    // Parameters
    parameter int  DLLP_WIDTH        = 48   ;
    parameter int  PAYLOAD_WIDTH     = 32   ;
    parameter int  CRC_WIDTH         = 16   ;
    parameter time FC_UPDATE_TIMEOUT = 34us ;   // Maximum allowed interval between consecutive FC / DL-Feature DLLPs

    // UVM Factory register
    `uvm_component_utils(dll_vip_scoreboard)

    // Analysis Imports — one per monitor
    uvm_analysis_imp_rx_mon #(pcie_dllp_seq_item,  dll_vip_scoreboard) rx_mon_export;
    uvm_analysis_imp_tx_mon #(pcie_dllp_seq_item,  dll_vip_scoreboard) tx_mon_export;
    uvm_analysis_imp_sm_mon #(pcie_state_seq_item, dll_vip_scoreboard) sm_mon_export;

    
    // Transaction Queues
    pcie_dllp_seq_item  rx_queue[$]           ;   // RX transactions 
    pcie_dllp_seq_item  tx_queue[$]           ;   // TX transactions 
    pcie_state_seq_item sm_queue[$]           ;   // SM transactions 

    pcie_dllp_seq_item  predicted_tx_queue[$] ;   // reference model TX predictions
    pcie_state_seq_item predicted_sm_queue[$] ;   // reference model SM predictions

    
    // Handles
    dll_ref_model   ref_model ;   // reference model instance
    pcie_vip_config cfg       ;   // VIP configuration object

    
    // Scorecard Counters
    int error_count   = 0 ;
    int correct_count = 0 ;

    // Timing Tracking — last observed timestamp per DLLP type
    time last_fc1_p    = 0 ;
    time last_fc1_np   = 0 ;
    time last_fc1_cpl  = 0 ;
    time last_fc2_p    = 0 ;
    time last_fc2_np   = 0 ;
    time last_fc2_cpl  = 0 ;
    time last_upfc_p   = 0 ;
    time last_upfc_np  = 0 ;
    time last_upfc_cpl = 0 ;
    time last_dlf      = 0 ;


    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "dll_vip_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    //==========================================================
    // Build Phase
    //==========================================================
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db #(pcie_vip_config)::get(this, "", "CFG_ENV", cfg))
            `uvm_fatal("build_phase", "unable to get configuration object in scoreboard")

        rx_mon_export = new("rx_mon_export", this);
        tx_mon_export = new("tx_mon_export", this);
        sm_mon_export = new("sm_mon_export", this);

        ref_model     = new();
        ref_model.cfg = cfg;
    endfunction : build_phase

    //==========================================================
    // write() Callbacks for RX Monitor Analysis Ports
    //==========================================================
    // Function: Called when rx monitor sends transaction. This is where ref model is called and predictions are generated
    // Inputs  : DLLP sequence item received from the RX monitor
    virtual function void write_rx_mon(pcie_dllp_seq_item trans);
        pcie_dllp_seq_item  cloned_rx    ;
        pcie_state_seq_item predicted_sm ;
        pcie_dllp_seq_item  predicted_tx ;

        predicted_sm = pcie_state_seq_item::type_id::create("predicted_sm");
        predicted_tx = pcie_dllp_seq_item::type_id::create("predicted_tx");

        if (trans == null) begin
            `uvm_warning("DLL_SB", "write_rx_mon received null transaction")
            return;
        end

        // Clones the incoming item
        $cast(cloned_rx, trans.clone());
        // Enqueues it to rx_queue
        rx_queue.push_back(cloned_rx);
        // Runs a timing check
        timing_check(cloned_rx);

        `uvm_info("DLL_SB", $sformatf("RX Monitor transaction received: %s", cloned_rx.convert2string()), UVM_HIGH)

        `uvm_info("DLL_SB_DEBUG", $sformatf(
            "REF_IN pkt_id=%0d t=%0t dllp=0x%012h top=0x%02h pl_lnk_up=%0b reset=%0b ref_state_before=%s",
            cloned_rx.pkt_id,
            $time,
            cloned_rx.dllp,
            cloned_rx.dllp[47:40],
            cloned_rx.pl_lnk_up,
            cfg.reset,
            ref_model.current_state.name()), UVM_HIGH)

        // Drive the reference model — it predicts the new DLL state and any DL_Up / DL_Down transitions
        ref_model.rx_path(
            ._rx_item              (cloned_rx.dllp               ),
            ._pl_lnk_up            (cloned_rx.pl_lnk_up          ),
            ._dl_reset             (cfg.reset                     ),
            ._pl_valid             (cloned_rx.pl_valid            ),
            ._DL_Down              (predicted_sm.DL_Down          ),
            ._DL_Up                (predicted_sm.DL_Up            ),
            ._surprise_down_event  (predicted_sm.surprise_down_event)
        );

        `uvm_info("DLL_SB_DEBUG", $sformatf("REF_OUT pkt_id=%0d t=%0t ref_state_after=%s", cloned_rx.pkt_id, $time, ref_model.current_state.name()), UVM_HIGH)

        // Capture the post-call state into the prediction item and enqueue it
        predicted_sm.vip_state = ref_model.current_state;
        predicted_sm_queue.push_back(predicted_sm);

        `uvm_info("DLL_SB", $sformatf("Model predicted state=%s DL_Up=%0b DL_Down=%0b",
            predicted_sm.vip_state.name(), predicted_sm.DL_Up, predicted_sm.DL_Down), UVM_MEDIUM)

    endfunction : write_rx_mon


    //==========================================================
    // write() Callbacks for TX Monitor Analysis Ports
    //==========================================================
    // Function: Called by the TX monitor analysis port on every transmitted DLLP transaction.
    // Clones and enqueues the item for future comparison against reference model TX predictions.
    // Inputs  : DLLP sequence item received from the TX monitor
    virtual function void write_tx_mon(pcie_dllp_seq_item trans);
        pcie_dllp_seq_item cloned_tx;

        $cast(cloned_tx, trans.clone());
        tx_queue.push_back(cloned_tx);

        `uvm_info("DLL_SB", $sformatf("TX Monitor transaction received: %s", cloned_tx.convert2string()), UVM_HIGH)

    endfunction : write_tx_mon

    //==========================================================
    // write() Callbacks for SM Monitor Analysis Ports
    //==========================================================
    // Function: Called by the SM monitor analysis port on every state machine transition.
    // Inputs  : state machine sequence item received from the SM monitor
    virtual function void write_sm_mon(pcie_state_seq_item trans);

        if (trans == null) begin
            `uvm_warning("DLL_SB", "write_sm_mon received null transaction")
            return;
        end

        // If a predicted SM transaction is available in the prediction queue, triggers
        // compare_sm_transactions to validate the SM against the reference model.
        if(predicted_sm_queue.size() > 0)
            compare_sm_transactions(trans);

    endfunction : write_sm_mon

    //==========================================================
    // Compare SM Transactions
    //==========================================================    
    // Function: Pops the oldest prediction from predicted_sm_queue and compares it field-by-field
    // against the actual SM transaction reported by the DUT:
    //   Check 1 — vip_state          : DLL state machine state
    //   Check 2 — DL_Up              : data-link-up assertion
    //   Check 3 — DL_Down            : data-link-down assertion
    //   Check 4 — surprise_down_event: unexpected link-down detection
    // Inputs  : trans — actual state sequence item from the SM monitor
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    protected virtual function void compare_sm_transactions(pcie_state_seq_item trans);
        pcie_state_seq_item actual_sm    ;
        pcie_state_seq_item predicted_sm ;

        // actual_sm = pcie_state_seq_item::type_id::create("actual_sm");
        $cast(actual_sm, trans.clone());
        
        predicted_sm = predicted_sm_queue.pop_front();

        `uvm_info("DLL_SB", $sformatf("Comparing SM: predicted state=%s actual state=%s",
            predicted_sm.vip_state.name(), actual_sm.vip_state.name()), UVM_MEDIUM)

        // Check 1: VIP state
        if(actual_sm.vip_state !== predicted_sm.vip_state) begin
            `uvm_error("DLL_SB", $sformatf("[compare_sm] STATE MISMATCH: predicted=%s actual=%s",
                predicted_sm.vip_state.name(), actual_sm.vip_state.name()))
            error_count++;
        end else begin
            `uvm_info("DLL_SB", $sformatf("[compare_sm] STATE OK: %s", actual_sm.vip_state.name()), UVM_MEDIUM)
            correct_count++;
        end

        // Check 2: DL_Up
        if(actual_sm.DL_Up !== predicted_sm.DL_Up) begin
            `uvm_error("DLL_SB", $sformatf("[compare_sm] DL_Up MISMATCH: predicted=%0b actual=%0b",
                predicted_sm.DL_Up, actual_sm.DL_Up))
            error_count++;
        end else begin
            `uvm_info("DLL_SB", $sformatf("[compare_sm] DL_Up OK: %0b", actual_sm.DL_Up), UVM_MEDIUM)
            correct_count++;
        end

        // Check 3: DL_Down
        if(actual_sm.DL_Down !== predicted_sm.DL_Down) begin
            `uvm_error("DLL_SB", $sformatf("[compare_sm] DL_Down MISMATCH: predicted=%0b actual=%0b",
                predicted_sm.DL_Down, actual_sm.DL_Down))
            error_count++;
        end else begin
            `uvm_info("DLL_SB", $sformatf("[compare_sm] DL_Down OK: %0b", actual_sm.DL_Down), UVM_MEDIUM)
            correct_count++;
        end

        // Check 4: Surprise Down Event
        if(actual_sm.surprise_down_event !== predicted_sm.surprise_down_event) begin
            `uvm_error("DLL_SB", $sformatf("[compare_sm] SURPRISE_DOWN MISMATCH: predicted=%0b actual=%0b",
                predicted_sm.surprise_down_event, actual_sm.surprise_down_event))
            error_count++;
        end else begin
            `uvm_info("DLL_SB", "[compare_sm] SURPRISE_DOWN OK", UVM_MEDIUM)
            correct_count++;
        end

    endfunction : compare_sm_transactions

    //==========================================================
    // Timing Check
    //==========================================================
    // Function: compares the current simulation time against the last recorded timestamp for that
    // DLLP type. Reports a uvm_error if the gap exceeds FC_UPDATE_TIMEOUT.
    // Inputs  : txn — DLLP sequence item to be checked
    protected virtual function void timing_check(pcie_dllp_seq_item txn);
        case(txn.dllp[47:40])

            INITFC1_P: begin
                if(last_fc1_p != 0 && ($time - last_fc1_p) > FC_UPDATE_TIMEOUT)
                    `uvm_error("FC_TIMEOUT", $sformatf("InitFC1-P timeout: %0t", $time - last_fc1_p))
                last_fc1_p = $time;
            end

            INITFC1_NP: begin
                if(last_fc1_np != 0 && ($time - last_fc1_np) > FC_UPDATE_TIMEOUT)
                    `uvm_error("FC_TIMEOUT", $sformatf("InitFC1-NP timeout: %0t", $time - last_fc1_np))
                last_fc1_np = $time;
            end

            INITFC1_CPL: begin
                if(last_fc1_cpl != 0 && ($time - last_fc1_cpl) > FC_UPDATE_TIMEOUT)
                    `uvm_error("FC_TIMEOUT", $sformatf("InitFC1-CPL timeout: %0t", $time - last_fc1_cpl))
                last_fc1_cpl = $time;
            end

            INITFC2_P: begin
                if(last_fc2_p != 0 && ($time - last_fc2_p) > FC_UPDATE_TIMEOUT)
                    `uvm_error("FC_TIMEOUT", $sformatf("InitFC2-P timeout: %0t", $time - last_fc2_p))
                last_fc2_p = $time;
            end

            INITFC2_NP: begin
                if(last_fc2_np != 0 && ($time - last_fc2_np) > FC_UPDATE_TIMEOUT)
                    `uvm_error("FC_TIMEOUT", $sformatf("InitFC2-NP timeout: %0t", $time - last_fc2_np))
                last_fc2_np = $time;
            end

            INITFC2_CPL: begin
                if(last_fc2_cpl != 0 && ($time - last_fc2_cpl) > FC_UPDATE_TIMEOUT)
                    `uvm_error("FC_TIMEOUT", $sformatf("InitFC2-CPL timeout: %0t", $time - last_fc2_cpl))
                last_fc2_cpl = $time;
            end

            UPDATEFC_P: begin
                if(last_upfc_p != 0 && ($time - last_upfc_p) > FC_UPDATE_TIMEOUT)
                    `uvm_error("FC_TIMEOUT", $sformatf("UpdateFC-P timeout: %0t", $time - last_upfc_p))
                last_upfc_p = $time;
            end

            UPDATEFC_NP: begin
                if(last_upfc_np != 0 && ($time - last_upfc_np) > FC_UPDATE_TIMEOUT)
                    `uvm_error("FC_TIMEOUT", $sformatf("UpdateFC-NP timeout: %0t", $time - last_upfc_np))
                last_upfc_np = $time;
            end

            UPDATEFC_CPL: begin
                if(last_upfc_cpl != 0 && ($time - last_upfc_cpl) > FC_UPDATE_TIMEOUT)
                    `uvm_error("FC_TIMEOUT", $sformatf("UpdateFC-CPL timeout: %0t", $time - last_upfc_cpl))
                last_upfc_cpl = $time;
            end

            DL_FEATURE: begin
                if(last_dlf != 0 && ($time - last_dlf) > FC_UPDATE_TIMEOUT)
                    `uvm_error("DLF_TIMEOUT", $sformatf("DL Feature DLLP interval exceeded: %0t", $time - last_dlf))
                last_dlf = $time;
            end

            default: begin
                // Unrecognised DLLP type — reset all interval trackers
                last_fc1_p    = 0 ;
                last_fc1_np   = 0 ;
                last_fc1_cpl  = 0 ;
                last_fc2_p    = 0 ;
                last_fc2_np   = 0 ;
                last_fc2_cpl  = 0 ;
                last_upfc_p   = 0 ;
                last_upfc_np  = 0 ;
                last_upfc_cpl = 0 ;
                last_dlf      = 0 ;
            end

        endcase
    endfunction : timing_check

    //==========================================================
    // Report Phase
    //==========================================================
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info("DLL_SB", "========== DLL Scoreboard Results ==========", UVM_LOW)
        `uvm_info("DLL_SB", $sformatf("Total PASSED checks: %0d", correct_count), UVM_LOW)
        `uvm_info("DLL_SB", $sformatf("Total FAILED checks: %0d", error_count  ), UVM_LOW)

        if(error_count == 0 && correct_count > 0)
            `uvm_info("DLL_SB", "*** DLL TEST PASSED ***", UVM_LOW)
        else
            `uvm_error("DLL_SB", "*** DLL TEST FAILED ***")

    endfunction : report_phase

endclass : dll_vip_scoreboard

`endif // DLL_VIP_SCOREBOARD_SV