# moodle-server
A script to configure a Debian installation as a [Moodle](https://moodle.org/) server for e-Learning functionality.

## What Does This Project Do?
This project provides a setup script that is intended for people who want a (hopefully) simple, one-step mechanism to set up a complete Moodle server with reasonable defaults.

If you're using this project it's assumed you are probably a system administrator of some sort (maybe working for a school or other learning establishment) wanting to set up a Moodle server for your users. This project is not something you'll want to run on your desktop machine, you'll be wanting at least a basic, publicly-accessible web server, either hosted on your own hardware or by a web/cloud hosting provider of some sort. As of writing (June 2024), a suitible hosted virtual machine from a public provider is available for under $5 a month.

You will also need a [domain name](https://en.wikipedia.org/wiki/Domain_name) available (e.g. example.com), and the ability to set up a [sub-domain](https://en.wikipedia.org/wiki/Subdomain) (e.g. moodle.example.com).

This project has a couple of options for handling connectivity from the outside world to your server:
 - With a "tunneling" or "ingress" provider such as Cloudflare, Ngrok or [similar services](https://github.com/anderspitman/awesome-tunneling). In that case, external HTTPS connections to your Moodle instance go through your chosen provider, who ideally also provides protection against common security issues.
 - By handling HTTPS connections to the outside world itself, in which case it uses [Caddy web server](https://caddyserver.com/) as a proxy server and will automatically handle obtaining an HTTPS certificate from [Let's Encrypt](https://letsencrypt.org/). If you are using this option, it is assumed you are running on a publicly-available server of some kind with a static IP address, probably hosted by a service provider. If you are running on your own server hardware behind a firewall, you will probably have to set up a port forwarding rule on your firewall for incoming HTTPS (port 443) traffic.
 - Neither of the above, in which case the Moodle server will be available via HTTP. This assumes you are going to set up your own HTTPS configuration, possibly by adding your own certificate to the Apache configuration.

## Installation
On a freshly installed Debian 12 (Bookworm) server, as root, run:
```
wget https://github.com/trainergav/moodle-server/raw/master/install.sh
bash install.sh -servername moodle.example.com -dbpassword ExamplePassword123 -servertitle "Example Moodle Server" -sslhandler tunnel
```
Or, download from Github and run the install script:
```
git clone https://github.com/trainergav/moodle-server.git
bash moodle-server/install.sh -servername moodle.example.com -dbpassword ExamplePassword123 -servertitle "Example Moodle Server" -sslhandler tunnel
```
You'll need to provide some values:
 - The full domain name of the server (should be your server's domain name, e.g. "moodle.example.com")
 - The root password to set for the MariaDB database.
 - Optionally, the title for the Moodle server (e.g. "Example.com Moodle Server").
 - Optionally, either "tunnel" or "caddy" as the SSL Handler option. The default, "none", will result in a Moodle server with local-network-only HTTP access.

The script will take a little while to run - it downloads and installs various components as it goes along, it might take 10 minutes or so.

## After Installation
When the script has finished, you should (hopefully) have a Debian server running:

 - [Apache](https://httpd.apache.org/)
 - [MariaDB](https://mariadb.org/)
 - [PHP](https://www.php.net/)
 - [Moodle](https://moodle.org/)
 - Optionally: [Caddy](https://caddyserver.com/)

This project, and all the software installed by it, is free and open source - you might want to check the links above for the details of each project's license.

As of June 2024, this script has been tested on a Debian 12 (Bookworm) release. It could well work okay on Raspberry Pi OS, using a Raspberry Pi as a handy low-cost server, but I haven't tested that yet.

You should wind up with a freshly-installed Moodle server available on (standard HTTP) port 80. You should then make sure you can (securly, i.e. via HTTPS) connect to the server using whatever method you prefer:
 - If you specified "tunnel" as your SSL Handler option, you'll need to install / configure your SSL tunnel. Typically, you'll have a service of some sort to install on the server and some configuration options to complete at the provider's end. If the provider asks you for a local port / URL for its service to point at, 'HTTP://localhost:80' is probably correct.
 - If you specified "caddy", an instance of Caddy web server should also be running, configured to act as a proxy server providing SSL functionality to the Apache server running Moodle. Caddy will take care of configuring its own SSL certificate.

With either of the above options, you should now be able to connect to the Moodle server by opening up a web browser pointing at the domain name you provided (e.g. https://moodle.example.com)

If you specified "none" as the SSL Handler option, you'll need to configure SSL yourself (probably by adding to the Apache config and making sure port 443 (SSL) is publically available, either by checking your web server provider's configuration or, if using a local server, making sure port forwarding is set up on your firewall).

When you have got a browser open and connected to the Moodle server, you should then be able to step through Moodle's inital configuration screens.
