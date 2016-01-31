# BK0011M for [MIST Board](https://github.com/mist-devel/mist-board/wiki)

This project of [popular USSR home computer](https://en.wikipedia.org/wiki/Electronika_BK) is based on precise [KR1801VM1](http://zx-pk.ru/showthread.php?t=23978) Verilog model by Vslav

### Features:
- Fully functional BK0011M and BK0010 with close to real CPU and Video timings (need furter corrections).
- Raw DSK image support (read-only, Disk A)
- Multipatitioned VHD image (read-write, Disk C+)
- A16M extension for BK0010 (support for short and long resets)
- AY8910 Sound with 1.71MHz clock
- Joystick
- Mouse

### Planned features:
- single file loading from OSD
- simulate tape loading (maybe)

### Installation:
Copy the *.rbf file at the root of the SD card. You can rename the file to core.rbf if you want the MiST to load it automatically at startup.

Copy [bk0011m.rom](https://github.com/sorgelig/BK0011M/tree/master/releases) to root of SD card.

For PAL mode (RGBS output) you need to put [mist.ini](https://github.com/sorgelig/ZX_Spectrum-128K_MIST/tree/master/releases/mist.ini) file to the root of SD card. Set the option **scandoubler_disable** for desired video output.

There are couple disk images in [extra](https://github.com/sorgelig/BK0011M/tree/master/releases) folder with CSIDOS OS with complete ecosystem (viewer,text editor, music editor, debugger, etc.) written by me more than 20 years ago. Image also incudes some music and utils written by different people.

*Most documents are in Russian languange.*

### HDD Utility
Supplied [HDD Utility](https://github.com/sorgelig/BK0011M/blob/master/SW/bkhdutil.exe) can be used to concatenate separate DSK image into one VHD image. You can put it to root of SD card. If you will name it as bk0011m.vhd then it will autoload at start (requires IO firmware update).

Press F12 to access OSD menu.

##### Keyboard map:

| PC key      |  BK Key   |
|:-----------:|:---------:|
| ESC         | KT        |
| F1          | ПОВТ      |
| F2          | ВС        |
| F3          | ГРАФ      |
| F4          | <--!      |
| F5          | !-->      |
| F6          | ИНДСУ     |
| F7          | БЛОК РЕД  |
| F8          | ШАГ       |
| F9          | СБР       |
| F10         | СТОП      |
| Ctrl+F11    | RESET     |
| F12         | OSD Menu  |
| Insert      | !-->      |
| delete      | -!->      |
| shift+enter | УСТ ТАБ   |
| shift+tab   | СБР ТАБ   |
| alt+tab     | ШАГ ПО ТАБ|
| Right Alt   | ЛАТ       |
| Right Ctrl  | РУС       |

### Download precompiled binaries:
Go to [releases](https://github.com/sorgelig/BK0011M/tree/master/releases) folder.
