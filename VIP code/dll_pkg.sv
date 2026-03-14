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
    typedef enum { 
        // Acknowledgement 
        ACK,
        NACK,
        // Misc
        NOP,
        VENDOR_SPECIFIC,
        DL_FEATURE,
        // Flow-control initialisation
        INITFC1_P,
        INITFC1_NP,
        INITFC1_CPL,
        INITFC2_P,
        INITFC2_NP,
        INITFC2_CPL,
        // Flow-control update
        UPDATEFC_P,
        UPDATEFC_NP,
        UPDATEFC_CPL        
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
 
`endif // DLL_PKG_SV