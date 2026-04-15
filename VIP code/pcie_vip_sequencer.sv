`ifndef PCIE_VIP_TX_SEQUENCER
`define PCIE_VIP_TX_SEQUENCER

class pcie_vip_tx_sequencer extends uvm_sequencer #(pcie_dllp_seq_item);
    `uvm_component_utils(pcie_vip_tx_sequencer)
    
    uvm_analysis_export #(pcie_state_seq_item) sqr_export;     //getting the data from tx monitor ???
    uvm_tlm_analysis_fifo #(pcie_state_seq_item) sqr_fifo;
    pcie_vip_config cfg;
    dl_state_t state;

    function new(string name = "pcie_vip_tx_sequencer", uvm_component parent = null);
        super.new(name,parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Get the configuration object to access the configuration registers
        if(!uvm_config_db #(pcie_vip_config)::get(this,"","CFG_ENV",cfg))
          `uvm_fatal("build_phase","unable to get configuration object in sb")

        sqr_export = new("sqr_export",this);
        sqr_fifo   = new("sqr_fifo",this);

    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        sqr_export.connect(sqr_fifo.analysis_export);
    endfunction : connect_phase
    
    task run_phase(uvm_phase phase);
        pcie_state_seq_item state_item;
        pcie_base_seq       seq       ;
        forever begin
            // wait until the state changes
            sqr_fifo.get(state_item);       
            state = state_item.state;        
            case (state)
                DL_INACTIVE : seq = pcie_inactive_sequence::type_id::create("seq");
                DL_FEATURE  : seq = pcie_feature_sequence::type_id::create("seq");
                DL_INIT1    : seq = pcie_fc_init1_seq::type_id::create("seq");
                DL_INIT2    : seq = pcie_fc_init2_seq::type_id::create("seq");
                DL_ACTIVE   : seq = pcie_active_seq::type_id::create("seq");
                default     : `uvm_warning("SQR", $sformatf("Unhandled state: %s", state.name()))
            endcase
            seq.start(this);
        end

    endtask : run_phase

endclass : pcie_vip_tx_sequencer 


`endif 



