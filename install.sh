# A script to automate the installation of a Moodle server. Basically doing the steps listed here:
# https://docs.moodle.org/404/en/Installation_quick_guide

copyOrDownload () {
    echo Copying $1 to $2, mode $3...
    if [ -f $1 ]; then
        cp $1 $2
    elif [ -f moodle-server/$1 ]; then
        cp moodle-server/$1 $2
    else
        wget https://github.com/trainergav/moodle-server/raw/master/$1 -O $2
    fi
    chmod $3 $2
}

# Set default command-line flag values.
moodlebranch="MOODLE_501_STABLE"
servertitle="Moodle Server"
sslhandler="none"
dbname="moodle"

# Read user-defined command-line flags.
while test $# -gt 0; do
    case "$1" in
        -servername)
            shift
            servername=$1
            shift
            ;;
        -servertitle)
            shift
            servertitle=$1
            shift
            ;;
         -dbname)
            shift
            dbname=$1
            shift
            ;;
        -dbpassword)
            shift
            dbpassword=$1
            shift
            ;;
        -sslhandler)
            shift
            sslhandler=$1
            shift
            ;;
        *)
            echo "$1 is not a recognized flag."
            exit 1;
            ;;
    esac
done

# Check all required flags are set, print a usage message if not.
if [ -z "$servername" ] || [ -z "$dbpassword" ]; then 
echo "Usage: install.sh -servername SERVERNAME -dbpassword DATABASEPASSWORD   -[dbname DBNAME] [-servertitle SERVERTITLE] [-sslhandler none | tunnel | caddy]"
    echo "SERVERNAME: The full domain name of the Moodle server (e.g. moodle.example.com)."
    echo "DATABASEPASSWORD: The root password to set for the MariaDB database."
    echo "Optional: DBNAME: Install an instance of Moodle into a nominated database and location (e.g. \"moodle500\". Defaults to \"moodle\"" 
    echo "Optional: SERVERTITLE: A title for the Moodle server (e.g. \"My Company Moodle Server\". Defaults to \"Moodle Server\"" 
    echo "Optional: \"tunnel\" or \"caddy\" as SSL Handler options. If \"tunnel\", Moodle will be configured assuming an SSL tunneling"
    echo "          service (Cloudflare, NGrok, etc) will be used to provide SSL ingress. If \"caddy\", Caddy webserver will be installed"
    echo "          and set up to auto-configure SSL. If \"none\" (the default), neither option will be configured for."
    exit 1;
fi

echo Installing Moodle server \""$servertitle"\"...

# Make sure the Apache web server is installed.
if [ ! -d "/etc/apache2" ]; then
    apt install -y apache2
    rm /var/www/html/index.html
fi

echo Apache installed \""$servertitle"\"...

# Make sure the MariaDB database server is installed.
if [ ! -f "/usr/bin/mariadb" ]; then
    apt install -y mariadb-server
    # After installing MariaDB, it seems to be best practice to run the "mysql_secure_installation" script to reconfigure a few default settings to be more secure.
    # Here, we automate this process using the approach outlined at: https://bertvv.github.io/notes-to-self/2015/11/16/automating-mysql_secure_installation/
    mysql --user=root -e "UPDATE mysql.user SET Password=PASSWORD('$dbpassword') WHERE User='root';"
    mysql --user=root --password=$dbpassword -e "DELETE FROM mysql.user WHERE User='';"
    mysql --user=root --password=$dbpassword -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql --user=root --password=$dbpassword -e "DROP DATABASE IF EXISTS test;"
    mysql --user=root --password=$dbpassword -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    mysql --user=root --password=$dbpassword -e "FLUSH PRIVILEGES;"
fi

echo Database created \""$servertitle"\"...

# Make sure PHP is installed.
if [ ! -d "/etc/php" ]; then
    apt install -y php libapache2-mod-php php-mysql php-xml php-mbstring php-curl php-zip php-gd php-intl php-soap
    sed -i 's/;max_input_vars = 1000/max_input_vars = 9000/g' /etc/php/8.4/apache2/php.ini
#    sed -i 's/;max_execution_time = /max_execution_time = 160/g' /etc/php/8.4/apache2/php.ini
#    sed -i 's/;max_input_vars = 1000/max_input_vars = 9000/g' /etc/php/8.4/apache2/php.ini
fi

# Get Moodle 5.0.1 via Git.
if [ ! -d "moodle" ]; then
    git clone -b $moodlebranch git://git.moodle.org/moodle.git
fi

echo Moodle downloaded \""$servertitle"\"...

# Create / set up the Moodle database.
mysql --user=root --password=$dbpassword -e "CREATE DATABASE $dbname DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql --user=root --password=$dbpassword -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,CREATE TEMPORARY TABLES,DROP,INDEX,ALTER ON  $dbname.* TO 'moodleuser'@'localhost' IDENTIFIED BY '$dbpassword';"
mysql --user=root --password=$dbpassword -e "FLUSH PRIVILEGES;"

echo Moodle user database created and user setup \""$servertitle"\"...

# Set up the Moodle data folder.
if [ ! -d "/var/www/$dbname" ]; then
    mkdir /var/www/$dbname
    chown www-data:www-data /var/www/$dbname
fi

echo Moodle DATADIR created \""$servertitle"\"...

# Copy the Moodle code to the web server

cp -r moodle/* /var/www/html
mkdir /var/www/html/private
chmod 755 /var/www/html/private
rm /var/www/html/config-dist.php
copyOrDownload config.php /var/www/html/config.php 0644
sed -i "s/{{DBPASSWORD}}/$dbpassword/g" /var/www/html/config.php
sed -i "s/{{SERVERNAME}}/$servername/g" /var/www/html/config.php
if [ $sslhandler = "tunnel" ] || [ $sslhandler = "caddy" ]; then
    sed -i "s/{{SSLPROXY}}/true/g" /var/www/html/private/config.php
else
    sed -i "s/{{SSLPROXY}}/false/g" /var/www/html/private/config.php
fi


# Make sure DOS2Unix is installed.
if [ ! -f "/usr/bin/dos2unix" ]; then
    apt install -y dos2unix
fi

# Set up Crontab if it doesn't already exist.
if [ ! -f "/var/spool/cron/crontabs/www-data" ]; then
    copyOrDownload crontab crontab 0644
    dos2unix crontab
    crontab crontab
    rm crontab
fi

# Restart Apache so any changes take effect.
service apache2 restart

# Optionally, install Caddy web server.
if [ $sslhandler = "caddy" ]; then
    if [ ! -d "/etc/caddy" ]; then
        apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
        apt update
        apt install caddy
    fi

    # To do: add Caddy config here, configure to act as HTTPS proxy for Apache.
fi
