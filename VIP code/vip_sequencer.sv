`ifndef VIP_TX_SEQUENCER
`define VIP_TX_SEQUENCER

class vip_tx_sequencer extends uvm_sequencer #(vip_seq_item);
    `uvm_component_utils(vip_tx_sequencer)
    function new(string name = "vip_tx_sequencer", uvm_component parent = null);
        super.new(name,parent);
    endfunction //new()
endclass //vip_tx_sequencer extends uvm_sequencer

`endif // End of include guard