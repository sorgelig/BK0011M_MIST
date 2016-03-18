// ==================================================================================
// BK in FPGA
// ----------------------------------------------------------------------------------
//
// A BK-0010 FPGA Replica. Keyboard codes translator.
//
// This project is a work of many people. See file README for further information.
//
// Based on the original BK-0010 code by Alex Freed.
// ==================================================================================

`default_nettype none

module kbd_transl
(
	input        shift,
	input        e0,
	input  [7:0] incode,
	output [6:0] outcode,
	output       autoar2
);

assign autoar2 = ascii[7];
assign outcode = ascii[6:0];

reg [7:0] ascii;

// 
// A decent scancode table can be found here
// http://www.computer-engineering.org/ps2keyboard/scancodes2.html
//  

// This part translates the scan code into an ASCII value...
// Only the ASCII codes which I considered important have been included.
// if you want more, just add the appropriate case statement lines...
// (You will need to know the keyboard scan codes you wish to assign.)
// The entries are listed in ascending order of ASCII value.
always @* begin
    ascii = 0;
    casex({shift, incode})
    9'HX29: ascii = 7'H20; // Space
    9'H116: ascii = 7'H21; // !
    9'H152: ascii = 7'H22; // "
    9'H126: ascii = 7'H23; // #
    9'H125: ascii = 7'H24; // $
    9'H12e: ascii = 7'H25; //
    9'H13d: ascii = 7'H26; //
    9'H052: ascii = 7'H27; //
    9'H146: ascii = 7'H28; //
    9'H145: ascii = 7'H29; //
    9'H13e: ascii = 7'H2a; // *
    9'H155: ascii = 7'H2b; // +
    9'H041: ascii = 7'H2c; // ,
    9'H04e: ascii = 7'H2d; // -
    9'H049: ascii = 7'H2e; // .
    9'H04a: ascii = 7'H2f; // /
    9'H045: ascii = 7'H30; // 0
    9'H016: ascii = 7'H31; // 1
    9'H01e: ascii = 7'H32; // 2
    9'H026: ascii = 7'H33; // 3
    9'H025: ascii = 7'H34; // 4
    9'H02e: ascii = 7'H35; // 5
    9'H036: ascii = 7'H36; // 6
    9'H03d: ascii = 7'H37; // 7
    9'H03e: ascii = 7'H38; // 8
    9'H046: ascii = 7'H39; // 9
    9'H14c: ascii = 7'H3a; // :
    9'H04c: ascii = 7'H3b; // ;
    9'H141: ascii = 7'H3c; // <
    9'H055: ascii = 7'H3d; // =
    9'H149: ascii = 7'H3e; // >
    9'H14a: ascii = 7'H3f; // ?
    9'H11e: ascii = 7'H40; // @
    9'H11c: ascii = 7'H41; // A
    9'H132: ascii = 7'H42; // B
    9'H121: ascii = 7'H43; // C
    9'H123: ascii = 7'H44; // D
    9'H124: ascii = 7'H45; // E
    9'H12b: ascii = 7'H46; // F
    9'H134: ascii = 7'H47; // G
    9'H133: ascii = 7'H48; // H
    9'H143: ascii = 7'H49; // I
    9'H13b: ascii = 7'H4a; // J
    9'H142: ascii = 7'H4b; // K
    9'H14b: ascii = 7'H4c; // L
    9'H13a: ascii = 7'H4d; // M
    9'H131: ascii = 7'H4e; // N
    9'H144: ascii = 7'H4f; // O
    9'H14d: ascii = 7'H50; // P
    9'H115: ascii = 7'H51; // Q
    9'H12d: ascii = 7'H52; // R
    9'H11b: ascii = 7'H53; // S
    9'H12c: ascii = 7'H54; // T
    9'H13c: ascii = 7'H55; // U
    9'H12a: ascii = 7'H56; // V
    9'H11d: ascii = 7'H57; // W
    9'H122: ascii = 7'H58; // X
    9'H135: ascii = 7'H59; // Y
    9'H11a: ascii = 7'H5a; // Z
    9'H054: ascii = 7'H5b; // [
    9'H05d: ascii = 7'H5c; // \
    9'H05b: ascii = 7'H5d; // ]
    9'H136: ascii = 7'H5e; // ^
    9'H14e: ascii = 7'H5f; // _    
    9'H00e: ascii = 7'H60; // `
    9'H01c: ascii = 7'H61; // a
    9'H032: ascii = 7'H62; // b
    9'H021: ascii = 7'H63; // c
    9'H023: ascii = 7'H64; // d
    9'H024: ascii = 7'H65; // e
    9'H02b: ascii = 7'H66; // f
    9'H034: ascii = 7'H67; // g
    9'H033: ascii = 7'H68; // h
    9'H043: ascii = 7'H69; // i
    9'H03b: ascii = 7'H6a; // j
    9'H042: ascii = 7'H6b; // k
    9'H04b: ascii = 7'H6c; // l
    9'H03a: ascii = 7'H6d; // m
    9'H031: ascii = 7'H6e; // n
    9'H044: ascii = 7'H6f; // o
    9'H04d: ascii = 7'H70; // p
    9'H015: ascii = 7'H71; // q
    9'H02d: ascii = 7'H72; // r
    9'H01b: ascii = 7'H73; // s
    9'H02c: ascii = 7'H74; // t
    9'H03c: ascii = 7'H75; // u
    9'H02a: ascii = 7'H76; // v
    9'H01d: ascii = 7'H77; // w
    9'H022: ascii = 7'H78; // x
    9'H035: ascii = 7'H79; // y
    9'H01a: ascii = 7'H7a; // z
    9'H154: ascii = 7'H7b; // {
    9'H15d: ascii = 7'H7c; // |
    9'H15b: ascii = 7'H7d; // }
    9'H10e: ascii = 7'H7e; // ~

    9'hX66: ascii = 8'o030; // Backspace - was 'h8 but delete last char is 030
    9'H00d: ascii = 8'o011; // Tab
    9'H10d: ascii = 8'o020; // Clear Tab
    9'H15a: ascii = 8'o015; // Set Tab
    9'HX76: ascii = 8'o003; // ESC - KT
    9'H05a: ascii = 8'o012; // Enter
    9'HX71: ascii = 8'o026; // Delete - |<=
    9'HX70: ascii = 8'o027; // Insert - |=>
    9'HX75: ascii = 8'o032; // arrow up
    9'HX72: ascii = 8'o033; // arrow down
    9'HX6B: ascii = 8'o010; // arrow left
    9'HX74: ascii = 8'o031; // arrow right
    9'HX6C: ascii = 8'o034; // arrow up-left
    9'HX7D: ascii = 8'o035; // arrow up-right
    9'HX69: ascii = 8'o037; // arrow down-left
    9'HX7A: ascii = 8'o036; // arrow down-right
    9'HX05: ascii = 8'o201; // F1 - POVT
    9'HX06: ascii = 8'o023; // F2 - BC
    9'HX04: ascii = 8'o225; // F3 - Graphics
    //9'HX0c: ascii         // F4 -
    9'hX03: ascii = 8'o231; // F5 - Kill EOL
    9'hX0b: ascii = 8'o202; // F6 - IND SU
    9'hX83: ascii = 8'o204; // F7 - BLK RED
    9'hX0a: ascii = 8'o220; // F8 - SHAG
    9'HX01: ascii = 8'o014; // F9 - SBR

    9'hX14: if (~e0) ascii = 8'o016; // LCtrl - RUS
    9'HX1F: if (e0)  ascii = 8'o017; // LWin  - LAT
    9'HX27: if (e0)  ascii = 8'o017; // RWin  - LAT

    default: ascii = 7'H00;// 0x00 used for unlisted characters.
    endcase
end

endmodule
