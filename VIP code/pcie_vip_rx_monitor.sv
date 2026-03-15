`ifndef PCIE_VIP_RX_MONITOR
`define PCIE_VIP_RX_MONITOR

class pcie_vip_rx_monitor extends uvm_monitor;
/*-------------------------------------------------------------------------------
-- UVM Factory register
-------------------------------------------------------------------------------*/
	// Provide implementations of virtual methods such as get_type_name and create
	`uvm_component_utils(pcie_vip_rx_monitor)

/*-------------------------------------------------------------------------------
-- Interface, port, fields
-------------------------------------------------------------------------------*/

    // virtual lpif_if lpif_vif
    // seq_item   dll_item & tlp ???
	uvm_analysis_port #(/*seq_item*/) rx_mon_ap;

/*-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------*/
	// Constructor
	function new(string name = "pcie_vip_rx_monitor", uvm_component parent=null);
		super.new(name, parent);
	endfunction : new

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		rx_mon_ap=new("rx_mon_ap", this);
	endfunction : build_phase

	task run_phase(uvm_phase phase);	//check the names for vif & seq_item & variables
		super.run_phase(phase);
		forever begin
			// Read the signals in Seq_Item and write in tx_mon_ap
		end
	endtask : run_phase

endclass : pcie_vip_rx_monitor

`endif 