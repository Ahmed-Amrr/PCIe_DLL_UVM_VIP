interface lpif_if (
    input logic lclk   // Link clock used to synchronize all signals
);

    bit        pl_lnk_up;   // Indicates that the physical link is up and active

    bit        lp_valid;   // Indicates that lp_data contains valid data
    logic [63:0] lp_data ;   // 64-bit data bus from Link Partner (DLLP/TLP data)

    bit        pl_valid;   // Indicates that pl_data contains valid data from PL
    logic [63:0] pl_data ;   // 64-bit data bus from Physical Layer


    // driver clocking block
    clocking drv_cb @(posedge lclk);
        default output #0;
        output pl_lnk_up;
        output lp_valid;
        output lp_data;
        output pl_data;
        output pl_valid;

    endclocking

    // monitor clocking block
    clocking mon_cb @(posedge lclk);
        default input #1step;
        input pl_lnk_up;
        input lp_valid;
        input lp_data;
        input pl_data;
        input pl_valid;

    endclocking

endinterface // lpif_if