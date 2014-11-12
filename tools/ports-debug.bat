@REM org.webosports.app.pdf
SET package=%1
SET deviceIP=192.168.1.66
SET devicePort=22

ssh -p %devicePort% -L 11222:%deviceIP%:1122 root@%deviceIP%  'QTWEBKIT_INSPECTOR_SERVER=127.0.0.1:1122; /usr/sbin/webapp-launcher --debug -a /usr/palm/applications/%package%/appinfo.json -p {}'