`ifndef LPIF_IF_SV
`define LPIF_IF_SV

interface lpif_if (
    input logic lclk    // Link clock — synchronizes all interface signals
);

    //==========================================================
    // Signal Declarations
    //==========================================================

    bit         pl_lnk_up  ;   // Physical link is up and active
    bit         lp_valid   ;   // lp_data contains valid data from Link Partner
    logic [0:255] [7:0] lp_flit_data    ;   // 64-bit data bus from Link Partner (DLLP / TLP)
    logic [47:0] lp_dlp_data    ;
    bit         pl_valid   ;   // pl_data contains valid data from Physical Layer
    logic [0:255] [7:0] pl_flit_data   ;   // 64-bit data bus from Physical Layer
    logic [47:0] pl_dlp_data    ;

    //==========================================================
    // Driver Clocking Block - Synchronous outputs, zero skew
    //==========================================================
    clocking drv_cb @(posedge lclk);
        default output #0;
        output pl_lnk_up;
        output lp_valid ;
        output lp_flit_data  ;
        output lp_dlp_data  ;
        output pl_flit_data  ;
        output pl_dlp_data  ;
        output pl_valid ;
    endclocking

    //==========================================================
    // Monitor Clocking Block - Synchronous inputs, 1-step skew
    //==========================================================
    clocking mon_cb @(posedge lclk);
        default input #1step;
        input pl_lnk_up;
        input lp_valid ;
        input lp_flit_data  ;
        input lp_dlp_data  ;
        input pl_flit_data  ;
        input pl_dlp_data  ;
        input pl_valid ;
    endclocking

endinterface : lpif_if

`endif
