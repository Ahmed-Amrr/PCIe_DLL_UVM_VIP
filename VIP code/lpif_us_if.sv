interface lpif_us_if (
    input bit lclk   // Link clock used to synchronize all signals
);

    bit        pl_lnk_up;   // Indicates that the physical link is up and active

    bit        lp_irdy ;   // Transmitter is ready to send data
    bit        lp_valid;   // Indicates that lp_data contains valid data
    bit [63:0] lp_data ;   // 64-bit data bus from Link Partner (DLLP/TLP data)

    bit        pl_trdy ;   // Physical Layer Ready: receiver ready to accept data
    bit        pl_valid;   // Indicates that pl_data contains valid data from PL
    bit [63:0] pl_data ;   // 64-bit data bus from Physical Layer


    // driver clocking block
    clocking drv_cb (@posedge lclk);
        default output #2;
        output pl_lnk_up, lp_irdy, lp_valid, lp_data, pl_trdy, pl_valid, pl_data;
    endclocking

    // monitor clocking block
    clocking mon_cb (@posedge lclk);
        default input #1;
        input pl_lnk_up, lp_irdy, lp_valid, lp_data, pl_trdy, pl_valid, pl_data;
    endclocking

endinterface // lpif_if