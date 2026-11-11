# Printer Raster Filters

The CUPS driver relies on the `rastertoM08F` raster filter to translate CUPS raster data into binary thermal printer commands for the Phomemo / QY printer family.

### Location on System
When installed, the filter resides in:
`/usr/lib/cups/filter/rastertoM08F` (or `/usr/libexec/cups/filter/rastertoM08F`).

### How `install.sh` handles it
1. If `rastertoM08F` is already installed in `/usr/lib/cups/filter/`, the installer reuses it automatically.
2. If you have the official vendor package (`QY_Printer-*`), the installer detects and copies the matching architecture binary (`x86_64`, `aarch64`, `armhf`, `i386`).
3. If needed, you can place the precompiled binary for your architecture in `filters/<arch>/rastertoM08F`.
