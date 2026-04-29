`ifndef LPIF_IF_SV
`define LPIF_IF_SV

interface lpif_if (
    input logic lclk    // Link clock — synchronizes all interface signals
);

    //==========================================================
    // Signal Declarations
    //==========================================================

    bit          pl_lnk_up  ;   // Physical link is up and active
    
    bit          lp_valid   ;   // lp_data contains valid data from Link Partner
    logic [63:0] lp_data    ;   // 64-bit data bus from Link Partner (DLLP / TLP)

    bit          pl_valid   ;   // pl_data contains valid data from Physical Layer
    logic [63:0] pl_data    ;   // 64-bit data bus from Physical Layer

    //==========================================================
    // Driver Clocking Block - Synchronous outputs, zero skew
    //==========================================================
    clocking drv_cb @(posedge lclk);
        default output #0;
        output pl_lnk_up;
        output lp_valid ;
        output lp_data  ;
        output pl_data  ;
        output pl_valid ;
    endclocking

    //==========================================================
    // Monitor Clocking Block - Synchronous inputs, 1-step skew
    //==========================================================
    clocking mon_cb @(posedge lclk);
        default input #1step;
        input pl_lnk_up;
        input lp_valid ;
        input lp_data  ;
        input pl_data  ;
        input pl_valid ;
    endclocking

endinterface : lpif_if

`endif
