`ifndef PCIE_VIP_DRIVER
`define PCIE_VIP_DRIVER

class pcie_vip_driver extends uvm_driver #(pcie_dllp_seq_item);
    `uvm_component_utils(pcie_vip_driver)
    // register callback type with driver
    `uvm_register_cb(pcie_vip_driver, pcie_vip_driver_cb)

    parameter int DLLP_WIDTH    = 48;
    parameter int PAYLOAD_WIDTH = 32;
    parameter int CRC_WIDTH     = 16;
    parameter int BYTE          = 8;
    parameter int PAYLOAD_IN_BYTES = PAYLOAD_WIDTH / BYTE;  // equals 4

    virtual lpif_if    lpif_vif;
    pcie_vip_config    cfg;
    pcie_dllp_seq_item seq_item_drv;

    pcie_vip_tx_sequencer sqr;

    function new(string name = "pcie_vip_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);        
    endfunction

    //count for the 34us period and check for the crc
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        seq_item_drv = pcie_dllp_seq_item::type_id::create("seq_item_drv");
        forever begin
            if (seq_item_drv == null) begin
                continue;
            end
            seq_item_port.get_next_item(seq_item_drv);
            // crc generation
            CRC_generation(seq_item_drv.dllp[47:16], seq_item_drv.dllp[15:0]);

            // pre drive callbakc hook to inject error before driving
            `uvm_do_callbacks(pcie_vip_driver, pcie_vip_driver_cb, pre_drive(seq_item_drv, sqr))

            // drive the interface
            lpif_vif.drv_cb.lp_data <= seq_item_drv.dllp;
            lpif_vif.drv_cb.lp_valid <= 1;
            @(lpif_vif.drv_cb);

            // post drive callback hook 
            `uvm_do_callbacks(pcie_vip_driver, pcie_vip_driver_cb, post_drive(seq_item_drv, sqr))

            seq_item_port.item_done();
        end
    endtask
    // virtual task run_phase(uvm_phase phase);
    //     super.run_phase(phase);
    //     seq_item_drv = pcie_dllp_seq_item::type_id::create("seq_item_drv");
    //     lpif_vif.drv_cb.lp_valid <= 0;
    //     lpif_vif.drv_cb.rst_req  <= 0;
    //     forever begin
    //         seq_item_port.get_next_item(seq_item_drv);

    //         if (seq_item_drv.rst_req) begin
    //             lpif_vif.drv_cb.rst_req  <= 1;
    //             lpif_vif.drv_cb.lp_valid <= 0;  // ← no DLLP during reset
    //             //lpif_vif.drv_cb.lp_data  <= '0;
    //             @(lpif_vif.drv_cb);
    //             lpif_vif.drv_cb.rst_req  <= 0;
    //         end
    //         else begin
    //             lpif_vif.drv_cb.rst_req  <= 0;
    //             CRC_generation(seq_item_drv.dllp[47:16], seq_item_drv.dllp[15:0]);
    //             `uvm_do_callbacks(pcie_vip_driver, pcie_vip_driver_cb, pre_drive(seq_item_drv, sqr))
    //             lpif_vif.drv_cb.lp_data  <= seq_item_drv.dllp;
    //             lpif_vif.drv_cb.lp_valid <= 1;
    //             @(lpif_vif.drv_cb);
    //             // Deassert valid after one beat to avoid monitor re-sampling stale DLLP.
    //             lpif_vif.drv_cb.lp_valid <= 0;
    //             `uvm_do_callbacks(pcie_vip_driver, pcie_vip_driver_cb, post_drive(seq_item_drv, sqr))
    //         end

    //         seq_item_port.item_done();
    //     end
    // endtask

    function void CRC_generation(input bit[PAYLOAD_WIDTH-1:0] dllp_before_crc, output bit[CRC_WIDTH-1:0] crc);

        bit [CRC_WIDTH-1:0]     crc_calc = 16'hFFFF;        //initial value
        bit [PAYLOAD_WIDTH-1:0] dllp_before_crc_rearanged;  //each byte (7,6,5,4,3,2,1,0) by default
        bit [BYTE-1:0]          flipped_byte;
        bit [BYTE-1:0]          order_bytes [PAYLOAD_IN_BYTES];    //used in the flipping loops
        bit                     feedback;                   //get the last bit of the crc and add it to the input bit

    //flipping each byte in dllp_pkg as specified
        for (int i = 0; i < PAYLOAD_IN_BYTES; i++) begin
            order_bytes[i] = dllp_before_crc[(i*BYTE) +: BYTE];         //{Byte 0, Byte 1, Byte 2, Byte 3}
        end
        for (int i = 0; i < PAYLOAD_IN_BYTES; i++) begin
            dllp_before_crc_rearanged[(i*BYTE) +: BYTE] = order_bytes[PAYLOAD_IN_BYTES-1-i];
        end                                                             //needed {Byte 3, Byte 2, Byte 1, Byte 0}            
                                                                         
    //generating crc
        for (int k = 0; k < PAYLOAD_WIDTH; k++) begin
            feedback     =  dllp_before_crc_rearanged[k] ^ crc_calc[CRC_WIDTH-1];   //adding bit[15] with the input
            crc_calc     =  {crc_calc[CRC_WIDTH-2:0] , feedback};           //shift and add feedback
            crc_calc[1]  =  feedback ^ crc_calc[1];                         //calculated using the polynomial 100Bh
            crc_calc[3]  =  feedback ^ crc_calc[3];
            crc_calc[12] =  feedback ^ crc_calc[12];
        end

    //flipping each byte in crc as specified
        for (int i = 0; i < 2; i++) begin
         for (int j = 0; j < BYTE; j++) begin
             flipped_byte[7-j] = crc_calc[(i*BYTE)+j];
         end
         crc_calc[(i*BYTE) +: BYTE] = flipped_byte;  //maping each byte to (7,6,5,4,3,2,1,0)
        end                                          //instead of (0,1,2,3,4,5,6,7)
    //inverse each bit to model the inverter in the crc
        crc = ~crc_calc;
    endfunction : CRC_generation

endclass //pcie_vip_driver extends uvm_driver

`endif 


