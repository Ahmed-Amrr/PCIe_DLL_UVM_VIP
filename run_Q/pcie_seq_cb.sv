`ifndef PCIE_SEQ_CB_SV
`define PCIE_SEQ_CB_SV  

class pcie_seq_cb extends uvm_callback;

    // UVM Factory register
    `uvm_object_utils(pcie_seq_cb)

    // Current DLL state — can be used by derived callbacks to gate behavior
    dl_state_t state;

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_seq_cb");
        super.new(name);
    endfunction

    //==========================================================
    // do_send_pattern - Base callback hook for custom FC send patterns
    //==========================================================
    virtual task do_send_pattern(pcie_base_seq seq, dl_state_t state);
        // Default: do nothing — normal sequence pattern runs
    endtask

endclass

`endif