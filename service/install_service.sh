
#!/bin/sh                                                                                       

SID="org.webosports.app.pdf.service"


echo "Removing old Service files...."

# Remove the dbus service
rm -f /usr/share/dbus-1/system-services/${SID}.service /var/palm/system-services/${SID}.service

# Remove the ls2 roles
rm -f /usr/share/ls2/roles/prv/${SID}.json /var/palm/ls2/roles/prv/${SID}.json
rm -f /usr/share/ls2/roles/pub/${SID}.json /var/palm/ls2/roles/pub/${SID}.json

# Stop the service if running
/usr/bin/killall -9 ${SID} || true

echo "Installing Service...."

# Install the dbus service
cp /usr/palm/services/${SID}/dbus/${SID}.service.pub /usr/share/dbus-1/system-services/${SID}.service

# Install the ls2 roles
mkdir -p /var/palm/ls2/roles/prv /var/palm/ls2/roles/pub
cp /usr/palm/services/${SID}/dbus/${SID}.json.prv /usr/share/ls2/roles/prv/${SID}.json
cp /usr/palm/services/${SID}/dbus/${SID}.json.pub /usr/share/ls2/roles/pub/${SID}.json


echo "Done"