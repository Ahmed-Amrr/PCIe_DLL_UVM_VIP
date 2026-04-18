`ifndef PCIE_VIP_TX_SEQUENCER
`define PCIE_VIP_TX_SEQUENCER

class pcie_vip_tx_sequencer extends uvm_sequencer #(pcie_dllp_seq_item);
    `uvm_component_utils(pcie_vip_tx_sequencer)
    
    uvm_analysis_imp #(pcie_state_seq_item, pcie_vip_tx_sequencer) sqr_export;     
    pcie_vip_config cfg;
    dl_state_t state;
    pcie_base_seq seq;


    function new(string name = "pcie_vip_tx_sequencer", uvm_component parent = null);
        super.new(name,parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Get the configuration object to access the configuration registers
        if(!uvm_config_db #(pcie_vip_config)::get(this,"","CFG_ENV",cfg))
          `uvm_fatal("build_phase","unable to get configuration object in sb")

        sqr_export = new("sqr_export",this);

    endfunction : build_phase

    
    task run_phase(uvm_phase phase);

        forever begin
            // wait until the state changes 
            @(state) ;     
            case (state)
                DL_INACTIVE : seq = pcie_inactive_seq::type_id::create("seq");
                DL_FEATURE  : seq = pcie_feature_sequence::type_id::create("seq");
                DL_INIT1    : seq = pcie_fc_init1_seq::type_id::create("seq");
                DL_INIT2    : seq = pcie_fc_init2_seq::type_id::create("seq");
                DL_ACTIVE   : seq = pcie_active_seq::type_id::create("seq");
                default     : `uvm_warning("SQR", $sformatf("Unhandled state: %s", state.name()))
            endcase
            seq.start(this);
        end

    endtask : run_phase

    function void write (pcie_state_seq_item item);
        state = item.state;
    endfunction

endclass : pcie_vip_tx_sequencer 


`endif 



