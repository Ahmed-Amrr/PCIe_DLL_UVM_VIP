`ifndef PCIE_VIP_DRIVER_SV
`define PCIE_VIP_DRIVER_SV

class pcie_vip_driver extends uvm_driver #(pcie_dllp_seq_item);

    // UVM Factory register and callback registration
    `uvm_component_utils(pcie_vip_driver)
    `uvm_register_cb(pcie_vip_driver, pcie_vip_driver_cb)

    // Parameters
    parameter int DLLP_WIDTH       = 48                    ;
    parameter int PAYLOAD_WIDTH    = 32                    ;
    parameter int CRC_WIDTH        = 16                    ;
    parameter int BYTE             = 8                     ;
    parameter int PAYLOAD_IN_BYTES = PAYLOAD_WIDTH / BYTE  ;   // 4 bytes

    // Virtual interface handle
    virtual lpif_if lpif_vif;

    // Handles
    pcie_dllp_seq_item    seq_item_drv;
    pcie_vip_tx_sequencer sqr         ;
    pcie_vip_config cfg;

    //==========================================================
    // Constructor
    //==========================================================
    function new(string name = "pcie_vip_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    //==========================================================
    // Build Phase
    //==========================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Get the configuration object to access the configuration registers
        if(!uvm_config_db #(pcie_vip_config)::get(this,"","CFG_ENV",cfg))
          `uvm_fatal("build_phase","unable to get configuration object in sb")
    endfunction : build_phase

    //==========================================================
    // Run Phase - Get items and drive interface each clock cycle
    //==========================================================
    // For every sequence item:
    //   1. pre_drive  callback — modify DLLP fields before CRC
    //   2. CRC generation      — compute and insert CRC into item
    //   3. crc_drive  callback — optionally corrupt the CRC
    //   4. Drive interface     — write DLLP and valid onto lpif
    //   5. post_drive callback — any post-clock actions
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        seq_item_drv = pcie_dllp_seq_item::type_id::create("seq_item_drv");

        forever begin
            if (seq_item_drv == null) continue;

            seq_item_port.get_next_item(seq_item_drv);

            // pre-drive — allows field-level error injection before CRC
            `uvm_do_callbacks(pcie_vip_driver, pcie_vip_driver_cb, pre_drive(seq_item_drv, sqr))

            // compute and insert CRC into bits [15:0]
            CRC_generation(seq_item_drv.dllp[47:16], seq_item_drv.dllp[15:0]);

            // crc_drive — allows CRC corruption after generation
            `uvm_do_callbacks(pcie_vip_driver, pcie_vip_driver_cb, crc_drive(seq_item_drv, sqr))

            // drive DLLP and valid onto the interface
            lpif_vif.drv_cb.lp_data  <= seq_item_drv.dllp;
            lpif_vif.drv_cb.lp_valid <= (cfg.reset || !lpif_vif.pl_lnk_up) ? 0 : 1;

            @(lpif_vif.drv_cb);

            // post-drive — any actions required after the clock edge
            `uvm_do_callbacks(pcie_vip_driver, pcie_vip_driver_cb, post_drive(seq_item_drv, sqr))

            seq_item_port.item_done();
        end
    endtask

    //==========================================================
    // CRC_generation - Compute 16-bit CRC over 32-bit DLLP payload
    //==========================================================
    // Function: Implements the PCIe DLLP CRC algorithm (polynomial 0x100Bh):
    // Inputs  : dllp_before_crc — 32-bit DLLP payload (bits [47:16])
    // Outputs : crc             — computed 16-bit CRC  (bits [15:0])
    function void CRC_generation(input bit [PAYLOAD_WIDTH-1:0] dllp_before_crc,
                                 output bit [CRC_WIDTH-1:0]    crc);

        bit [CRC_WIDTH-1:0]     crc_calc                 = 16'hFFFF;   // LFSR initial value
        bit [PAYLOAD_WIDTH-1:0] dllp_before_crc_rearanged            ;   // Byte-reordered payload
        bit [BYTE-1:0]          flipped_byte                         ;
        bit [BYTE-1:0]          order_bytes [PAYLOAD_IN_BYTES]       ;   // Scratch for byte reorder
        bit                     feedback                             ;   // LFSR feedback bit

        // Reverse byte order of the 32-bit payload (big-endian reorder)
        for (int i = 0; i < PAYLOAD_IN_BYTES; i++)
            order_bytes[i] = dllp_before_crc[(i*BYTE) +: BYTE];

        for (int i = 0; i < PAYLOAD_IN_BYTES; i++)
            dllp_before_crc_rearanged[(i*BYTE) +: BYTE] = order_bytes[PAYLOAD_IN_BYTES-1-i];

        // LFSR — shift and apply polynomial taps at bits 1, 3, 12
        for (int k = 0; k < PAYLOAD_WIDTH; k++) begin
            feedback     = dllp_before_crc_rearanged[k] ^ crc_calc[CRC_WIDTH-1];
            crc_calc     = {crc_calc[CRC_WIDTH-2:0], feedback};   // Shift left, insert feedback
            crc_calc[1]  = feedback ^ crc_calc[1] ;               // Polynomial tap at bit 1
            crc_calc[3]  = feedback ^ crc_calc[3] ;               // Polynomial tap at bit 3
            crc_calc[12] = feedback ^ crc_calc[12];               // Polynomial tap at bit 12
        end

        // Reverse bit order within each byte of the resulting CRC
        for (int i = 0; i < 2; i++) begin
            for (int j = 0; j < BYTE; j++)
                flipped_byte[7-j] = crc_calc[(i*BYTE)+j];
            crc_calc[(i*BYTE) +: BYTE] = flipped_byte;
        end

        // Invert all bits of the final CRC
        crc = ~crc_calc;

    endfunction : CRC_generation

endclass : pcie_vip_driver

`endif