`ifndef PCIE_GEN6_ECC_SV
`define PCIE_GEN6_ECC_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

typedef enum logic [1:0] {
    ECC_NO_ERROR      = 2'b00,
    ECC_CORRECTED     = 2'b01,
    ECC_UNCORRECTABLE = 2'b10
} ecc_status_t;

class pcie_gen6_ecc;

    //  EXP table : i → α^i 
    bit [7:0] GF_EXP [0:255] = {
        /* 00-0f */ 8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80, 8'h1D, 8'h3A, 8'h74, 8'hE8, 8'hCD, 8'h87, 8'h13, 8'h26,
        /* 10-1f */ 8'h4C, 8'h98, 8'h2D, 8'h5A, 8'hB4, 8'h75, 8'hEA, 8'hC9, 8'h8F, 8'h03, 8'h06, 8'h0C, 8'h18, 8'h30, 8'h60, 8'hC0,
        /* 20-2f */ 8'h9D, 8'h27, 8'h4E, 8'h9C, 8'h25, 8'h4A, 8'h94, 8'h35, 8'h6A, 8'hD4, 8'hB5, 8'h77, 8'hEE, 8'hC1, 8'h9F, 8'h23,
        /* 30-3f */ 8'h46, 8'h8C, 8'h05, 8'h0A, 8'h14, 8'h28, 8'h50, 8'hA0, 8'h5D, 8'hBA, 8'h69, 8'hD2, 8'hB9, 8'h6F, 8'hDE, 8'hA1,
        /* 40-4f */ 8'h5F, 8'hBE, 8'h61, 8'hC2, 8'h99, 8'h2F, 8'h5E, 8'hBC, 8'h65, 8'hCA, 8'h89, 8'h0F, 8'h1E, 8'h3C, 8'h78, 8'hF0,
        /* 50-5f */ 8'hFD, 8'hE7, 8'hD3, 8'hBB, 8'h6B, 8'hD6, 8'hB1, 8'h7F, 8'hFE, 8'hE1, 8'hDF, 8'hA3, 8'h5B, 8'hB6, 8'h71, 8'hE2,
        /* 60-6f */ 8'hD9, 8'hAF, 8'h43, 8'h86, 8'h11, 8'h22, 8'h44, 8'h88, 8'h0D, 8'h1A, 8'h34, 8'h68, 8'hD0, 8'hBD, 8'h67, 8'hCE,
        /* 70-7f */ 8'h81, 8'h1F, 8'h3E, 8'h7C, 8'hF8, 8'hED, 8'hC7, 8'h93, 8'h3B, 8'h76, 8'hEC, 8'hC5, 8'h97, 8'h33, 8'h66, 8'hCC,
        /* 80-8f */ 8'h85, 8'h17, 8'h2E, 8'h5C, 8'hB8, 8'h6D, 8'hDA, 8'hA9, 8'h4F, 8'h9E, 8'h21, 8'h42, 8'h84, 8'h15, 8'h2A, 8'h54,
        /* 90-9f */ 8'hA8, 8'h4D, 8'h9A, 8'h29, 8'h52, 8'hA4, 8'h55, 8'hAA, 8'h49, 8'h92, 8'h39, 8'h72, 8'hE4, 8'hD5, 8'hB7, 8'h73,
        /* A0-Af */ 8'hE6, 8'hD1, 8'hBF, 8'h63, 8'hC6, 8'h91, 8'h3F, 8'h7E, 8'hFC, 8'hE5, 8'hD7, 8'hB3, 8'h7B, 8'hF6, 8'hF1, 8'hFF,
        /* B0-BF */ 8'hE3, 8'hDB, 8'hAB, 8'h4B, 8'h96, 8'h31, 8'h62, 8'hC4, 8'h95, 8'h37, 8'h6E, 8'hDC, 8'hA5, 8'h57, 8'hAE, 8'h41,
        /* C0-CF */ 8'h82, 8'h19, 8'h32, 8'h64, 8'hC8, 8'h8D, 8'h07, 8'h0E, 8'h1C, 8'h38, 8'h70, 8'hE0, 8'hDD, 8'hA7, 8'h53, 8'hA6,
        /* D0-DF */ 8'h51, 8'hA2, 8'h59, 8'hB2, 8'h79, 8'hF2, 8'hF9, 8'hEF, 8'hC3, 8'h9B, 8'h2B, 8'h56, 8'hAC, 8'h45, 8'h8A, 8'h09,
        /* E0-EF */ 8'h12, 8'h24, 8'h48, 8'h90, 8'h3D, 8'h7A, 8'hF4, 8'hF5, 8'hF7, 8'hF3, 8'hFB, 8'hEB, 8'hCB, 8'h8B, 8'h0B, 8'h16,
        /* F0-FF */ 8'h2C, 8'h58, 8'hB0, 8'h7D, 8'hFA, 8'hE9, 8'hCF, 8'h83, 8'h1B, 8'h36, 8'h6C, 8'hD8, 8'hAD, 8'h47, 8'h8E, 8'h01
    };

    //  LOG table : α^i → i  
    bit [7:0] GF_LOG [0:255] = {
        /* 00-0f */ 8'hFF, 8'h00, 8'h01, 8'h19, 8'h02, 8'h32, 8'h1A, 8'hC6, 8'h03, 8'hDF, 8'h33, 8'hEE, 8'h1B, 8'h68, 8'hC7, 8'h4B,
        /* 10-1f */ 8'h04, 8'h64, 8'hE0, 8'h0E, 8'h34, 8'h8D, 8'hEF, 8'h81, 8'h1C, 8'hC1, 8'h69, 8'hF8, 8'hC8, 8'h08, 8'h4C, 8'h71,
        /* 20-2f */ 8'h05, 8'h8A, 8'h65, 8'h2F, 8'hE1, 8'h24, 8'h0F, 8'h21, 8'h35, 8'h93, 8'h8E, 8'hDA, 8'hF0, 8'h12, 8'h82, 8'h45,
        /* 30-3f */ 8'h1D, 8'hB5, 8'hC2, 8'h7D, 8'h6A, 8'h27, 8'hF9, 8'hB9, 8'hC9, 8'h9A, 8'h09, 8'h78, 8'h4D, 8'hE4, 8'h72, 8'hA6,
        /* 40-4f */ 8'h06, 8'hBF, 8'h8B, 8'h62, 8'h66, 8'hDD, 8'h30, 8'hFD, 8'hE2, 8'h98, 8'h25, 8'hB3, 8'h10, 8'h91, 8'h22, 8'h88,
        /* 50-5f */ 8'h36, 8'hD0, 8'h94, 8'hCE, 8'h8F, 8'h96, 8'hDB, 8'hBD, 8'hF1, 8'hD2, 8'h13, 8'h5C, 8'h83, 8'h38, 8'h46, 8'h40,
        /* 60-6f */ 8'h1E, 8'h42, 8'hB6, 8'hA3, 8'hC3, 8'h48, 8'h7E, 8'h6E, 8'h6B, 8'h3A, 8'h28, 8'h54, 8'hFA, 8'h85, 8'hBA, 8'h3D,
        /* 70-7f */ 8'hCA, 8'h5E, 8'h9B, 8'h9F, 8'h0A, 8'h15, 8'h79, 8'h2B, 8'h4E, 8'hD4, 8'hE5, 8'hAC, 8'h73, 8'hF3, 8'hA7, 8'h57,
        /* 80-8f */ 8'h07, 8'h70, 8'hC0, 8'hF7, 8'h8C, 8'h80, 8'h63, 8'h0D, 8'h67, 8'h4A, 8'hDE, 8'hED, 8'h31, 8'hC5, 8'hFE, 8'h18,
        /* 90-9f */ 8'hE3, 8'hA5, 8'h99, 8'h77, 8'h26, 8'hB8, 8'hB4, 8'h7C, 8'h11, 8'h44, 8'h92, 8'hD9, 8'h23, 8'h20, 8'h89, 8'h2E,
        /* A0-Af */ 8'h37, 8'h3F, 8'hD1, 8'h5B, 8'h95, 8'hBC, 8'hCF, 8'hCD, 8'h90, 8'h87, 8'h97, 8'hB2, 8'hDC, 8'hFC, 8'hBE, 8'h61,
        /* B0-BF */ 8'hF2, 8'h56, 8'hD3, 8'hAB, 8'h14, 8'h2A, 8'h5D, 8'h9E, 8'h84, 8'h3C, 8'h39, 8'h53, 8'h47, 8'h6D, 8'h41, 8'hA2,
        /* C0-CF */ 8'h1F, 8'h2D, 8'h43, 8'hD8, 8'hB7, 8'h7B, 8'hA4, 8'h76, 8'hC4, 8'h17, 8'h49, 8'hEC, 8'h7F, 8'h0C, 8'h6F, 8'hF6,
        /* D0-DF */ 8'h6C, 8'hA1, 8'h3B, 8'h52, 8'h29, 8'h9D, 8'h55, 8'hAA, 8'hFB, 8'h60, 8'h86, 8'hB1, 8'hBB, 8'hCC, 8'h3E, 8'h5A,
        /* E0-EF */ 8'hCB, 8'h59, 8'h5F, 8'hB0, 8'h9C, 8'hA9, 8'hA0, 8'h51, 8'h0B, 8'hF5, 8'h16, 8'hEB, 8'h7A, 8'h75, 8'h2C, 8'hD7,
        /* F0-FF */ 8'h4F, 8'hAE, 8'hD5, 8'hE9, 8'hE6, 8'hE7, 8'hAD, 8'hE8, 8'h74, 8'hD6, 8'hF4, 8'hEA, 8'hA8, 8'h50, 8'h58, 8'hAF
    };

    // Function gf_mul : multiply two GF(2^8) elements with log/exp tables
    //                   Returns 0 if either operand is 0 
    // Inputs  : a, b -> multiplied operands
    // Returns : a × b in GF(2^8)
    function bit [7:0] gf_mul (bit [7:0] a, bit [7:0] b);
        bit [8:0] sum;
        if (a == 8'h00 || b == 8'h00) return 8'h00;
        sum = (GF_LOG[a] + GF_LOG[b]) % 255; // modulo 255
        return GF_EXP[sum[7:0]];
    endfunction : gf_mul

    //  encode_ecc_group : compute the two ECC bytes for one 84-byte code word
    //  Inputs  : data[0:83] –> information bytes
    //                        data[83] must set to 8'h00 for groups 1 & 2 while calling
    //  Outputs : check_byte  –> B[84] = Σ data[i] × α^(84−i), i from 0 to 83  
    //            parity_byte –> B[85] = XOR(data[0 to 83])  
    function void encode_ecc_group (
        input  bit [7:0] data [84],
        output bit [7:0] check_byte,
        output bit [7:0] parity_byte
    );
        check_byte  = 8'h00;
        parity_byte = 8'h00;

        for (int i = 0; i < 84; i++) begin
            check_byte  ^= gf_mul(data[i], GF_EXP[84 - i]);
            parity_byte ^= data[i];
        end

        `uvm_info("ECC_RM",
            $sformatf("[encode_ecc_group] check=0x%02h parity=0x%02h",
                      check_byte, parity_byte), UVM_HIGH)
    endfunction : encode_ecc_group

    //  decode_group : correct single byte error for one 86-byte code word
    //  Input  : rx[0:85] –> received 86-byte code word
    //  Outputs : corrected[0:85]  –> corrected code word
    //            status           –> ECC_NO_ERROR / ECC_CORRECTED / ECC_UNCORRECTABLE
    function void decode_group (
        input  bit [7:0]   rx        [86],
        output bit [7:0]   corrected [86],
        output ecc_status_t status
    );
        bit [7:0] synd_parity;
        bit [7:0] synd_check;
        bit [7:0] i_sc, i_sp;
        bit [8:0] exp_diff;
        bit [7:0] col;

        // default case no error
        foreach (rx[i]) corrected[i] = rx[i];

        // Syndrome Parity : XOR of B[0 to 83] and B[85]
        synd_parity = 8'h00;
        for (int i = 0; i < 84; i++) synd_parity ^= rx[i];
        synd_parity ^= rx[85];

        // Syndrome Check : recompute B[84] from received data, XOR with received B[84] 
        synd_check = 8'h00;
        for (int i = 0; i < 84; i++)
            synd_check ^= gf_mul(rx[i], GF_EXP[84 - i]);
        synd_check ^= rx[84];
        // Case 1: For Both equal to zero -> NO ERROR
        if (synd_check == 8'h00 && synd_parity == 8'h00) begin
            status = ECC_NO_ERROR;
        // Case 2: Error in B[85] for Syndrome Parity not equal zero
        end else if (synd_check == 8'h00 && synd_parity != 8'h00) begin
            //Correct by XOR with SP
            corrected[85] ^= synd_parity;
            status = ECC_CORRECTED;
            `uvm_info("ECC_RM",
                $sformatf("[decode_group] Corrected B[85]: 0x%02h → 0x%02h",
                          rx[85], corrected[85]), UVM_MEDIUM)
        // Case 3: Error in B[84] for Syndrome check not equal zero
        end else if (synd_check != 8'h00 && synd_parity == 8'h00) begin
            // Correct by XOR with SC
            corrected[84] ^= synd_check;
            status = ECC_CORRECTED;
            `uvm_info("ECC_RM",
                $sformatf("[decode_group] Corrected B[84]: 0x%02h → 0x%02h",
                          rx[84], corrected[84]), UVM_MEDIUM)
        // Case 4: Single-symbol error in B[col] For Both not equal to zero
        end else begin
            //  α^(84 − column) = synd_check / synd_parity
            //  84 − column = LOG[SC] − LOG[SP]
            //  col = 84 − (LOG[SC] − LOG[SP]) mod 255
            i_sc   = GF_LOG[synd_check];
            i_sp   = GF_LOG[synd_parity];
            // Modulo-255 subtraction
            exp_diff = (i_sc >= i_sp) ?  ({1'b0, i_sc} - {1'b0, i_sp}) : ({1'b0, i_sc} + 9'd255 - {1'b0, i_sp});
            col = 84 - exp_diff;
            // column from 0 to 83
           if(col < 8'd84) begin
                 corrected[col] ^= synd_parity;
                 status = ECC_CORRECTED;
                 `uvm_info("ECC_RM",
                    $sformatf("[decode_group] Corrected B[%0d]: 0x%02h → 0x%02h",
                              col, rx[col], corrected[col]), UVM_MEDIUM)
            end
            // if col >= 84 → uncorrectable error
            else begin
                 status = ECC_UNCORRECTABLE;
                 `uvm_error("ECC_RM",
                    $sformatf("[decode_group] Uncorrectable error: SC=0x%02h SP=0x%02h col=%0d",
                              synd_check, synd_parity, col))
            end
        end

        `uvm_info("ECC_RM",
            $sformatf("[decode_group] SC=0x%02h SP=0x%02h status=%s",
                      synd_check, synd_parity, status.name()), UVM_MEDIUM)
    endfunction : decode_group

    //  encode_flit : encode the full 256-byte flit
    //  Input  : flit_in[0:255]  –> from 250 to 255 are overwritten 
    //  Output : flit_out[0:255] –> from 0 to 249 unchanged input and from 250 to 255 equals calculated ECC bytes
    function void encode_flit (
        input  bit [7:0] flit_in  [256],
        output bit [7:0] flit_out [256]
    );
        bit [7:0] grp     [3][86];      // ecc three groups
        bit [7:0] check     [3];        // computed B[84] per group
        bit [7:0] parity     [3];       // computed B[85] per group
        bit [7:0] encoder_in  [84];

        // Map flit bytes from 0 to 249 into the three ECC groups 
        // group = i mod 3,  byte_offset = floor(i/3)
        for (int i = 0; i < 250; i++)
            grp[i % 3][i / 3] = flit_in[i];

        // Put B[83]=0 for groups 1 and 2 
        grp[1][83] = 8'h00;
        grp[2][83] = 8'h00;

        // Encode each group
        for (int g = 0; g < 3; g++) begin
            for (int b = 0; b < 84; b++) encoder_in[b] = grp[g][b];
            encode_ecc_group(encoder_in, check[g], parity[g]);
        end

        //  output flit generation
        for (int i = 0; i < 250; i++) flit_out[i] = flit_in[i];
        // ECC bytes mapping (flit bytes 250 -> 255)
        flit_out[250] = check[1];    // group 1 check byte
        flit_out[251] = check[2];    // group 2 check byte
        flit_out[252] = check[0];    // group 0 check byte
        flit_out[253] = parity[1];   // group 1 parity byte
        flit_out[254] = parity[2];   // group 2 parity byte
        flit_out[255] = parity[0];   // group 0 parity byte

        `uvm_info("ECC_RM", "[encode_flit] Done", UVM_HIGH)
    endfunction : encode_flit

    //  decode_flit : decode and correct a full 256-byte flit
    //  Input  : flit_in[0:255]   –> received flit (data + ECC bytes 250 -> 255)
    //  Output : flit_out[0:255]  –> corrected flit
    //           group_status[3]  –> per-group ECC status
    function void decode_flit (
        input  bit [7:0]  flit_in  [256],
        output bit [7:0]  flit_out [256],
        output ecc_status_t group_status  [3]
    );
        bit [7:0] grp             [3][86];           // received code words
        bit [7:0] corrected_cw    [3][86];   // corrected code words from decoder
        bit [7:0] decoder_in  [86];
        bit [7:0] decoder_out [86];

        // Map flit bytes from 0 to 249 into ECC groups
        for (int i = 0; i < 250; i++)
            grp[i % 3][i / 3] = flit_in[i];

        // Put B[83]=0 for groups 1 and 2
        grp[1][83] = 8'h00;
        grp[2][83] = 8'h00;

        // Place received ECC bytes into group code words 
        grp[1][84] = flit_in[250];
        grp[2][84] = flit_in[251];
        grp[0][84] = flit_in[252];
        grp[1][85] = flit_in[253];
        grp[2][85] = flit_in[254];
        grp[0][85] = flit_in[255];

        // Decode each group 
        for (int g = 0; g < 3; g++) begin
            for (int b = 0; b < 86; b++) decoder_in[b] = grp[g][b];
            decode_group(decoder_in, decoder_out, group_status[g]);
            for (int b = 0; b < 86; b++) corrected_cw[g][b] = decoder_out[b];

            `uvm_info("ECC_RM",
                $sformatf("[decode_flit] Group %0d: status=%s ",
                          g, group_status[g].name()), UVM_MEDIUM)
        end

        // Reconstruct corrected flit 
        // Data bytes (flit[0:249])
        for (int i = 0; i < 250; i++)
            flit_out[i] = corrected_cw[i % 3][i / 3];

        // ECC bytes (flit[250:255])
        flit_out[250] = corrected_cw[1][84];
        flit_out[251] = corrected_cw[2][84];
        flit_out[252] = corrected_cw[0][84];
        flit_out[253] = corrected_cw[1][85];
        flit_out[254] = corrected_cw[2][85];
        flit_out[255] = corrected_cw[0][85];
    endfunction : decode_flit

endclass 

`endif 