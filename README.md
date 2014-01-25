WebOS Ports PDF View
====================

A PDF Viewer App for WebOS.

### Building for WebOS

- Clone the git repository
- cd org.webosports.app.pdf
- tools\deploy-webos.bat
- palm-install bin\*.ipk


### Installing on Ports Emulator

tools\ports-install.bat bin\*.ipk
ssh localhost:5522
source /usr/palm/services/org.webosports.app.pdf.service/install_service.sh


### Updating PDF Lib

This App uses Mozilla [pdf.js](https://github.com/mozilla/pdf.js) library to render the PDF document. You can update it to the latest version using following steps (testted with pdf.js version 0.8.894)

    $ git clone git://github.com/mozilla/pdf.js.git pdfjs
    $ cd pdfjs
    $ node make generic
    $ cp build/generic/build/pdf.js FULL_PATH/org.webosports.app.pdf/lib/pdf.js/
    $ cp build/generic/build/pdf.worker.js FULL_PATH/org.webosports.app.pdf/lib/pdf.js/
    $ cp build/generic/web/compatibility.js FULL_PATH/org.webosports.app.pdf/lib/pdf.js/

### Notes

- Legacy WebOS does not support loading custom fonts. So it will fallback to default font. This means if your PDF uses some special font that does not translate well into the default font you will get garbage.
 	
### TODO

- Make the Busy Spinner hide after loading page on Ports Emulator
- Look at https://github.com/jviereck/node-pdfreader to see if we can move the rendering part to a Node.js service

