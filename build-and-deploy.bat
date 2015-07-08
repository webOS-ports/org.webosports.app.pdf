node enyo/tools/deploy.js -v -o deploy/org.webosports.app.pdf

adb push deploy/org.webosports.app.pdf /usr/palm/applications/org.webosports.app.pdf

adb shell luna-send -n 1 luna://com.palm.applicationManager/rescan {}

adb shell systemctl restart luna-next