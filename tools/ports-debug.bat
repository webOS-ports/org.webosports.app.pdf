@REM org.webosports.app.pdf.app
SET package=%1
ssh -p 5522 -L 11222:localhost:11222 root@localhost  'QTWEBKIT_INSPECTOR_SERVER=10.0.2.15:1122; webapp-launcher -a /usr/palm/applications/%package%/appinfo.json --debug'