`ifndef PCIE_VIP_TX_SEQUENCER
`define PCIE_VIP_TX_SEQUENCER

class pcie_vip_tx_sequencer extends uvm_sequencer #(pcie_dllp_seq_item);
    `uvm_component_utils(pcie_vip_tx_sequencer)
    function new(string name = "pcie_vip_tx_sequencer", uvm_component parent = null);
        super.new(name,parent);
    endfunction //new()
endclass //pcie_vip_tx_sequencer extends uvm_sequencer

`endif // End of include guard