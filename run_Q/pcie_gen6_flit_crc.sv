`ifndef PCIE_GEN6_FLIT_CRC_SV
`define PCIE_GEN6_FLIT_CRC_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

// pcie_gen6_flit_crc : Implements the Flit-mode CRC defined in spec section 4.2.3.4.2.3
//                       "CRC Bytes in Flit" (Figure 4-53).
//
//  GF(2^8) field    : primitive polynomial x^8 + x^5 + x^3 + x + 1  (0x12B)
//  Generator g(x)   : g(x) = (x+a)(x+a^2)...(x+a^8)
//                     = x^8 + a^172 x^7 + a^116 x^6 + a^186 x^5 + a^172 x^4
//                       + a^195 x^3 + a^134 x^2 + a^199 x + a^36
//  Input a(x)       : 242 Bytes (Byte 0 .. Byte 241), fed MSB-byte-first (Byte241 -> Byte0),
//                      each byte fed bit[7] (MSB) first per spec data ordering.
//  Output           : 8 CRC Bytes B0..B7 (64 bits total)
//
//  NOTE: This class implements the LFSR (Figure 4-53) directly. It does NOT use the
//        1936x64 Appendix-K generator matrix (that matrix is only a precomputed
//        shortcut for the exact same math) — both methods must produce identical
//        results, since the matrix is just this LFSR unrolled.
class pcie_gen6_flit_crc;

    localparam int FLIT_PAYLOAD_BYTES = 242;   // Bytes 0..241 -> a(x)
    localparam int CRC_BYTES          = 8;     // B0..B7

    //  EXP table : i -> alpha^i , for primitive polynomial x^8+x^5+x^3+x+1 (0x12B)
    bit [7:0] GF_EXP [256] = {
        /* 00-0f */ 8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80, 8'h2B, 8'h56, 8'hAC, 8'h73, 8'hE6, 8'hE7, 8'hE5, 8'hE1,
        /* 10-1f */ 8'hE9, 8'hF9, 8'hD9, 8'h99, 8'h19, 8'h32, 8'h64, 8'hC8, 8'hBB, 8'h5D, 8'hBA, 8'h5F, 8'hBE, 8'h57, 8'hAE, 8'h77,
        /* 20-2f */ 8'hEE, 8'hF7, 8'hC5, 8'hA1, 8'h69, 8'hD2, 8'h8F, 8'h35, 8'h6A, 8'hD4, 8'h83, 8'h2D, 8'h5A, 8'hB4, 8'h43, 8'h86,
        /* 30-3f */ 8'h27, 8'h4E, 8'h9C, 8'h13, 8'h26, 8'h4C, 8'h98, 8'h1B, 8'h36, 8'h6C, 8'hD8, 8'h9B, 8'h1D, 8'h3A, 8'h74, 8'hE8,
        /* 40-4f */ 8'hFB, 8'hDD, 8'h91, 8'h09, 8'h12, 8'h24, 8'h48, 8'h90, 8'h0B, 8'h16, 8'h2C, 8'h58, 8'hB0, 8'h4B, 8'h96, 8'h07,
        /* 50-5f */ 8'h0E, 8'h1C, 8'h38, 8'h70, 8'hE0, 8'hEB, 8'hFD, 8'hD1, 8'h89, 8'h39, 8'h72, 8'hE4, 8'hE3, 8'hED, 8'hF1, 8'hC9,
        /* 60-6f */ 8'hB9, 8'h59, 8'hB2, 8'h4F, 8'h9E, 8'h17, 8'h2E, 8'h5C, 8'hB8, 8'h5B, 8'hB6, 8'h47, 8'h8E, 8'h37, 8'h6E, 8'hDC,
        /* 70-7f */ 8'h93, 8'h0D, 8'h1A, 8'h34, 8'h68, 8'hD0, 8'h8B, 8'h3D, 8'h7A, 8'hF4, 8'hC3, 8'hAD, 8'h71, 8'hE2, 8'hEF, 8'hF5,
        /* 80-8f */ 8'hC1, 8'hA9, 8'h79, 8'hF2, 8'hCF, 8'hB5, 8'h41, 8'h82, 8'h2F, 8'h5E, 8'hBC, 8'h53, 8'hA6, 8'h67, 8'hCE, 8'hB7,
        /* 90-9f */ 8'h45, 8'h8A, 8'h3F, 8'h7E, 8'hFC, 8'hD3, 8'h8D, 8'h31, 8'h62, 8'hC4, 8'hA3, 8'h6D, 8'hDA, 8'h9F, 8'h15, 8'h2A,
        /* a0-af */ 8'h54, 8'hA8, 8'h7B, 8'hF6, 8'hC7, 8'hA5, 8'h61, 8'hC2, 8'hAF, 8'h75, 8'hEA, 8'hFF, 8'hD5, 8'h81, 8'h29, 8'h52,
        /* b0-bf */ 8'hA4, 8'h63, 8'hC6, 8'hA7, 8'h65, 8'hCA, 8'hBF, 8'h55, 8'hAA, 8'h7F, 8'hFE, 8'hD7, 8'h85, 8'h21, 8'h42, 8'h84,
        /* c0-cf */ 8'h23, 8'h46, 8'h8C, 8'h33, 8'h66, 8'hCC, 8'hB3, 8'h4D, 8'h9A, 8'h1F, 8'h3E, 8'h7C, 8'hF8, 8'hDB, 8'h9D, 8'h11,
        /* d0-df */ 8'h22, 8'h44, 8'h88, 8'h3B, 8'h76, 8'hEC, 8'hF3, 8'hCD, 8'hB1, 8'h49, 8'h92, 8'h0F, 8'h1E, 8'h3C, 8'h78, 8'hF0,
        /* e0-ef */ 8'hCB, 8'hBD, 8'h51, 8'hA2, 8'h6F, 8'hDE, 8'h97, 8'h05, 8'h0A, 8'h14, 8'h28, 8'h50, 8'hA0, 8'h6B, 8'hD6, 8'h87,
        /* f0-ff */ 8'h25, 8'h4A, 8'h94, 8'h03, 8'h06, 8'h0C, 8'h18, 8'h30, 8'h60, 8'hC0, 8'hAB, 8'h7D, 8'hFA, 8'hDF, 8'h95, 8'h01
    };

    //  LOG table : alpha^i -> i , same field
    bit [7:0] GF_LOG [256] = {
        /* 00-0f */ 8'hFF, 8'h00, 8'h01, 8'hF3, 8'h02, 8'hE7, 8'hF4, 8'h4F, 8'h03, 8'h43, 8'hE8, 8'h48, 8'hF5, 8'h71, 8'h50, 8'hDB,
        /* 10-1f */ 8'h04, 8'hCF, 8'h44, 8'h33, 8'hE9, 8'h9E, 8'h49, 8'h65, 8'hF6, 8'h14, 8'h72, 8'h37, 8'h51, 8'h3C, 8'hDC, 8'hC9,
        /* 20-2f */ 8'h05, 8'hBD, 8'hD0, 8'hC0, 8'h45, 8'hF0, 8'h34, 8'h30, 8'hEA, 8'hAE, 8'h9F, 8'h08, 8'h4A, 8'h2B, 8'h66, 8'h88,
        /* 30-3f */ 8'hF7, 8'h97, 8'h15, 8'hC3, 8'h73, 8'h27, 8'h38, 8'h6D, 8'h52, 8'h59, 8'h3D, 8'hD3, 8'hDD, 8'h77, 8'hCA, 8'h92,
        /* 40-4f */ 8'h06, 8'h86, 8'hBE, 8'h2E, 8'hD1, 8'h90, 8'hC1, 8'h6B, 8'h46, 8'hD9, 8'hF1, 8'h4D, 8'h35, 8'hC7, 8'h31, 8'h63,
        /* 50-5f */ 8'hEB, 8'hE2, 8'hAF, 8'h8B, 8'hA0, 8'hB7, 8'h09, 8'h1D, 8'h4B, 8'h61, 8'h2C, 8'h69, 8'h67, 8'h19, 8'h89, 8'h1B,
        /* 60-6f */ 8'hF8, 8'hA6, 8'h98, 8'hB1, 8'h16, 8'hB4, 8'hC4, 8'h8D, 8'h74, 8'h24, 8'h28, 8'hED, 8'h39, 8'h9B, 8'h6E, 8'hE4,
        /* 70-7f */ 8'h53, 8'h7C, 8'h5A, 8'h0B, 8'h3E, 8'hA9, 8'hD4, 8'h1F, 8'hDE, 8'h82, 8'h78, 8'hA2, 8'hCB, 8'hFB, 8'h93, 8'hB9,
        /* 80-8f */ 8'h07, 8'hAD, 8'h87, 8'h2A, 8'hBF, 8'hBC, 8'h2F, 8'hEF, 8'hD2, 8'h58, 8'h91, 8'h76, 8'hC2, 8'h96, 8'h6C, 8'h26,
        /* 90-9f */ 8'h47, 8'h42, 8'hDA, 8'h70, 8'hF2, 8'hFE, 8'h4E, 8'hE6, 8'h36, 8'h13, 8'hC8, 8'h3B, 8'h32, 8'hCE, 8'h64, 8'h9D,
        /* a0-af */ 8'hEC, 8'h23, 8'hE3, 8'h9A, 8'hB0, 8'hA5, 8'h8C, 8'hB3, 8'hA1, 8'h81, 8'hB8, 8'hFA, 8'h0A, 8'h7B, 8'h1E, 8'hA8,
        /* b0-bf */ 8'h4C, 8'hD8, 8'h62, 8'hC6, 8'h2D, 8'h85, 8'h6A, 8'h8F, 8'h68, 8'h60, 8'h1A, 8'h18, 8'h8A, 8'hE1, 8'h1C, 8'hB6,
        /* c0-cf */ 8'hF9, 8'h80, 8'hA7, 8'h7A, 8'h99, 8'h22, 8'hB2, 8'hA4, 8'h17, 8'h5F, 8'hB5, 8'hE0, 8'hC5, 8'hD7, 8'h8E, 8'h84,
        /* d0-df */ 8'h75, 8'h57, 8'h25, 8'h95, 8'h29, 8'hAC, 8'hEE, 8'hBB, 8'h3A, 8'h12, 8'h9C, 8'hCD, 8'h6F, 8'h41, 8'hE5, 8'hFD,
        /* e0-ef */ 8'h54, 8'h0F, 8'h7D, 8'h5C, 8'h5B, 8'h0E, 8'h0C, 8'h0D, 8'h3F, 8'h10, 8'hAA, 8'h55, 8'hD5, 8'h5D, 8'h20, 8'h7E,
        /* f0-ff */ 8'hDF, 8'h5E, 8'h83, 8'hD6, 8'h79, 8'h7F, 8'hA3, 8'h21, 8'hCC, 8'h11, 8'hFC, 8'h40, 8'h94, 8'h56, 8'hBA, 8'hAB
    };

    // g-coefficients g0..g7 (each a fixed GF(2^8) element, derived from the spec exponents)
    //   g0 = a^36 , g1 = a^199 , g2 = a^134 , g3 = a^195 , g4 = a^172 , g5 = a^186 , g6 = a^116 , g7 = a^172
    bit [7:0] G [8] = '{8'h69, 8'h4D, 8'h41, 8'h33, 8'hD5, 8'hFE, 8'h68, 8'hD5};

    // Function gf_mul : multiply two GF(2^8) elements via log/exp tables
    // Inputs  : a, b -> multiplied operands
    // Returns : a x b in GF(2^8) ; returns 0 if either operand is 0
    function bit [7:0] gf_mul (bit [7:0] a, bit [7:0] b);
        bit [8:0] sum;
        if (a == 8'h00 || b == 8'h00) return 8'h00;
        sum = (GF_LOG[a] + GF_LOG[b]) % 255;
        return GF_EXP[sum[7:0]];
    endfunction : gf_mul

    // Function crc_flit_calc : Computes the 8 CRC bytes (B0..B7) over a 242-byte Flit payload,
    //                          implementing the Figure 4-53 LFSR exactly (Fibonacci-style shift
    //                          register: feedback = B7 XOR new_byte ; each Bi shifts from B(i-1),
    //                          XORed with gi*feedback ; B0 takes g0*feedback only).
    // Input   : data[0:241] -> Flit information Bytes 0..241 , fed in MSB-byte-first order
    //                          (i.e. call with data[0]=Byte241 ... data[241]=Byte0, matching
    //                          the spec's a(x) convention / Appendix-K bit ordering)
    // Output  : crc_bytes[0:7] -> B0..B7 (B0 = crc_bytes[0] ... B7 = crc_bytes[7])
    function void crc_flit_calc (
        input  bit [7:0] data [FLIT_PAYLOAD_BYTES],
        output bit [7:0] crc_bytes [CRC_BYTES]
    );
        bit [7:0] B [CRC_BYTES];
        bit [7:0] new_B [CRC_BYTES];
        bit [7:0] feedback;

        foreach (B[i]) B[i] = 8'h00;

        for (int n = 0; n < FLIT_PAYLOAD_BYTES; n++) begin
            feedback = B[7] ^ data[n];

            new_B[0] = gf_mul(G[0], feedback);
            for (int i = 1; i < CRC_BYTES; i++)
                new_B[i] = B[i-1] ^ gf_mul(G[i], feedback);

            foreach (B[i]) B[i] = new_B[i];
        end

        foreach (crc_bytes[i]) crc_bytes[i] = B[i];

        `uvm_info("FLIT_CRC",
            $sformatf("[crc_flit_calc] B0..B7 = %02h %02h %02h %02h %02h %02h %02h %02h",
                      crc_bytes[0], crc_bytes[1], crc_bytes[2], crc_bytes[3],
                      crc_bytes[4], crc_bytes[5], crc_bytes[6], crc_bytes[7]), UVM_MEDIUM)
    endfunction : crc_flit_calc

    // Function crc_flit_check : Recomputes the CRC over a received 242-byte Flit payload and
    //                           compares it against the received 8 CRC bytes.
    // Input   : data[0:241]        -> received Flit information bytes (post FEC decode/correct)
    //           rx_crc_bytes[0:7]  -> received B0..B7
    // Returns : 1 if mismatch (CRC error -> Flit not valid), 0 if match
    function bit crc_flit_check (
        input bit [7:0] data         [FLIT_PAYLOAD_BYTES],
        input bit [7:0] rx_crc_bytes  [CRC_BYTES]
    );
        bit [7:0] calc_crc [CRC_BYTES];
        bit       mismatch;

        crc_flit_calc(data, calc_crc);

        mismatch = 0;
        foreach (calc_crc[i])
            if (calc_crc[i] != rx_crc_bytes[i]) mismatch = 1;

        if (mismatch)
            `uvm_error("FLIT_CRC",
                $sformatf("[crc_flit_check] CRC mismatch. Calc=%02h%02h%02h%02h%02h%02h%02h%02h Rx=%02h%02h%02h%02h%02h%02h%02h%02h",
                          calc_crc[0], calc_crc[1], calc_crc[2], calc_crc[3], calc_crc[4], calc_crc[5], calc_crc[6], calc_crc[7],
                          rx_crc_bytes[0], rx_crc_bytes[1], rx_crc_bytes[2], rx_crc_bytes[3], rx_crc_bytes[4], rx_crc_bytes[5], rx_crc_bytes[6], rx_crc_bytes[7]))
        else
            `uvm_info("FLIT_CRC", "[crc_flit_check] CRC OK", UVM_HIGH)

        return mismatch;
    endfunction : crc_flit_check

endclass : pcie_gen6_flit_crc

`endif
