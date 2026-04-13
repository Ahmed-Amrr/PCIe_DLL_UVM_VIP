module pcie_top;

    bit clk;

    // Clock Generation  
    initial begin
        clk = 0;
        always #5 clk = ~clk;  // 100MHz
    end 

   // Interface Instances
    lpif_if u_lpif_if   (.clk(clk));
    lpif_if d_lpif_if   (.clk(clk));

    // UVM Config DB — register interfaces
    initial begin
        uvm_config_db #(virtual lpif_if)::set(null, "*", "u_lpif", u_ipif_if);
        uvm_config_db #(virtual lpif_if)::set(null, "*", "d_lpif", d_ipif_if);
    end

    // Run Test
    initial begin
        run_test();
    end

endmodule