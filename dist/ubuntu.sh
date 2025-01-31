#!/bin/bash

if [ "$(id -u)" != "0" ]; then
    echo "Script harus dijalankan dengan sudo"
    exit 1
fi

get_input() {
    local prompt="$1"
    local default="$2"
    local input
    
    exec < /dev/tty
    read -p "$prompt" input
    
    if [ -z "$input" ] && [ ! -z "$default" ]; then
        echo "$default"
    else
        echo "$input"
    fi
}

user_ip=$(get_input "Masukkan IP address (contoh: 192.168.1.1): ")
user_domain=$(get_input "Masukkan nama domain (contoh: smkeki.sch.id): ")

mysql_root_password=$(get_input "Masukkan password untuk root MySQL: ")
phpmyadmin_password=$(get_input "Masukkan password untuk phpMyAdmin: ")

# Validasi input
if [ -z "$user_ip" ] || [ -z "$user_domain" ] || [ -z "$mysql_root_password" ] || [ -z "$phpmyadmin_password" ]; then
    echo "IP address, domain, MySQL password, dan phpMyAdmin password tidak boleh kosong. Jalankan ulang script."
    exit 1
fi

add-apt-repository universe -y

export DEBIAN_FRONTEND=noninteractive

echo "mysql-server mysql-server/root_password password $mysql_root_password" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $mysql_root_password" | debconf-set-selections
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-pass password $mysql_root_password" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/app-pass password $phpmyadmin_password" | debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections

apt-get clean
apt-get update -y

apt-get install -y \
    bind9 \
    apache2 \
    mysql-server \
    apache2-utils \
    phpmyadmin \
    samba \
    || { echo "Instalasi paket gagal. Periksa koneksi internet dan repository."; exit 1; }

systemctl disable apt-daily.timer
systemctl disable apt-daily-upgrade.timer

mkdir -p /etc/bind
cat > /etc/resolv.conf <<EOL
nameserver $user_ip
nameserver 8.8.8.8
search $user_domain
options edns0 trust-ad
EOL

reversed_ip=$(echo "$user_ip" | awk -F. '{print $3"."$2"."$1}')

cat > /etc/bind/named.conf.default-zones <<EOL
# Default zones
zone "localhost" {
    type master;
    file "/etc/bind/db.local";
};

zone "127.in-addr.arpa" {
    type master;
    file "/etc/bind/db.127";
};

zone "0.in-addr.arpa" {
    type master;
    file "/etc/bind/db.0";
};

zone "255.in-addr.arpa" {
    type master;
    file "/etc/bind/db.255";
};

# Custom SMK zones
zone "$user_domain" {
     type master;
     file "/etc/bind/smk.db";
 };

zone "$reversed_ip.in-addr.arpa" {
     type master;
     file "/etc/bind/smk.ip";
 };
EOL

cat > /etc/bind/smk.db <<EOL
\$TTL    604800
@       IN      SOA     ns.$user_domain. root.$user_domain. (
                        2         ; Serial
                        604800    ; Refresh
                        86400     ; Retry
                        2419200   ; Expire
                        604800 )  ; Negative Cache TTL
;
@       IN      NS      ns.$user_domain.
@       IN      MX 10   $user_domain.
@       IN      A       $user_ip
ns      IN      A       $user_ip
www     IN      CNAME   ns
mail    IN      CNAME   ns
ftp     IN      CNAME   ns
ntp     IN      CNAME   ns
proxy   IN      CNAME   ns
EOL

octet=$(echo "$user_ip" | awk -F. '{print $4}')
cat > /etc/bind/smk.ip <<EOL
@       IN      SOA     ns.$user_domain. root.$user_domain. (
                        2         ; Serial
                        604800    ; Refresh
                        86400     ; Retry
                        2419200   ; Expire
                        604800 )  ; Negative Cache TTL
;
@       IN      NS      ns.$user_domain.
$octet  IN      PTR     ns.$user_domain.
EOL

mkdir -p /etc/apache2/sites-available
mkdir -p /var/www

cat > /etc/apache2/sites-available/000-default.conf <<EOL
<VirtualHost $user_ip:80>
        ServerAdmin admin@$user_domain
        ServerName www.$user_domain
        DocumentRoot /var/www
        ErrorLog \${APACHE_LOG_DIR}/error.log
        LogLevel warn
        CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOL

cat > /var/www/index.php <<EOL
<!DOCTYPE html>
<html>
<body>
    <h1>Selamat Datang di Server $user_domain</h1>
    <?php phpinfo(); ?>
</body>
</html>
EOL

chmod 777 /var/www/ -R

echo "Tambah user Samba (username: tamu)"
useradd tamu
echo "Masukkan password untuk user tamu:"
passwd tamu

cp /etc/samba/smb.conf /etc/samba/smb.conf.backup

cat >> /etc/samba/smb.conf <<EOL

[www]
path = /var/www/
browseable = yes
writeable = yes
valid users = tamu
admin users = root
EOL

smbpasswd -a tamu

echo "Menambahkan konfigurasi phpMyAdmin ke apache2.conf..."
echo "Include /etc/phpmyadmin/apache.conf" >> /etc/apache2/apache2.conf

a2ensite 000-default.conf
a2enmod rewrite
a2enmod ssl

systemctl restart bind9 || true
systemctl restart apache2 || true
systemctl restart smbd || true

echo "==== Konfigurasi Selesai ===="
echo "Domain: $user_domain"