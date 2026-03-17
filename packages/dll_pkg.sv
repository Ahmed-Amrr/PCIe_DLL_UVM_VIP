
// ============================================================
//  PCIe Gen 5 – Data Link Layer Package
// ============================================================

`ifndef DLL_PKG_SV
`define DLL_PKG_SV
 
package dll_pkg;
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
        DL_FEATURE      = 8'b0000_0010,
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
        logic [7:0]  hdr_credits  [3];   // [FC_POSTED], [FC_NON_POSTED], [FC_COMPLETION]
        logic [11:0] data_credits [3];
        logic [1:0] hdr_scale  [3];
        logic [1:0] data_scale [3];
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
 
endpackage : dll_pkg
 
`endif // 

