/*  This file is part of JTFRAME.
      JTFRAME program is free software: you can redistribute it and/or modify
      it under the terms of the GNU General Public License as published by
      the Free Software Foundation, either version 3 of the License, or
      (at your option) any later version.

      JTFRAME program is distributed in the hope that it will be useful,
      but WITHOUT ANY WARRANTY; without even the implied warranty of
      MERCHANTABILITY or FITNESS FOR addr PARTICULAR PURPOSE.  See the
      GNU General Public License for more details.

      You should have received a copy of the GNU General Public License
      along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

      Author: Jose Tejada Gomez. Twitter: @topapate
      Version: 1.0
      Date: 21-5-2021

*/

// Instantiates the m6801 core with some
// of the logic needed to become a 63701 MCU
// such as the one used in Double Dragon or Bubble Bobble

module jtframe_6801mcu(
    input         rst,
    input         clk,
    input         cen,

    input         int0n,
    input         int1n,

    input  [ 7:0] p0_i,
    input  [ 7:0] p1_i,
    input  [ 7:0] p2_i,
    input  [ 7:0] p3_i,

    output [ 7:0] p0_o,
    output [ 7:0] p1_o,
    output [ 7:0] p2_o,
    output [ 7:0] p3_o,

    // external memory
    input  [ 7:0] x_din,
    output [ 7:0] x_dout,
    output [15:0] x_addr,
    output        x_wr,

    // ROM programming
    input         clk_rom,
    input [11:0]  prog_addr,
    input [ 7:0]  prom_din,
    input         prom_we
);

wire [ 7:0] rom_data, ram_data, ram_q;
wire [15:0] rom_addr;
wire [ 6:0] ram_addr;
wire        ram_we;
reg  [ 7:0] xin_sync, p0_s, p1_s, p2_s, p3_s;   // input data must be sampled with cen

// The memory is expected to suffer cen for both reads and writes
wire clkx = clk & cen;

always @(posedge clk) if(cen) begin
    xin_sync <= x_din;
    p0_s     <= p0_i;
    p1_s     <= p1_i;
    p2_s     <= p2_i;
    p3_s     <= p3_i;
end

// You need to clock gate for reading or the MCU won't work
jtframe_dual_ram #(.aw(12)) u_prom(
    .clk0   ( clk_rom   ),
    .clk1   ( clkx      ),
    // Port 0
    .data0  ( prom_din  ),
    .addr0  ( prog_addr ),
    .we0    ( prom_we   ),
    .q0     (           ),
    // Port 1
    .data1  (           ),
    .addr1  ( rom_addr[11:0]  ),
    .we1    ( 1'b0      ),
    .q1     ( rom_data  )
);

jtframe_ram #(.aw(7),.cen_rd(1)) u_ramu(
    .clk        ( clk               ),
    .cen        ( cen               ),
    .addr       ( ram_addr          ),
    .data       ( ram_data          ),
    .we         ( ram_we            ),
    .q          ( ram_q             )
);

mc8051_core u_mcu(
    .reset      ( rst       ),
    .clk        ( clkx      ),
    .cen        ( 1'b1      ),  // this input is not reliable
    // code ROM
    .rom_data_i ( rom_data  ),
    .rom_adr_o  ( rom_addr  ),
    // internal RAM
    .ram_data_i ( ram_q     ),
    .ram_data_o ( ram_data  ),
    .ram_adr_o  ( ram_addr  ),
    .ram_wr_o   ( ram_we    ),
    .ram_en_o   (           ),
    // external memory: connected to main CPU
    .datax_i    ( xin_sync  ),
    .datax_o    ( x_dout    ),
    .adrx_o     ( x_addr    ),
    .wrx_o      ( x_wr      ),
    // interrupts
    .int0_i     ( int0n     ),
    .int1_i     ( int1n     ),
    // counters
    .all_t0_i   ( 1'b0      ),
    .all_t1_i   ( 1'b0      ),
    // serial interface
    .all_rxd_i  ( 1'b0      ),
    .all_rxd_o  (           ),
    // Ports
    .p0_i       ( p0_s      ),
    .p0_o       ( p0_o      ),

    .p1_i       ( p1_s      ),
    .p1_o       ( p1_o      ),

    .p2_i       ( p2_s      ),
    .p2_o       ( p2_o      ),

    .p3_i       ( p3_s      ),
    .p3_o       ( p3_o      )
);

endmodule