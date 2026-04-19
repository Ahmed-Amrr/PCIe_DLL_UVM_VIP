`ifndef PCIE_VIP_TX_MONITOR
`define PCIE_VIP_TX_MONITOR

class pcie_vip_tx_monitor extends uvm_monitor;
/*-------------------------------------------------------------------------------
-- UVM Factory register
-------------------------------------------------------------------------------*/
	// Provide implementations of virtual methods such as get_type_name and create
	`uvm_component_utils(pcie_vip_tx_monitor)

/*-------------------------------------------------------------------------------
-- Interface, port, fields
-------------------------------------------------------------------------------*/

    virtual lpif_if lpif_vif;
    pcie_dllp_seq_item seq_item_tx_mon;
	uvm_analysis_port #(pcie_dllp_seq_item) tx_mon_ap;

/*-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------*/
	// Constructor
	function new(string name = "pcie_vip_tx_monitor", uvm_component parent=null);
		super.new(name, parent);
	endfunction : new

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		tx_mon_ap=new("tx_mon_ap", this);
	endfunction : build_phase

	task run_phase(uvm_phase phase);	
		super.run_phase(phase);
		forever begin
			seq_item_tx_mon=pcie_dllp_seq_item::type_id::create("seq_item_tx_mon");
            @(lpif_vif.mon_cb);
			seq_item_tx_mon.dllp = lpif_vif.mon_cb.lp_data;
			seq_item_tx_mon.lp_valid = lpif_vif.mon_cb.lp_valid;
			tx_mon_ap.write(seq_item_tx_mon);
			/*`uvm_info("run_phase", seq_item_tx_mon.convert2string(), UVM_HIGH)*/
		end
	endtask : run_phase

endclass : pcie_vip_tx_monitor

`endif 