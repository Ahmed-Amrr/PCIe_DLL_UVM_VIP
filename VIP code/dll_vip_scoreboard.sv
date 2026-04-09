`ifndef DLL_VIP_SCOREBOARD_SV
`define DLL_VIP_SCOREBOARD_SV

// declare analysis imp tags for each monitor
`uvm_analysis_imp_decl(_rx_mon)
`uvm_analysis_imp_decl(_tx_mon)
`uvm_analysis_imp_decl(_sm_mon)

class dll_vip_scoreboard extends uvm_scoreboard;

    parameter int DLLP_WIDTH    = 48;
    parameter int PAYLOAD_WIDTH = 32;
    parameter int CRC_WIDTH     = 16;

    `uvm_component_utils(dll_vip_scoreboard)

    uvm_analysis_imp_rx_mon #(pcie_dllp_seq_item, dll_vip_scoreboard) rx_mon_export;
    uvm_analysis_imp_tx_mon #(pcie_dllp_seq_item, dll_vip_scoreboard) tx_mon_export;
    uvm_analysis_imp_sm_mon #(pcie_state_seq_item, dll_vip_scoreboard) sm_mon_export;

   
    pcie_dllp_seq_item rx_queue[$];
    pcie_dllp_seq_item tx_queue[$];
    pcie_state_seq_item   sm_queue[$];

    pcie_dllp_seq_item predicted_tx_queue[$];
    pcie_state_seq_item   predicted_sm_queue[$];

    // Reference Model Instance
    dll_ref_model ref_model;

    // Counters
    int error_count   = 0;
    int correct_count = 0;

    
    function new(string name = "dll_vip_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        rx_mon_export = new("rx_mon_export", this);
        tx_mon_export = new("tx_mon_export", this);
        sm_mon_export = new("sm_mon_export", this);
        ref_model = new();
    endfunction : build_phase

    // Function : write_rx_mon
    // Called when rx monitor sends transaction. This is where ref model is called and predictions are generated
    virtual function void write_rx_mon(pcie_dllp_seq_item trans);
        pcie_dllp_seq_item cloned_rx;
        pcie_state_seq_item   predicted_sm;
        pcie_dllp_seq_item predicted_tx;

        // create predicted sm transaction
        predicted_sm = pcie_state_seq_item::type_id::create("predicted_sm");
        // create predicted tx transaction
        predicted_tx = pcie_dllp_seq_item::type_id::create("predicted_tx");

        // clone transaction
        $cast(cloned_rx, trans.clone());
        rx_queue.push_back(cloned_rx);

        `uvm_info("DLL_SB", $sformatf("RX Monitor transaction received: %s", cloned_rx.convert2string()), UVM_HIGH)

        // Call Reference Model rx_path
        // Model processes received DLLP and predicts:
        // 1. Expected state + DL_Up/Down for THIS cycle
        // 2. Expected tx response for NEXT cycle
        ref_model.rx_path(
            ._rx_item       (cloned_rx.dllp),
            ._pl_lnk_up     (cloned_rx.pl_lnk_up),
            ._dl_reset      (cloned_rx.reset),
            ._link_not_disabled(cloned_rx.link_not_disabled),
            ._surprise_down_Error_Reporting_capable(cloned_rx.surprise_down_capable),
            ._DL_Down       (predicted_sm.DL_Down),
            ._DL_Up         (predicted_sm.DL_Up),
            ._surprise_down_event(predicted_sm.surprise_down_event)
        );
        // get predicted state from model
        predicted_sm.vip_state = ref_model.current_state;
        // store predicted sm for comparison with actual sm monitor output
        predicted_sm_queue.push_back(predicted_sm);

        `uvm_info("DLL_SB", $sformatf("Model predicted state=%s DL_Up=%0b DL_Down=%0b", predicted_sm.vip_state.name(), predicted_sm.DL_Up, predicted_sm.DL_Down), UVM_MEDIUM)

        // get predicted tx response from model
        ref_model.predict_expected_tx_response(.current_state(ref_model.current_state), .expected_type(predicted_tx.dllp_type));

        // store predicted tx for comparison with actual tx monitor output
        predicted_tx_queue.push_back(predicted_tx);

        `uvm_info("DLL_SB",$sformatf("Model predicted TX type=%s", predicted_tx.dllp_type.name()), UVM_MEDIUM)

        // try to compare sm if actual available
        if(sm_queue.size() > 0)
            compare_sm_transactions();

    endfunction : write_rx_mon

    // Function : write_tx_mon
    // Called when tx monitor sends transaction. Stores in queue and tries to compare with predicted tx from model
    virtual function void write_tx_mon(pcie_dllp_seq_item trans);
        pcie_dllp_seq_item cloned_tx;

        // clone transaction
        $cast(cloned_tx, trans.clone());
        tx_queue.push_back(cloned_tx);

        `uvm_info("DLL_SB", $sformatf("TX Monitor transaction received: %s", cloned_tx.convert2string()), UVM_HIGH)

        // try to compare if predicted tx available
        if(predicted_tx_queue.size() > 0)
            compare_tx_transactions();

    endfunction : write_tx_mon

    // write_sm_mon
    // Called when sm monitor sends transaction. Stores in queue and tries to compare with predicted sm from model
    virtual function void write_sm_mon(pcie_state_seq_item trans);
        pcie_state_seq_item cloned_sm;

        // clone transaction
        $cast(cloned_sm, trans.clone());
        sm_queue.push_back(cloned_sm);

        `uvm_info("DLL_SB", $sformatf("SM Monitor transaction received: %s", cloned_sm.convert2string()), UVM_HIGH)

        // try to compare if predicted sm available
        if(predicted_sm_queue.size() > 0)
            compare_sm_transactions();

    endfunction : write_sm_mon

    //==========================================================
    // Compare Functions
    //==========================================================

    
    // Function : compare_sm_transactions
    // Compares predicted state + DL_Up/Down from model against actual from sm monitor
    protected virtual function void compare_sm_transactions();
        pcie_state_seq_item actual_sm;
        pcie_state_seq_item predicted_sm;

        actual_sm    = sm_queue.pop_front();
        predicted_sm = predicted_sm_queue.pop_front();

        `uvm_info("DLL_SB", $sformatf("Comparing SM: predicted state=%s actual state=%s", predicted_sm.vip_state.name(), actual_sm.vip_state.name()), UVM_MEDIUM)

        // Check 1: State correct?
        if(actual_sm.vip_state !== predicted_sm.vip_state) begin
            `uvm_error("DLL_SB", $sformatf("[compare_sm] STATE MISMATCH: predicted=%s actual=%s", predicted_sm.vip_state.name(), actual_sm.vip_state.name()))
            error_count++;
        end
        else begin
            `uvm_info("DLL_SB", $sformatf("[compare_sm] STATE OK: %s", actual_sm.vip_state.name()), UVM_MEDIUM)
            correct_count++;
        end

        // Check 2: DL_Up correct?
        if(actual_sm.DL_Up !== predicted_sm.DL_Up) begin
            `uvm_error("DLL_SB", $sformatf("[compare_sm] DL_Up MISMATCH: predicted=%0b actual=%0b", predicted_sm.DL_Up, actual_sm.DL_Up))
            error_count++;
        end
        else begin
            `uvm_info("DLL_SB", $sformatf("[compare_sm] DL_Up OK: %0b", actual_sm.DL_Up), UVM_MEDIUM)
            correct_count++;
        end

        // Check 3: DL_Down correct?
        if(actual_sm.DL_Down !== predicted_sm.DL_Down) begin
            `uvm_error("DLL_SB", $sformatf("[compare_sm] DL_Down MISMATCH: \predicted=%0b actual=%0b", predicted_sm.DL_Down, actual_sm.DL_Down))
            error_count++;
        end
        else begin
            `uvm_info("DLL_SB", $sformatf("[compare_sm] DL_Down OK: %0b", actual_sm.DL_Down), UVM_MEDIUM)
            correct_count++;
        end

        // Check 4: Surprise Down Event correct?
        if(actual_sm.surprise_down_event !== predicted_sm.surprise_down_event) begin
            `uvm_error("DLL_SB", $sformatf("[compare_sm] SURPRISE_DOWN MISMATCH: \ predicted=%0b actual=%0b", predicted_sm.surprise_down_event, actual_sm.surprise_down_event))
            error_count++;
        end
        else begin
            `uvm_info("DLL_SB", "[compare_sm] SURPRISE_DOWN OK", UVM_MEDIUM)
            correct_count++;
        end

    endfunction : compare_sm_transactions

    // Function : compare_tx_transactions
    // Compares predicted tx DLLP from model against actual tx from tx monitor
    protected virtual function void compare_tx_transactions();
        pcie_dllp_seq_item actual_tx;
        pcie_dllp_seq_item predicted_tx;

        actual_tx    = tx_queue.pop_front();
        predicted_tx = predicted_tx_queue.pop_front();

        `uvm_info("DLL_SB", $sformatf("Comparing TX: predicted type=%s actual type=%s", predicted_tx.dllp_type.name(), actual_tx.dllp_type.name()), UVM_MEDIUM)

        // Check 1: TX DLLP type correct?
        if(actual_tx.dllp_type !== predicted_tx.dllp_type) begin
            `uvm_error("DLL_SB", $sformatf("[compare_tx] TYPE MISMATCH: \ predicted=%s actual=%s", predicted_tx.dllp_type.name(), actual_tx.dllp_type.name()))
            error_count++;
        end
        else begin
            `uvm_info("DLL_SB", $sformatf("[compare_tx] TYPE OK: %s", actual_tx.dllp_type.name()), UVM_MEDIUM)
            correct_count++;
        end

        // Check 2: TX DLLP fields correct?
        // I removed this part from line 90 as we said that we will do the prediction for type field inside the ref model 
        // but for other bits, we aren't sure where to add this prediction logic (ref? or sb?)
        if(actual_tx.dllp !== predicted_tx.dllp) begin
            `uvm_error("DLL_SB", $sformatf("[compare_tx] FIELDS MISMATCH: \ predicted=0x%0h actual=0x%0h", predicted_tx.dllp, actual_tx.dllp))
            error_count++;
        end
        else begin
            `uvm_info("DLL_SB", $sformatf("[compare_tx] FIELDS OK: 0x%0h",actual_tx.dllp), UVM_MEDIUM)
            correct_count++;
        end

    endfunction : compare_tx_transactions

    //==========================================================
    // Check Phase
    // verify no leftover transactions in queues
    //==========================================================
    function void check_phase(uvm_phase phase);
        super.check_phase(phase);

        if(rx_queue.size() != 0) begin
            `uvm_error("DLL_SB", $sformatf("RX queue not empty! \ %0d transactions remaining", rx_queue.size()))
        end
        if(tx_queue.size() != 0) begin
            `uvm_error("DLL_SB", $sformatf("TX queue not empty! \ %0d transactions remaining", tx_queue.size()))
        end
        if(sm_queue.size() != 0) begin
            `uvm_error("DLL_SB", $sformatf("SM queue not empty! \ %0d transactions remaining", sm_queue.size()))
        end
        if(predicted_tx_queue.size() != 0) begin
            `uvm_error("DLL_SB", $sformatf("Predicted TX queue not empty! \ %0d transactions remaining", predicted_tx_queue.size()))
        end
        if(predicted_sm_queue.size() != 0) begin
            `uvm_error("DLL_SB", $sformatf("Predicted SM queue not empty! \ %0d transactions remaining", predicted_sm_queue.size()))
        end

    endfunction : check_phase

    //==========================================================
    // Report Phase
    //==========================================================
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info("DLL_SB", "========== DLL Scoreboard Results ==========", UVM_LOW)
        `uvm_info("DLL_SB",$sformatf("Total PASSED checks: %0d", correct_count), UVM_LOW)
        `uvm_info("DLL_SB", $sformatf("Total FAILED checks: %0d", error_count), UVM_LOW)

        if(error_count == 0 && correct_count > 0) begin
            `uvm_info("DLL_SB", "*** DLL TEST PASSED ***", UVM_LOW)
        end
        else begin
            `uvm_error("DLL_SB", "*** DLL TEST FAILED ***")
        end
    endfunction : report_phase

endclass : dll_vip_scoreboard

`endif // DLL_VIP_SCOREBOARD_SV