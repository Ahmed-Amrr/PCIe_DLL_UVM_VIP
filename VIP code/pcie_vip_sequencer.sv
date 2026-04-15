`ifndef PCIE_VIP_TX_SEQUENCER
`define PCIE_VIP_TX_SEQUENCER

class pcie_vip_tx_sequencer extends uvm_sequencer #(pcie_dllp_seq_item);
    `uvm_component_utils(pcie_vip_tx_sequencer)
    
    uvm_analysis_export #(pcie_state_seq_item) sqr_export;     //getting the data from tx monitor
    uvm_tlm_analysis_fifo #(pcie_state_seq_item) sqr_fifo;
    pcie_vip_config cfg;

    dl_state_t state;

    pcie_state_seq_item state_seq_item;

    function new(string name = "pcie_vip_tx_sequencer", uvm_component parent = null);
        super.new(name,parent);
    endfunction //new()

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Get the configuration object to access the configuration registers
        if(!uvm_config_db #(pcie_vip_config)::get(this,"","CFG_ENV",cfg))
          `uvm_fatal("build_phase","unable to get configuration object in sb")

        sqr_export=new("sqr_export",this);
        sqr_fifo=new("sqr_fifo",this);

    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        sqr_export.connect(sqr_fifo.analysis_export);
    endfunction : connect_phase


    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            sqr_fifo.get(state_seq_item);
            state = state_seq_item.vip_state;
        end
    endtask : run_phase


endclass //pcie_vip_tx_sequencer extends uvm_sequencer

`endif // End of include guard