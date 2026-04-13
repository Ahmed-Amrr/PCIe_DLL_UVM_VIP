
// ============================================================
//  PCIe Gen 5 – Data Link Layer Package
// ============================================================

`ifndef DLL_PKG_SV
`define DLL_PKG_SV
 
package dll_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"


 
    // Data Link Layer state machine states
    typedef enum { 
        DL_INACTIVE,
        DL_FEATURE,
        DL_INIT1,
        DL_INIT2,
        DL_ACTIVE
    } dl_state_t;
  
    // DLLP Types
    typedef enum logic [7:0] { 
        // Acknowledgement 
        ACK             = 8'b0000_0000,
        NACK            = 8'b0001_0000,
        // Misc
        NOP             = 8'b0011_0001,
        VENDOR_SPECIFIC = 8'b0011_0000,
        FEATURE         = 8'b0000_0010,
        // Flow-control initialisation
        INITFC1_P       = 8'b0100_0000,   // VC bits [2:0] are masked
        INITFC1_NP      = 8'b0101_0000,
        INITFC1_CPL     = 8'b0110_0000,
        INITFC2_P       = 8'b1100_0000,
        INITFC2_NP      = 8'b1101_0000,
        INITFC2_CPL     = 8'b1110_0000,
        // Flow-control update
        UPDATEFC_P      = 8'b1000_0000,
        UPDATEFC_NP     = 8'b1001_0000,
        UPDATEFC_CPL    = 8'b1010_0000
    } dllp_type_t;

    //  fc_type_t
    //  Posted / Non-Posted / Completion – used to index credit arrays
    typedef enum {
        FC_POSTED,
        FC_NON_POSTED,
        FC_COMPLETION
    } fc_type_t;

    typedef struct packed {
        logic [7:0]  [2:0] hdr_credits;   // [FC_POSTED], [FC_NON_POSTED], [FC_COMPLETION]
        logic [11:0] [2:0] data_credits;
        logic [1:0]  [2:0] hdr_scale;
        logic [1:0]  [2:0] data_scale;
    } fc_credits_t;

    typedef struct packed {
        logic        feature_exchange_enable;   // bit 31
        logic [7:0]  rsvdp;                      // bits 30:23
        logic [22:0] local_feature_supported;   // bits 22:0
    } dl_feature_cap_reg_t;

   typedef struct packed {
        logic        remote_feature_valid;      // bit 31
        logic [7:0]  rsvdz;                      // bits 30:23
        logic [22:0] remote_feature_supported;  // bits 22:0
    } dl_feature_status_reg_t;


   // Sequence Items 
  `include "pcie_dllp_seq_item.sv"
  `include "pcie_state_seq_item.sv"

  // Config Object
  `include "pcie_vip_config.sv"

  // Coverage 
 // `include "pcie_vip_coverage.sv"

  // Scoreboard 
  `include "dll_vip_scoreboard.sv"

  // Sequencers 
  `include "pcie_vip_sequencer.sv"

  // Drivers & Monitors 
  `include "pcie_vip_driver.sv"
  `include "pcie_vip_err_driver.sv"
  `include "pcie_vip_tx_monitor.sv"
  `include "pcie_vip_rx_monitor.sv"

  // State Machine 
  `include "pcie_vip_state_machine.sv"

  // VIP Agents 
  `include "pcie_vip_tx_agent.sv"
  `include "pcie_vip_rx_agent.sv"

  // VIP Environment 
  `include "pcie_vip_env.sv"

  // Glue logic
  `include "glue_logic_monitor.sv"
  `include "glue_logic_driver.sv"
  `include "glue_logic_agent.sv"

  // Shared infra
  `include "pcie_shared_scoreboard.sv"
  `include "ref_model.sv"

  // Top config & sequencer
  `include "pcie_top_cfg.sv"
  `include "virtual_sequencer.sv"

  // Sequences
  `include "pcie_base_sequence.sv"
  `include "pcie_active_sequence.sv"
  `include "pcie_inactive_sequence.sv"
  `include "pcie_init_sequence.sv"
  `include "pcie_fc_init2_sequence.sv"
  `include "pcie_feature_sequence.sv"
  `include "pcie_feature_no_update_sequence.sv"
  `include "pcie_feature_reserved_seq.sv"
  `include "pcie_dropped_fc_sequence.sv"
  `include "pcie_out_of_order_fc_sequence.sv"
  `include "pcie_incorrect_dllp_type_sequence.sv"
  `include "pcie_wrong_dllp_type_seq.sv"
  `include "virtual_sequence.sv"

  // Top env & test (must be last)
  `include "pcie_top_env.sv"
  `include "pcie_top_test.sv"
 
endpackage : dll_pkg
 
`endif

