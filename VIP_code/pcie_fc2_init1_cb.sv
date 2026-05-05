`ifndef PCIE_FC2_INIT1_CB
`define PCIE_FC2_INIT1_CB

class pcie_fc2_init1_cb extends pcie_vip_driver_cb;

    // UVM Factory register
    `uvm_object_utils(pcie_fc2_init1_cb)

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_fc2_init1_cb");
        super.new(name);
    endfunction : new

    //==========================================================
    // pre_drive - Inject a wrong DLLP type for the current state
    //==========================================================
    // Replaces the DLLP type field with a randomly chosen type 
    // that is illegal for the current DLL state
    virtual task pre_drive(pcie_dllp_seq_item item, pcie_vip_tx_sequencer sqr);
        dllp_type_t wrong_type;

        if (sqr == null) begin
            `uvm_warning("CB_FC2", "sqr is null")
            return;
        end

        // Pick a type that is not valid for the current state
        if (sqr.state == DL_INIT1) begin
            randcase
                1 : wrong_type = INITFC2_P  ;
                1 : wrong_type = INITFC2_NP ;
                1 : wrong_type = INITFC2_CPL;
            endcase
		// Overwrite DLLP type field with the illegal type
		item.dllp[47:40] = wrong_type; 
        end
              

    endtask : pre_drive

endclass 

`endif
