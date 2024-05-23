copyOrDownload () {
    echo Copying $1 to $2, mode $3...
    if [ -f $1 ]; then
        cp $1 $2
    elif [ -f remote-gateway/$1 ]; then
        cp remote-gateway/$1 $2
    else
        wget https://github.com/dhicks6345789/remote-gateway/raw/master/$1 -O $2
    fi
    chmod $3 $2
}

pagetitle="Guacamole"
# Read user-defined command-line flags.
while test $# -gt 0; do
    case "$1" in
        -servername)
            shift
            servername=$1
            shift
            ;;
        -pagetitle)
            shift
            pagetitle=$1
            shift
            ;;
        *)
            echo "$1 is not a recognized flag!"
            exit 1;
            ;;
    esac
done

# Check all required flags are set, print a usage message if not.
if [ -z "$servername" ]; then
    echo "Usage: install.sh -servername SERVERNAME [-pagetitle PAGETITLE]"
    echo "SERVERNAME: The full domain name of the Guacamole server (e.g. guacamole.example.com)"
    echo "Optional: PAGETITLE: A title for the HTML page (tab title) displayed."
    exit 1;
fi

# 14th June 2023: Debian 12 (Bookworm): The packaged version of Tomcat is v10, which Guacamole doesn't yet support.
# Therefore, we'll install Tomcat v9 (from distributed binaries) instead. We modify 1-setup.sh and 2-install-guacamole.sh to explicitly set the Tomcat version.
# First, install Java...
if [ ! -f "/usr/bin/java" ]; then
    apt install -y default-jre
fi
# ...then download and set up Tomcat v9. Following: https://www.tecmint.com/install-apache-tomcat-on-debian-10/
if [ ! -d "/opt/tomcat" ]; then
    mkdir /opt/tomcat
    groupadd tomcat
    useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat
    
    # Install Tomcat 9.
    wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.82/bin/apache-tomcat-9.0.82.tar.gz
    tar xzf apache-tomcat-9.0.82.tar.gz -C /opt/tomcat --strip-components=1
    rm apache-tomcat-9.0.82.tar.gz
    
    chgrp -R tomcat /opt/tomcat
    chmod -R g+r /opt/tomcat/conf
    chmod g+x /opt/tomcat/conf
    chown -R tomcat /opt/tomcat/webapps/ /opt/tomcat/work/ /opt/tomcat/temp/ /opt/tomcat/logs/

    # Set up systemd to run Tomcat 9.
    copyOrDownload tomcat.service /etc/systemd/system/tomcat.service 0644
    systemctl daemon-reload
    systemctl start tomcat
    systemctl enable tomcat
fi

# Use Itiligent's script to install a Guacamole server - see: https://github.com/itiligent/Guacamole-Setup
if [ ! -d "/etc/guacamole" ]; then
    copyOrDownload 1-setup.sh 1-setup.sh 0755
    ./1-setup.sh
    rm 1-setup.sh
    # rm -rf guac-setup
fi
# For now:
if [ -f "/etc/guacamole/extensions/guacamole-auth-jdbc-mysql-1.5.1.jar" ]; then
    rm /etc/guacamole/extensions/guacamole-auth-jdbc-mysql-1.5.1.jar
fi



# Make sure the Nginx web/proxy server is installed (used to proxy the Tomcat (Guacamole) and uWSGI servers into one namespace).
if [ ! -d "/etc/nginx" ]; then
    apt install -y nginx
fi

# Make sure uWSGI (WSGI component for Nginx) is installed...
if [ ! -f "/usr/bin/uwsgi" ]; then
    apt install -y uwsgi-core
    apt install -y uwsgi-plugin-python3
fi

# Make sure the net-tools package is installed (we use the arp command).
if [ ! -f "/usr/sbin/arp" ]; then
    apt install -y net-tools
fi

# Figure out what version of Python3 we have installed.
pythonVersion=`python3 -c 'import sys; print(str(sys.version_info[0]) + "." + str(sys.version_info[1]))'`
echo "Python version: $pythonVersion"

# Make sure Pip (Python package manager) is installed.
if [ ! -f "/usr/bin/pip3" ]; then
    apt install -y python3-pip
fi

# Make sure the python3-venv package is installed.
if [ ! -f "/usr/share/doc/python$pythonVersion-venv" ]; then
    bash -c "apt install -y python$pythonVersion-venv"
fi

# Make sure the Python venv is set up and activated.
if [ ! -f "/var/lib/nginx/uwsgi/venv" ]; then
    python3 -m venv /var/lib/nginx/uwsgi/venv
fi
source /var/lib/nginx/uwsgi/venv/bin/activate



# Make sure Flask (Python web-publishing framework, used for the Python CGI script) is installed.
if [ ! -d "/var/lib/nginx/uwsgi/venv/lib/python$pythonVersion/site-packages/flask" ]; then
    pip3 install flask
fi



# Make sure the remote-gateway folder and files exist.
if [ ! -d "/etc/remote-gateway" ]; then
    mkdir /etc/remote-gateway
fi

if [ ! -f "/etc/remote-gateway/newUser.xml" ]; then
    copyOrDownload newUser.xml /etc/remote-gateway/newUser.xml 0755
fi

if [ ! -f "/etc/remote-gateway/newUser.py" ]; then
    copyOrDownload newUser.py /etc/remote-gateway/newUser.py 0755
fi

# Make sure a folder with the correct permissions exists for remote-gateway to write log files.
if [ ! -d "/var/log/remote-gateway" ]; then
    mkdir /var/log/remote-gateway
    chown www-data:www-data /var/log/remote-gateway
fi

if [ ! -d "/var/www/.ssh" ]; then
    mkdir /var/www/.ssh
    chown www-data:www-data /var/www/.ssh
    chmod 700 /var/www/.ssh
    # sudo -u www-data ssh-keygen -t rsa
fi



echo "Stopping Guacamole..."
systemctl stop guacd

echo "Stopping Tomcat..."
systemctl stop tomcat

echo "Stopping uWSGI..."
systemctl stop emperor.uwsgi.service

echo "Stopping Nginx..."
systemctl stop nginx

# Make sure the Guacamole configuration file exists - download our file if there's no file there already.
if [ ! -f /etc/guacamole/guacd.conf ]; then
    copyOrDownload guacd.conf /etc/guacamole/guacd.conf 0755
fi

# Make sure the Guacamole user-mapping file exists - download our example file if there's no file there already.
if [ ! -f /etc/guacamole/user-mapping.xml ]; then
    copyOrDownload user-mapping.xml /etc/guacamole/user-mapping.xml 0755
fi
chown www-data:www-data /etc/guacamole/user-mapping.xml

# Make sure the Remote Gateway RaspberryPis file exists - create a new blank file if not already.
if [ ! -f /etc/remote-gateway/raspberryPis.csv ]; then
    echo "" > /etc/remote-gateway/raspberryPis.csv
fi
chown www-data:www-data /etc/remote-gateway/raspberryPis.csv

if [ -f /etc/remote-gateway/id_rsa ]; then
    chown www-data:www-data /etc/remote-gateway/id_rsa
fi



# Copy over the WSGI configuration and code.
copyOrDownload emperor.uwsgi.service /etc/systemd/system/emperor.uwsgi.service 0755
systemctl daemon-reload
copyOrDownload api.py /var/lib/nginx/uwsgi/api.py 0755
sed -i "s/Guacamole/$pagetitle/g" /var/lib/nginx/uwsgi/api.py
copyOrDownload client.html /var/www/html/client.html 0755
copyOrDownload error.html /var/www/html/error.html 0755
copyOrDownload registerPi.sh /var/www/html/registerPi.sh 0755

if [ ! -d /var/www/html/favicon ]; then
    mkdir /var/www/html/favicon
    copyOrDownload favicon/android-chrome-192x192.png /var/www/html/favicon/android-chrome-192x192.png 0755
    copyOrDownload favicon/android-chrome-512x512.png /var/www/html/favicon/android-chrome-512x512.png 0755
    copyOrDownload favicon/apple-touch-icon.png /var/www/html/favicon/apple-touch-icon.png 0755
    copyOrDownload favicon/browserconfig.xml /var/www/html/favicon/browserconfig.xml 0755
    copyOrDownload favicon/favicon-16x16.png /var/www/html/favicon/favicon-16x16.png 0755
    copyOrDownload favicon/favicon-32x32.png /var/www/html/favicon/favicon-32x32.png 0755
    copyOrDownload favicon/favicon.ico /var/www/html/favicon/favicon.ico 0755
    copyOrDownload favicon/mstile-144x144.png /var/www/html/favicon/mstile-144x144.png 0755
    copyOrDownload favicon/mstile-150x150.png /var/www/html/favicon/mstile-150x150.png 0755
    copyOrDownload favicon/mstile-310x150.png /var/www/html/favicon/mstile-310x150.png 0755
    copyOrDownload favicon/mstile-310x310.png /var/www/html/favicon/mstile-310x310.png 0755
    copyOrDownload favicon/mstile-70x70.png /var/www/html/favicon/mstile-70x70.png 0755
    copyOrDownload favicon/safari-pinned-tab.svg /var/www/html/favicon/safari-pinned-tab.svg 0755
    copyOrDownload favicon/site.webmanifest /var/www/html/favicon/site.webmanifest 0755
fi

# Enable the uWSGI server service.
systemctl enable emperor.uwsgi.service

# Copy over the Nginx config files.
copyOrDownload nginx.conf /etc/nginx/nginx.conf 0644
copyOrDownload default /etc/nginx/sites-available/default 0644
sed -i "s/SERVERNAME/$servername/g" /etc/nginx/sites-available/default
rm /etc/nginx/sites-enabled/*
ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default



echo "Starting Nginx..."
systemctl start nginx

echo "Starting uWSGI..."
systemctl start emperor.uwsgi.service

echo "Starting Tomcat..."
systemctl start tomcat

echo "Starting Guacamole server..."
systemctl start guacd
