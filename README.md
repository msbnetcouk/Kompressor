# Kompressor
Supercharging your network/firewall changes.

Kompressor is a Powershell 5.1 GUI for Batfish.

It will accept a 'CURRENT' and a 'CANDIDATE' configuration file. 
Once initialised, it's possible to test potential flows against either configuration. 

Kompressor submits the configuration files and flow questions as HTTP POST requests to the Batfish server of your choice.
Batfish is vendor agnostic but this release candidate was conceived specifically to address project work with Juniper SRX firewalls.

Example configuration files included.

Batfish not included.
