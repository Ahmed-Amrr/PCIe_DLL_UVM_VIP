`ifndef PCIE_VIP_DRIVER
`define PCIE_VIP_DRIVER

class pcie_vip_driver extends uvm_driver #(pcie_dllp_seq_item);
    `uvm_component_utils(pcie_vip_driver)

    virtual lpif_if lpif_vif;
    pcie_dllp_seq_item   seq_item_drv;

    function new(string name = "pcie_vip_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction //new()

    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);
    endfunction

    //count for the 34us period and check for the crc
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        seq_item_drv = pcie_dllp_seq_item::type_id::create("seq_item_drv", this);
        forever begin
            seq_item_port.get_next_item(seq_item_drv);
            CRC_generation(seq_item_drv.dllp[47:16], seq_item_drv.dllp[15:0]);
            lpif_vif.lp_data = seq_item_drv.dllp;
            lpif_vif.lp_valid = seq_item_drv.lp_valid;
            @(lpif_vif.drv_cb);
            seq_item_port.item_done();
        end
    endtask

    virtual function CRC_generation(input bit[31:0] dllp_before_crc,    //the default is {Byte 0, Byte 1, Byte 2, Byte 3}
                            output bit[15:0] crc                //each byte (7,6,5,4,3,2,1,0)
    );

        bit         [15:0]  crc_calc = 16'hFFFF;        //initial value
        bit         [31:0]  dllp_before_crc_rearanged;  //rearrange each byte to be (0,1,2,3,4,5,6,7)
        bit         [7:0]   flipped_byte;               //used in the flipping loops
        bit                 feedback;                   //get the last bit of the crc and add it to the input bit

    //flipping each byte in dllp_pkg as specified
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 8; j++) begin
                flipped_byte[7-j] = dllp_before_crc[(i*8)+j];
            end
            dllp_before_crc_rearanged[((i*8)+7):(i*8)] = flipped_byte;      //{Byte 0, Byte 1, Byte 2, Byte 3}
        end                                                                 //each byte (0,1,2,3,4,5,6,7)

    //generating crc
        for (int k = 0; k < 32; k++) begin
            feedback     =  dllp_before_crc_rearanged[31-k] ^ crc_calc[15]; //adding bit[15] with the input
            crc_calc     =  {crc_calc[14:0] , feedback};
            crc_calc[1]  =  feedback ^ crc_calc[1];                         //calculated using the polynomial 100Bh
            crc_calc[3]  =  feedback ^ crc_calc[3];
            crc_calc[12] =  feedback ^ crc_calc[12];
        end

    //flipping each byte in crc as specified
        for (int i = 0; i < 2; i++) begin
            for (int j = 0; j < 8; j++) begin
                flipped_byte[7-j] = crc_calc[(i*8)+j];
            end
            crc_calc[((i*8)+7):(i*8)] = flipped_byte;   //{Byte 0, Byte 1} each byte (7,6,5,4,3,2,1,0)
        end                                             //instead of (0,1,2,3,4,5,6,7)
    //inverse each bit to model the inverter in the crc
        crc = ~crc_calc;
    endfunction : CRC_generation

endclass //pcie_vip_driver extends uvm_driver

`endif 