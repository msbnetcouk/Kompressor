# Kompressor
Supercharging your network/firewall changes.

Kompressor is a Powershell 5.1 GUI for Batfish, alpha release.

Kompressor will accept a 'CURRENT' and a 'CANDIDATE' configuration file. 
Once initialised, it's possible to test potential flows against either configuration. 

Kompressor submits the configuration files and flow questions as HTTP POST requests to the Batfish server of your choice.
Batfish is vendor agnostic but this release candidate was conceived specifically to address project work with Juniper SRX (Junos) firewalls.

Example configuration files included.

Batfish not included.





Prerequisites?

1. 7zip - Batfish expects to receive a zip file with a specific directory tree. Powershell's Compress-Archive in 5.1 appears to mangle it.
https://www.7-zip.org/download.html

2. Curl - Hopefully a temporary requirement. Batfish kept rejecting native attempts to upload the configuration files.
All other requests use Powershell's Invoke-RestMethod.
https://curl.haxx.se/download.html

3. A Batfish server/container - This is where all the magic happens! Batfish uses TCP/9996 and TCP/9997 by default.
https://github.com/batfish/batfish
