import uvm_pkg::*;
`include "uvm_macros.svh"

module pcie_top;

    bit clk;

    // Clock Generation  
    initial begin
        clk = 0;
        forever begin
            #5 clk = ~clk;  // 100MHz
        end     
    end 

   // Interface Instances
    lpif_if u_lpif_if   (.lclk(clk));
    lpif_if d_lpif_if   (.lclk(clk));

    // UVM Config DB — register interfaces
    initial begin
        uvm_config_db#(virtual lpif_if)::set(null, "*", "u_lpif", u_lpif_if);
        uvm_config_db#(virtual lpif_if)::set(null, "*", "d_lpif", d_lpif_if);
    end

    // Run Test
    initial begin
        run_test(pcie_top_test_base);
    end

endmodule