# PPD Printer Descriptions

During setup (`sudo ./install.sh`), official PPD printer descriptions for over 70+ Phomemo / QY models are automatically downloaded and extracted from the manufacturer's package.

### Custom or Modified PPDs
If you have custom or modified PPD files, you can place them here (`ppd/*.ppd`). The installer will copy any files in this directory to `/usr/share/cups/model/qy/` alongside the official models.
