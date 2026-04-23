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

	    virtual lpif_if lpif_vif;
	    pcie_dllp_seq_item   seq_item_rx_mon;
		uvm_analysis_port #(pcie_dllp_seq_item) rx_mon_ap;
		int unsigned rx_pkt_id;

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
			rx_pkt_id = 0;
		endfunction : build_phase

		task run_phase(uvm_phase phase);	
			super.run_phase(phase);
			forever begin
	            @(lpif_vif.mon_cb);
	            if (lpif_vif.mon_cb.pl_valid) begin 
	            	seq_item_rx_mon=pcie_dllp_seq_item::type_id::create("seq_item_rx_mon");

					seq_item_rx_mon.dllp = lpif_vif.mon_cb.pl_data;
					seq_item_rx_mon.pl_lnk_up = lpif_vif.mon_cb.pl_lnk_up;
					seq_item_rx_mon.pl_valid = lpif_vif.mon_cb.pl_valid;
					seq_item_rx_mon.pkt_id = rx_pkt_id;
					rx_pkt_id++;
					`uvm_info("RX_MON_DEBUG", $sformatf("pkt_id=%0d t=%0t dllp=0x%012h top=0x%02h pl_lnk_up=%0b ", seq_item_rx_mon.pkt_id, $time, seq_item_rx_mon.dllp, seq_item_rx_mon.dllp[47:40], seq_item_rx_mon.pl_lnk_up), UVM_NONE)
					rx_mon_ap.write(seq_item_rx_mon);
	            end
				/*`uvm_info("run_phase", seq_item_rx_mon.convert2string(), UVM_HIGH)*/
			end
		endtask : run_phase

	endclass : pcie_vip_rx_monitor

`endif 