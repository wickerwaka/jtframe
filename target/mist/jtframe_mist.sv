/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 7-3-2019 */

module jtframe_mist #(parameter
    SIGNED_SND             = 1'b0,
    BUTTONS                = 2,
    DIPBASE                = 16,
    GAME_INPUTS_ACTIVE_LOW = 1'b1,
    COLORW                 = 4,
    VIDEO_WIDTH            = 384,
    VIDEO_HEIGHT           = 224,
    SDRAMW                 = 23
)(
    input           clk_sys,
    input           clk_rom,
    input           clk_pico,
    input           pll_locked,
    // interface with microcontroller
    output  [63:0]  status,
    // Base video
    input [COLORW-1:0] game_r,
    input [COLORW-1:0] game_g,
    input [COLORW-1:0] game_b,
    input              LHBL,
    input              LVBL,
    input              hs,
    input              vs,
    input              pxl_cen,
    input              pxl2_cen,
    // LED
    input        [1:0] game_led,
    // MiST VGA pins
    output       [5:0] VGA_R,
    output       [5:0] VGA_G,
    output       [5:0] VGA_B,
    output             VGA_HS,
    output             VGA_VS,
    // ROM programming
    input  [SDRAMW-1:0] prog_addr,
    input        [15:0] prog_data,
    input        [ 1:0] prog_mask,
    input        [ 1:0] prog_ba,
    input               prog_we,
    input               prog_rd,
    output              prog_dst,
    output              prog_dok,
    output              prog_rdy,
    output              prog_ack,
    // ROM access from game
    input  [SDRAMW-1:0] ba0_addr,
    input  [SDRAMW-1:0] ba1_addr,
    input  [SDRAMW-1:0] ba2_addr,
    input  [SDRAMW-1:0] ba3_addr,
    input         [3:0] ba_rd,
    input         [3:0] ba_wr,
    output        [3:0] ba_ack,
    output        [3:0] ba_rdy,
    output        [3:0] ba_dst,
    output        [3:0] ba_dok,
    input        [15:0] ba0_din,
    input        [ 1:0] ba0_din_m,  // write mask
    output       [15:0] sdram_dout,
    // UART
    input           uart_rx,
    output          uart_tx,
    // SDRAM interface
    inout    [15:0] SDRAM_DQ,       // SDRAM Data bus 16 Bits
    output   [12:0] SDRAM_A,        // SDRAM Address bus 13 Bits
    output          SDRAM_DQML,     // SDRAM Low-byte Data Mask
    output          SDRAM_DQMH,     // SDRAM High-byte Data Mask
    output          SDRAM_nWE,      // SDRAM Write Enable
    output          SDRAM_nCAS,     // SDRAM Column Address Strobe
    output          SDRAM_nRAS,     // SDRAM Row Address Strobe
    output          SDRAM_nCS,      // SDRAM Chip Select
    output    [1:0] SDRAM_BA,       // SDRAM Bank Address
    output          SDRAM_CKE,      // SDRAM Clock Enable
    // SPI interface to arm io controller
    inout           SPI_DO,
    input           SPI_DI,
    input           SPI_SCK,
    input           SPI_SS2,
    input           SPI_SS3,
    input           SPI_SS4,
    input           CONF_DATA0,
    // Buttons for MC2(+)
    input    [ 3:0] BUTTON_n,
    // PS2 are input pins for Neptuno
    // and outputs for MiST
    inout           ps2_clk,
    inout           ps2_dout,
    // Joystick
    input     [5:0] joy1_bus,
    input     [5:0] joy2_bus,
    output          JOY_SELECT,
    // ROM load from SPI
    output   [24:0] ioctl_addr,
    output   [ 7:0] ioctl_dout,
    output          ioctl_wr,
    input    [ 7:0] ioctl_din,
    output          ioctl_ram,
    input           dwnld_busy,
    output          downloading,

//////////// board
    output          rst,      // synchronous reset
    output          rst_n,    // asynchronous reset
    output          game_rst,
    output          game_rst_n,
    // reset forcing signals:
    input           rst_req,
    // Sound
    input   [15:0]  snd_left,
    input   [15:0]  snd_right,
    input           snd_sample,
    output          AUDIO_L,
    output          AUDIO_R,
    // joystick
    output   [9:0]  game_joystick1,
    output   [9:0]  game_joystick2,
    output   [9:0]  game_joystick3,
    output   [9:0]  game_joystick4,
    output   [3:0]  game_coin,
    output   [3:0]  game_start,
    output          game_service,
    output  [15:0]  joyana_l1,
    output  [15:0]  joyana_r1,
    output  [15:0]  joyana_l2,
    output  [15:0]  joyana_r2,
    output  [15:0]  joyana_l3,
    output  [15:0]  joyana_r3,
    output  [15:0]  joyana_l4,
    output  [15:0]  joyana_r4,
    // DIP and OSD settings
    output          enable_fm,
    output          enable_psg,

    output          dip_test,
    // non standard:
    output          dip_pause,
    inout           dip_flip,     // A change in dip_flip implies a reset
    output  [ 1:0]  dip_fxlevel,
    // Debug
    output          LED,
    output   [ 7:0] st_addr,
    input    [ 7:0] st_dout,
    output   [3:0]  gfx_en,
    output   [7:0]  debug_bus,
    input    [7:0]  debug_view
);

// control
wire [31:0]   joystick1, joystick2, joystick3, joystick4;
wire [63:0] board_status;
wire          ps2_kbd_clk, ps2_kbd_data;
wire          osd_shown;

wire [7:0]    scan2x_r, scan2x_g, scan2x_b;
wire          scan2x_hs, scan2x_vs, scan2x_clk;
wire          scan2x_enb;
wire [6:0]    core_mod;
wire [3:0]    but_start, but_coin;

wire  [ 1:0]  rotate;
wire          ioctl_cheat, sdram_init;

wire  [15:0]  board_left, board_right;

assign board_status = { {64-DIPBASE{1'b0}}, status[DIPBASE-1:0] };

jtframe_mist_base #(
    .SIGNED_SND     ( SIGNED_SND    ),
    .COLORW         ( COLORW        )
) u_base(
    .rst            ( rst           ),
    .sdram_init     ( sdram_init    ),
    .clk_sys        ( clk_sys       ),
    .clk_rom        ( clk_rom       ),
    .core_mod       ( core_mod      ),
    .osd_shown      ( osd_shown     ),
    // Base video
    .osd_rotate     ( rotate        ),
    .game_r         ( game_r        ),
    .game_g         ( game_g        ),
    .game_b         ( game_b        ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .hs             ( hs            ),
    .vs             ( vs            ),
    .pxl_cen        ( pxl_cen       ),
    // Scan-doubler video
    .scan2x_r       ( scan2x_r[7:2] ),
    .scan2x_g       ( scan2x_g[7:2] ),
    .scan2x_b       ( scan2x_b[7:2] ),
    .scan2x_hs      ( scan2x_hs     ),
    .scan2x_vs      ( scan2x_vs     ),
    .scan2x_enb     ( scan2x_enb    ),
    .scan2x_clk     ( scan2x_clk    ),
    // MiST VGA pins (includes OSD)
    .VIDEO_R        ( VGA_R         ),
    .VIDEO_G        ( VGA_G         ),
    .VIDEO_B        ( VGA_B         ),
    .VIDEO_HS       ( VGA_HS        ),
    .VIDEO_VS       ( VGA_VS        ),
    // SPI interface to arm io controller
    .SPI_DO         ( SPI_DO        ),
    .SPI_DI         ( SPI_DI        ),
    .SPI_SCK        ( SPI_SCK       ),
    .SPI_SS2        ( SPI_SS2       ),
`ifndef NEPTUNO
    .SPI_SS3        ( SPI_SS3       ),
    .SPI_SS4        ( SPI_SS4       ),
`else
    .SPI_SS3        ( SPI_SS2       ),  // SS2 reused on NeptUNO for OSD
    .SPI_SS4        (               ),
`endif
    .CONF_DATA0     ( CONF_DATA0    ),
    // control
    .status         ( status        ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .joystick3      ( joystick3     ),
    .joystick4      ( joystick4     ),
    .but_start      ( but_start     ),
    .but_coin       ( but_coin      ),
    // Analog joystick
    .joyana_l1      ( joyana_l1     ),
    .joyana_r1      ( joyana_r1     ),
    .joyana_l2      ( joyana_l2     ),
    .joyana_r2      ( joyana_r2     ),
    .joyana_l3      ( joyana_l3     ),
    .joyana_r3      ( joyana_r3     ),
    .joyana_l4      ( joyana_l4     ),
    .joyana_r4      ( joyana_r4     ),
    // Keyboard
    .ps2_kbd_clk    ( ps2_clk       ),
    .ps2_kbd_data   ( ps2_dout      ),
    // Direct joystick connection (Neptuno / MC)
    .joy1_bus       ( joy1_bus      ),
    .joy2_bus       ( joy2_bus      ),
    .JOY_SELECT     ( JOY_SELECT    ),
    // MC2(+) buttons
    .BUTTON_n       ( BUTTON_n      ),
    // audio
    .clk_dac        ( clk_sys       ),
    .snd_left       ( board_left    ),
    .snd_right      ( board_right   ),
    .snd_pwm_left   ( AUDIO_L       ),
    .snd_pwm_right  ( AUDIO_R       ),
    // ROM load from SPI
    .ioctl_addr     ( ioctl_addr    ),
    .ioctl_dout     ( ioctl_dout    ),
    .ioctl_din      ( ioctl_din     ),
    .ioctl_wr       ( ioctl_wr      ),
    .ioctl_ram      ( ioctl_ram     ),
    .ioctl_cheat    ( ioctl_cheat   ),
    .downloading    ( downloading   )
);

jtframe_board #(
    .BUTTONS               ( BUTTONS               ),
    .GAME_INPUTS_ACTIVE_LOW( GAME_INPUTS_ACTIVE_LOW),
    .COLORW                ( COLORW                ),
    .VIDEO_WIDTH           ( VIDEO_WIDTH           ),
    .VIDEO_HEIGHT          ( VIDEO_HEIGHT          ),
    .SDRAMW                ( SDRAMW                ),
    .MISTER                ( 0                     )
) u_board(
    .rst            ( rst             ),
    .rst_n          ( rst_n           ),
    .game_rst       ( game_rst        ),
    .game_rst_n     ( game_rst_n      ),
    .rst_req        ( rst_req         ),
    .sdram_init     ( sdram_init      ),
    .pll_locked     ( pll_locked      ),
    .downloading    ( dwnld_busy      ), // use busy signal from game module

    .clk_sys        ( clk_sys         ),
    .clk_rom        ( clk_rom         ),
    .clk_pico       ( clk_pico        ),
    .core_mod       ( core_mod        ),
    // Sound
    .snd_lin        ( snd_left        ),
    .snd_rin        ( snd_right       ),
    .snd_lout       ( board_left      ),
    .snd_rout       ( board_right     ),
    .snd_sample     ( snd_sample      ),
    // joystick
    .ps2_kbd_clk    ( ps2_clk         ),
    .ps2_kbd_data   ( ps2_dout        ),
    .board_joystick1( joystick1[15:0] ),
    .board_joystick2( joystick2[15:0] ),
    .board_joystick3( joystick3[15:0] ),
    .board_joystick4( joystick4[15:0] ),
    .joyana_l1      ( joyana_l1       ),
    .joyana_r1      ( joyana_r1       ),
    .joyana_l2      ( joyana_l2       ),
    .joyana_r2      ( joyana_r2       ),
    .board_start    ( but_start       ),
    .board_coin     ( but_coin        ),
    .game_joystick1 ( game_joystick1  ),
    .game_joystick2 ( game_joystick2  ),
    .game_joystick3 ( game_joystick3  ),
    .game_joystick4 ( game_joystick4  ),
    .game_coin      ( game_coin       ),
    .game_start     ( game_start      ),
    .game_service   ( game_service    ),
    // DIP and OSD settings
    .status         ( board_status    ),
    .enable_fm      ( enable_fm       ),
    .enable_psg     ( enable_psg      ),
    .dip_test       ( dip_test        ),
    .dip_pause      ( dip_pause       ),
    .dip_flip       ( dip_flip        ),
    .dip_fxlevel    ( dip_fxlevel     ),
    .timestamp      ( 32'd0           ), // MiST doesn't -normally- have a RTC
    // screen
    .rotate         ( rotate          ),
    // LED
    .osd_shown      ( osd_shown       ),
    .game_led       ( game_led        ),
    .led            ( LED             ),
    // UART
    .uart_rx        ( uart_rx         ),
    .uart_tx        ( uart_tx         ),
    // SDRAM interface
    // Bank 0: allows R/W
    .ba0_addr   ( ba0_addr      ),
    .ba1_addr   ( ba1_addr      ),
    .ba2_addr   ( ba2_addr      ),
    .ba3_addr   ( ba3_addr      ),
    .ba_rd      ( ba_rd         ),
    .ba_wr      ( ba_wr         ),
    .ba_dst     ( ba_dst        ),
    .ba_dok     ( ba_dok        ),
    .ba_rdy     ( ba_rdy        ),
    .ba_ack     ( ba_ack        ),
    .ba0_din    ( ba0_din       ),
    .ba0_din_m  ( ba0_din_m     ),  // write mask

    // ROM-load interface
    .prog_addr  ( prog_addr     ),
    .prog_ba    ( prog_ba       ),
    .prog_rd    ( prog_rd       ),
    .prog_we    ( prog_we       ),
    .prog_data  ( prog_data     ),
    .prog_mask  ( prog_mask     ),
    .prog_rdy   ( prog_rdy      ),
    .prog_dst   ( prog_dst      ),
    .prog_dok   ( prog_dok      ),
    .prog_ack   ( prog_ack      ),
    // SDRAM interface
    .SDRAM_DQ   ( SDRAM_DQ      ),
    .SDRAM_A    ( SDRAM_A       ),
    .SDRAM_DQML ( SDRAM_DQML    ),
    .SDRAM_DQMH ( SDRAM_DQMH    ),
    .SDRAM_nWE  ( SDRAM_nWE     ),
    .SDRAM_nCAS ( SDRAM_nCAS    ),
    .SDRAM_nRAS ( SDRAM_nRAS    ),
    .SDRAM_nCS  ( SDRAM_nCS     ),
    .SDRAM_BA   ( SDRAM_BA      ),
    .SDRAM_CKE  ( SDRAM_CKE     ),

    // Common signals
    .sdram_dout ( sdram_dout    ),

    // Cheat!
    .cheat      ( status[63:32] ),
    .prog_cheat ( ioctl_cheat   ),
    .prog_lock  ( 1'b0          ),  // locking is not needed on MiST
    .ioctl_wr   ( ioctl_wr      ),
    .ioctl_dout ( ioctl_dout    ),
    .ioctl_addr ( ioctl_addr[7:0]),
    .st_addr    ( st_addr       ),
    .st_dout    ( st_dout       ),

    // Base video
    .osd_rotate     ( rotate          ),
    .game_r         ( game_r          ),
    .game_g         ( game_g          ),
    .game_b         ( game_b          ),
    .LHBL           ( LHBL            ),
    .LVBL           ( LVBL            ),
    .hs             ( hs              ),
    .vs             ( vs              ),
    .pxl_cen        ( pxl_cen         ),
    .pxl2_cen       ( pxl2_cen        ),
    // Scan-doubler video
    .scan2x_r       ( scan2x_r        ),
    .scan2x_g       ( scan2x_g        ),
    .scan2x_b       ( scan2x_b        ),
    .scan2x_hs      ( scan2x_hs       ),
    .scan2x_vs      ( scan2x_vs       ),
    .scan2x_enb     ( scan2x_enb      ),
    .scan2x_clk     ( scan2x_clk      ),
    // Debug
    .gfx_en         ( gfx_en          ),
    .debug_bus      ( debug_bus       ),
    .debug_view     ( debug_view      ),
    // Unused ports (MiSTer)
    .gamma_bus      (                 ),
    .direct_video   ( 1'b0            ),
    .hdmi_arx       (                 ),
    .hdmi_ary       (                 ),
    .scan2x_cen     (                 ),
    .scan2x_de      (                 ),
    .scan2x_sl      (                 )
);

endmodule // jtframe