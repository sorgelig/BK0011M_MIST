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

module kbd_transl(shift, e0, incode, outcode, autoar2);
input             shift;
input             e0;
input       [7:0] incode;
output      [6:0] outcode;
output reg       	autoar2;

reg         [6:0]   ascii;
wire        [8:0]   shift_key_plus_code;

assign outcode = ascii;
assign shift_key_plus_code = {shift, incode};

// 
// A decent scancode table can be found here
// http://www.computer-engineering.org/ps2keyboard/scancodes2.html
//  

// This part translates the scan code into an ASCII value...
// Only the ASCII codes which I considered important have been included.
// if you want more, just add the appropriate case statement lines...
// (You will need to know the keyboard scan codes you wish to assign.)
// The entries are listed in ascending order of ASCII value.
always @(shift_key_plus_code, e0) begin
    autoar2 = 0;
    ascii = 0;
    case(shift_key_plus_code)
    9'h066,
    9'h166 : begin
      // Backspace ("backspace" key)
      ascii = 7'o30; // was 'h8 but delete last char is 030
    end
    9'H00d : begin
      ascii = 7'o11;  // Tab
    end
    9'H10d : begin
      ascii = 7'o20;  // clear Tab
    end
    
    9'H05a : begin
      if (~e0) ascii = 7'H0a;
      // Carriage return ("enter" key)
    end
    9'H15a : begin
      if (~e0) ascii = 7'H0d;
      // Carriage return ("enter" key)
    end
    9'H076,
    9'H176 : begin
      ascii = 7'o003; 
      // Escape ("esc" key)
    end
    9'H029 : begin
      ascii = 7'H20;
      // Space
    end
    9'H129 : begin
      ascii = 7'H20;
      // Space
    end

    9'H116 : begin
      ascii = 7'H21;
      // !
    end
    9'H152 : begin
      ascii = 7'H22;
      // "
    end
    9'H126 : begin
      ascii = 7'H23;
      // #
    end
    9'H125 : begin
      ascii = 7'H24;
      // $
    end
    9'H12e : begin
      ascii = 7'H25;
      //
    end
    9'H13d : begin
      ascii = 7'H26;
      //
    end
    9'H052 : begin
      ascii = 7'H27;
      //
    end
    9'H146 : begin
      ascii = 7'H28;
      //
    end
    9'H145 : begin
      ascii = 7'H29;
      //
    end
    9'H13e : begin
      ascii = 7'H2a;
      // *
    end
    9'H155 : begin
      ascii = 7'H2b;
      // +
    end
    9'H041 : begin
      ascii = 7'H2c;
      // ,
    end
    9'H04e : begin
      ascii = 7'H2d;
      // -
    end
    9'H049 : begin
      ascii = 7'H2e;
      // .
    end
    9'H04a : begin
      if (~e0) ascii = 7'H2f;
      // /
    end
    9'H045 : begin
      ascii = 7'H30;
      // 0
    end
    9'H016 : begin
      ascii = 7'H31;
      // 1
    end
    9'H01e : begin
      ascii = 7'H32;
      // 2
    end
    9'H026 : begin
      ascii = 7'H33;
      // 3
    end
    9'H025 : begin
      ascii = 7'H34;
      // 4
    end
    9'H02e : begin
      ascii = 7'H35;
      // 5
    end
    9'H036 : begin
      ascii = 7'H36;
      // 6
    end
    9'H03d : begin
      ascii = 7'H37;
      // 7
    end
    9'H03e : begin
      ascii = 7'H38;
      // 8
    end
    9'H046 : begin
      ascii = 7'H39;
      // 9
    end
    9'H14c : begin
      ascii = 7'H3a;
      // :
    end
    9'H04c : begin
      ascii = 7'H3b;
      // ;
    end
    9'H141 : begin
      ascii = 7'H3c;
      // <
    end
    9'H055 : begin
      ascii = 7'H3d;
      // =
    end
    9'H149 : begin
      ascii = 7'H3e;
      // >
    end
    9'H14a : begin
      ascii = 7'H3f;
      // ?
    end
    9'H11e : begin
      ascii = 7'H40;
      // @
    end
    9'H11c : begin
      ascii = 7'H41;
      // A
    end
    9'H132 : begin
      ascii = 7'H42;
      // B
    end
    9'H121 : begin
      ascii = 7'H43;
      // C
    end
    9'H123 : begin
      ascii = 7'H44;
      // D
    end
    9'H124 : begin
      ascii = 7'H45;
      // E
    end
    9'H12b : begin
      ascii = 7'H46;
      // F
    end
    9'H134 : begin
      ascii = 7'H47;
      // G
    end
    9'H133 : begin
      ascii = 7'H48;
      // H
    end
    9'H143 : begin
      ascii = 7'H49;
      // I
    end
    9'H13b : begin
      ascii = 7'H4a;
      // J
    end
    9'H142 : begin
      ascii = 7'H4b;
      // K
    end
    9'H14b : begin
      ascii = 7'H4c;
      // L
    end
    9'H13a : begin
      ascii = 7'H4d;
      // M
    end
    9'H131 : begin
      ascii = 7'H4e;
      // N
    end
    9'H144 : begin
      ascii = 7'H4f;
      // O
    end
    9'H14d : begin
      ascii = 7'H50;
      // P
    end
    9'H115 : begin
      ascii = 7'H51;
      // Q
    end
    9'H12d : begin
      ascii = 7'H52;
      // R
    end
    9'H11b : begin
      ascii = 7'H53;
      // S
    end
    9'H12c : begin
      ascii = 7'H54;
      // T
    end
    9'H13c : begin
      ascii = 7'H55;
      // U
    end
    9'H12a : begin
      ascii = 7'H56;
      // V
    end
    9'H11d : begin
      ascii = 7'H57;
      // W
    end
    9'H122 : begin
      ascii = 7'H58;
      // X
    end
    9'H135 : begin
      ascii = 7'H59;
      // Y
    end
    9'H11a : begin
      ascii = 7'H5a;
      // Z
    end
    9'H054 : begin
      ascii = 7'H5b;
      // [
    end
    9'H05d : begin
      ascii = 7'H5c;
      // \
    end
    9'H05b : begin
      ascii = 7'H5d;
      // ]
    end
    9'H136 : begin
      ascii = 7'H5e;
      // ^
    end
    9'H14e : begin
      ascii = 7'H5f;
      // _    
    end
    9'H00e : begin
      ascii = 7'H60;
      // `
    end
    9'H01c : begin
      ascii = 7'H61;
      // a
    end
    9'H032 : begin
      ascii = 7'H62;
      // b
    end
    9'H021 : begin
      ascii = 7'H63;
      // c
    end
    9'H023 : begin
      ascii = 7'H64;
      // d
    end
    9'H024 : begin
      ascii = 7'H65;
      // e
    end
    9'H02b : begin
      ascii = 7'H66;
      // f
    end
    9'H034 : begin
      ascii = 7'H67;
      // g
    end
    9'H033 : begin
      ascii = 7'H68;
      // h
    end
    9'H043 : begin
      ascii = 7'H69;
      // i
    end
    9'H03b : begin
      ascii = 7'H6a;
      // j
    end
    9'H042 : begin
      ascii = 7'H6b;
      // k
    end
    9'H04b : begin
      ascii = 7'H6c;
      // l
    end
    9'H03a : begin
      ascii = 7'H6d;
      // m
    end
    9'H031 : begin
      ascii = 7'H6e;
      // n
    end
    9'H044 : begin
      ascii = 7'H6f;
      // o
    end
    9'H04d : begin
      ascii = 7'H70;
      // p
    end
    9'H015 : begin
      ascii = 7'H71;
      // q
    end
    9'H02d : begin
      ascii = 7'H72;
      // r
    end
    9'H01b : begin
      ascii = 7'H73;
      // s
    end
    9'H02c : begin
      ascii = 7'H74;
      // t
    end
    9'H03c : begin
      ascii = 7'H75;
      // u
    end
    9'H02a : begin
      ascii = 7'H76;
      // v
    end
    9'H01d : begin
      ascii = 7'H77;
      // w
    end
    9'H022 : begin
      ascii = 7'H78;
      // x
    end
    9'H035 : begin
      ascii = 7'H79;
      // y
    end
    9'H01a : begin
      ascii = 7'H7a;
      // z
    end
    9'H154 : begin
      ascii = 7'H7b;
      // {
    end
    9'H15d : begin
      ascii = 7'H7c;
      // |
    end
    9'H15b : begin
      ascii = 7'H7d;
      // }
    end
    9'H10e : begin
      ascii = 7'H7e;
      // ~
    end

    
    9'H071, // (Delete)
    9'H171: if (e0) begin // Kill EOL
                autoar2 = 1;
                ascii = 7'o231;
            end

    9'H070,                            // Insert
    9'H170  : if (e0) ascii = 7'o027;  // |=>

    9'H075, 
    9'H175  : if (e0) ascii = 7'o032;  // arrow up

    9'H072,
    9'H172  : if (e0) ascii = 7'o033;  // arrow down

    9'H06B,
    9'H16B  : if (e0) ascii = 7'o010;  // arrow left

    9'H074,
    9'H174  : if (e0) ascii = 7'o031;  // arrow right

    9'H06C,    // BC/Home
    9'H16C  : if(e0) ascii = 7'o023; else ascii = 7'o034;  // arrow up-left

    9'H07D,
    9'H17D  : ascii = 7'o035;  // arrow up-right

    9'H069,
    9'H169  : ascii = 7'o037;  // arrow down-left

    9'H07A,
    9'H17A  : ascii = 7'o036;  // arrow down-right

    9'h114,
    9'h014  : if (e0) ascii = 7'o016;  // RUS (CapsLock)
    9'h111,
    9'h011  : if (e0) ascii = 7'o017;  // LAT (RShift)

    9'H005, // POVT! (F1)
    9'H105  : 
            begin
                autoar2 = 1;
                ascii = 7'o201;
            end
            
    9'H006, // F2 - BC
    9'H106  : ascii = 7'o023; 
    
    
    9'H004, // F3 - Graphics
    9'H104  : 
            begin
                autoar2 = 1;
                ascii = 7'o225;
            end
            
    9'H00c, // del at cursor (F4)
    9'H10c  : ascii = 7'o26; 
    
    // F5 |=>
    9'h003,
    9'h103: ascii = 7'o027;
    
    // F6: IND SU
    9'h00b,
    9'h10b  : 
            begin
                ascii = 7'o202;
                autoar2 = 1;
            end
            
    // F7: BLK RED
    9'h083,
    9'h183  :
            begin
                ascii = 7'o204;
                autoar2 = 1;
            end
            
    // F8: SHAG
    9'h00a,
    9'h10a  :
            begin
                ascii = 7'o220;
                autoar2 = 1;
            end
            
    9'H001:   ascii = 7'o014;  // SBR (F9)
    default : ascii = 7'H00;   // 0x00 used for unlisted characters.
    endcase
end

endmodule
