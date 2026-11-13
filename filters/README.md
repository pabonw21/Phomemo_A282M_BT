# Printer Raster Filters

The CUPS driver relies on raster filters (`rastertoM08F`, `rastertoD480`, `rastertolabelmxxx`) to translate CUPS raster data into binary thermal printer commands for the Phomemo / QY printer family.

### Location on System
When installed, the filters reside in:
`/usr/lib/cups/filter/` (or `/usr/libexec/cups/filter/`).

### How `install.sh` handles it
1. If the required filter is already installed in `/usr/lib/cups/filter/`, the installer can reuse it.
2. During setup (`sudo ./install.sh`), the installer automatically downloads the official driver archive (`QY_Printer_Driver_Linux.zip`) from the vendor, detects your CPU architecture (`x86_64`, `aarch64` / ARM64, `armhf`, `arm`, `i386`), and extracts the matching binary filter.
3. For offline installations, you can place a pre-downloaded `QY_Printer_Driver_Linux.zip` in the repository root or place manual binaries under `filters/<arch>/rastertoM08F`.
