# moodle-server
A script to configure a Debian installation as a [Moodle](https://moodle.org/) server for e-Learning functionality.

## What Does This Project Do?
This project provides a setup script that is intended for people who want a (hopefully) simple, one-step mechanism to set up a complete Moodle server with reasonable defaults.

If you're using this project it's assumed you are probably a system administrator of some sort (maybe working for a school or other learning establishment) wanting to set up a Moodle server for your users. This project is not something you'll want to run on your desktop machine, you'll be wanting at least a basic, publicly-accessible web server, either hosted on your own hardware or by a web/cloud hosting provider of some sort. As of writing (June 2024), a suitible hosted virtual machine from a public provider is available for under $5 a month.

You will also need a [domain name](https://en.wikipedia.org/wiki/Domain_name) available (e.g. example.com), and the ability to set up a [sub-domain](https://en.wikipedia.org/wiki/Subdomain) (e.g. moodle.example.com).

This project has a couple of options for handling connectivity from the outside world to your server:
 - With a "tunneling" or "ingress" provider such as Cloudflare, Ngrok or [similar services](https://github.com/anderspitman/awesome-tunneling). In that case, external HTTPS connections to your server go through your chosen provider, who ideally also provides protections against common security issues.
 - By handling HTTPS connections to the outside world itself, in which case it uses [Caddy web server](https://caddyserver.com/) and will automatically handle obtaining an HTTPS certificate from [Let's Encrypt](https://letsencrypt.org/). If you are using this option, it is assumed you are running on a publicly-available server of some kind with a static IP address, probably hosted by a service provider. If you are running on your own server hardware behind a firewall, you will probably have to set up a port forwarding rule on your firewall for incoming HTTPS (port 443) traffic.

All the software installed by this project is free and open source. The setup script, if it works correctly, should result in your machine running instances of:
 - Apache, with PHP
 - MariaDB
 - Moodle
 - Optionally: Caddy

As of May 2024, this script has been tested on a Debian 12 (Bookworm) release. It could well work okay on Raspberry Pi OS, using a Raspberry Pi as a handy low-cost server, but I haven't tested that yet.

## Installation
On a freshly installed Debian 12 (Bookworm) server, as root, run:
```
wget https://github.com/dhicks6345789/moodle-server/raw/master/install.sh
bash install.sh -servername moodle.example.com -pagetitle "My Moodle"
```
Or, download from Github and run the install script:
```
git clone https://github.com/dhicks6345789/moodle-server.git
bash moodle-server/install.sh -servername moodle.example.com -pagetitle "My Moodle"
```
You'll need to provide one value:
- The full domain name of the server (should be your server's domain name, where the Cloudflare DNS entry / Zero Trust application is pointing, e.g. "moodle.example.com")

You can also provide an optional value:
- A page title for the HTML page used to display the remote desktop. This generally gets used by browsers as a tab title, will simply default to "Guacamole" if not defined.

The script will take a little while to run - it downloads and installs various components as it goes along, it might take half an hour or so.

## After Installation
When the above script has finished, you should (hopefully) have a Debian server running:
