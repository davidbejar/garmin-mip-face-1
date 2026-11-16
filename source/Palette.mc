import Toybox.Lang;

//! Colours from design/spec.md §5. Every value uses only 00/55/AA/FF per channel
//! (the 64 MIP colours). TEXT and ACCENT become settings in milestone 8.
module Palette {
    const BACKGROUND = 0xFFFFFF;
    const TEXT = 0x000000;
    const ACCENT = 0xFF5500;
    const LABEL = 0x555555;
    const TRACK = 0xAAAAAA;
    const DATE_TEXT = 0xFFFFFF;
}
