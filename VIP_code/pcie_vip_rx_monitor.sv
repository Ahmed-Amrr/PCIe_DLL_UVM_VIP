`ifndef PCIE_VIP_RX_MONITOR
`define PCIE_VIP_RX_MONITOR

	class pcie_vip_rx_monitor extends uvm_monitor;

	// Provide implementations of virtual methods such as get_type_name and create
	`uvm_component_utils(pcie_vip_rx_monitor)

	// Interface, port, fields
	    virtual lpif_if lpif_vif;
	    pcie_dllp_seq_item   seq_item_rx_mon;
		uvm_analysis_port #(pcie_dllp_seq_item) rx_mon_ap;
		pcie_vip_config cfg;
		int unsigned rx_pkt_id;

		pcie_gen6_fec FEC;
	    logic [7:0] FLIT [0:255];
	    logic [1:0] group_status [3];
	    bit [7:0] expected_crc [8];
		
	    // Functions
		// Constructor
		function new(string name = "pcie_vip_rx_monitor", uvm_component parent=null);
			super.new(name, parent);
		endfunction : new

		function void build_phase(uvm_phase phase);
			super.build_phase(phase);
			rx_mon_ap=new("rx_mon_ap", this);
			// Get the configuration object to access the configuration registers
	        if(!uvm_config_db #(pcie_vip_config)::get(this,"","CFG_ENV",cfg))
	          `uvm_fatal("build_phase","unable to get configuration object in sb")

		    if (cfg.flit_mode_enable) begin
		    	FEC = new();
		    end
			rx_pkt_id = 0;
		endfunction : build_phase

		task run_phase(uvm_phase phase);	
			super.run_phase(phase);
			forever begin
	            @(lpif_vif.mon_cb);
            	seq_item_rx_mon=pcie_dllp_seq_item::type_id::create("seq_item_rx_mon");
				seq_item_rx_mon.pl_lnk_up = lpif_vif.mon_cb.pl_lnk_up;
				seq_item_rx_mon.pl_valid = lpif_vif.mon_cb.pl_valid;
				seq_item_rx_mon.pkt_id = rx_pkt_id;

				if(cfg.flit_mode_enable) begin
					FLIT <= lpif_vif.mon_cb.pl_data;
	                FEC.decode_flit(FLIT, FLIT, group_status);
	                for (int i = 0; i < 2; i++) begin
	                	if (group_status[i] == 2'b10) begin
	                		`uvm_error("FLIT_ECC_DECODE", "Uncorrectable error in the FLIT, dropping FLIT")
	                		continue;
	                	end
	                end


	                FEC.crc_flit_calc(FLIT[0:241], expected_crc);
	                if (FLIT[242:249] != expected_crc) begin
	                	`uvm_error("FLIT_CRC_CHECK", "Error in CRC check of the FLIT, dropping FLIT")
	                	continue;
	                end
	                for (int i = 0; i < 6; i++)
                    	seq_item_rx_mon.dllp[i*8 +: 8] <= FLIT[236+i];
	            end else begin
					for (int i = 0; i < 6; i++)
                    	seq_item_rx_mon.dllp[i*8 +: 8] <= lpif_vif.mon_cb.pl_data[236+i];
	            end

				rx_pkt_id++;
				`uvm_info("RX_MON_DEBUG", $sformatf("pkt_id=%0d t=%0t dllp=0x%012h top=0x%02h pl_lnk_up=%0b ", seq_item_rx_mon.pkt_id, $time, seq_item_rx_mon.dllp, seq_item_rx_mon.dllp[47:40], seq_item_rx_mon.pl_lnk_up), UVM_NONE)
				rx_mon_ap.write(seq_item_rx_mon);
			end
		endtask : run_phase

	endclass 

`endif 