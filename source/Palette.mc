import Toybox.Lang;

//! Fixed colours from design/spec.md §5. Every value uses only 00/55/AA/FF per
//! channel (the 64 MIP colours). The text and accent colours are settings: see
//! Settings.mc.
module Palette {
    const BACKGROUND = 0xFFFFFF;
    const LABEL = 0x555555;
    const TRACK = 0xAAAAAA;
    const DATE_TEXT = 0xFFFFFF;

    // Colour rules (§6): icons and bars use the bright shade, numbers the dark one.
    const RED = 0xFF0000;
    const RED_TEXT = 0xAA0000;
    const GREEN = 0x00AA00;
    const GREEN_TEXT = 0x005500;
    const HR_LOWEST = 0x0055FF;
}
