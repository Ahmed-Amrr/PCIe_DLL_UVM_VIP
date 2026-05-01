import uvm_pkg::*;
`include "uvm_macros.svh"
import dll_pkg::*;

module pcie_top;

    bit clk;

    //==========================================================
    // Clock Generation - 100 MHz
    //==========================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //==========================================================
    // Interface Instances
    //==========================================================
    lpif_if           u_lpif_if (.lclk(clk));   // Upstream LPIF interface
    lpif_if           d_lpif_if (.lclk(clk));   // Downstream LPIF interface
    passive_interface u_p_if    (.lclk(clk));   // Upstream passive interface
    passive_interface d_p_if    (.lclk(clk));   // Downstream passive interface

    //==========================================================
    // UVM Config DB - Register all virtual interfaces
    //==========================================================
    initial begin
        uvm_config_db #(virtual lpif_if)::set(null, "*", "u_lpif", u_lpif_if);
        uvm_config_db #(virtual lpif_if)::set(null, "*", "d_lpif", d_lpif_if);
        uvm_config_db #(virtual passive_interface)::set(null, "*", "u_p_if", u_p_if);
        uvm_config_db #(virtual passive_interface)::set(null, "*", "d_p_if", d_p_if);
    end

    //==========================================================
    // Run Test
    //==========================================================
    initial begin
        run_test("pcie_top_test_base");
    end

endmodule : pcie_top
