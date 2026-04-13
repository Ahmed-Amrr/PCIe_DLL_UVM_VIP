// ==============================================================
// Incdir — so `include inside pkg resolves correctly
// ==============================================================
+incdir+./../packages
+incdir+./../VIP_code
+incdir+./../test_code

// ==============================================================
// 1. Package (must come first — everything else depends on it)
// ==============================================================
./../packages/dll_pkg.sv

// ==============================================================
// 2. Interfaces (must come before top module, after package)
// ==============================================================
./../test_code/lpif_if.sv
./../test_code/passive_interface.sv

// ==============================================================
// 3. Top module (last — instantiates interfaces + imports pkg)
// ==============================================================
./../test_code/pcie_top.sv