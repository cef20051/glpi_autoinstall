#!/bin/bash

echo "🔧 Atualizando pacotes..."
apt update && apt upgrade -y

echo "📦 Instalando Apache, MariaDB, PHP e extensões exigidas pelo GLPI..."
apt install apache2 mariadb-server php libapache2-mod-php -y
apt install php-{cli,common,mbstring,xml,curl,gd,intl,bz2,zip,imap,mysql,ldap,apcu,opcache,readline} unzip wget -y

echo "🔐 Configurando MariaDB..."
mysql -u root <<EOF
CREATE DATABASE glpidb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'glpiuser'@'localhost' IDENTIFIED BY 'GLPIsenha123!';
GRANT ALL PRIVILEGES ON glpidb.* TO 'glpiuser'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "🌐 Baixando GLPI..."
cd /tmp
wget https://github.com/glpi-project/glpi/releases/download/10.0.14/glpi-10.0.14.tgz
tar -xvzf glpi-10.0.14.tgz
rm glpi-10.0.14.tgz

echo "📁 Criando diretórios seguros para arquivos sensíveis..."
mkdir -p /var/lib/glpi/files /var/lib/glpi/marketplace /var/lib/glpi/config
cp -r glpi/* /var/www/html/glpi
mv /var/www/html/glpi/files/* /var/lib/glpi/files/
mv /var/www/html/glpi/marketplace/* /var/lib/glpi/marketplace/
mv /var/www/html/glpi/config/* /var/lib/glpi/config/

echo "🔗 Criando links simbólicos para os diretórios seguros..."
rm -rf /var/www/html/glpi/files /var/www/html/glpi/marketplace /var/www/html/glpi/config
ln -s /var/lib/glpi/files /var/www/html/glpi/files
ln -s /var/lib/glpi/marketplace /var/www/html/glpi/marketplace
ln -s /var/lib/glpi/config /var/www/html/glpi/config

echo "🛠️ Ajustando permissões..."
chown -R www-data:www-data /var/www/html/glpi
chown -R www-data:www-data /var/lib/glpi
chmod -R 755 /var/www/html/glpi
chmod -R 750 /var/lib/glpi

echo "🌍 Configurando Apache para GLPI..."
cat <<APACHECONF > /etc/apache2/sites-available/glpi.conf
<VirtualHost *:80>
    ServerAdmin admin@localhost
    DocumentRoot /var/www/html/glpi
    ServerName glpi.local

    <Directory /var/www/html/glpi>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <Directory /var/lib/glpi>
        Require all denied
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/glpi_error.log
    CustomLog \${APACHE_LOG_DIR}/glpi_access.log combined
</VirtualHost>
APACHECONF

echo "🧩 Ativando site e módulos..."
a2ensite glpi.conf
a2enmod rewrite
systemctl reload apache2

echo "🔁 Reiniciando Apache..."
systemctl restart apache2

echo "🔧 Adicionando glpi.local ao /etc/hosts..."
grep -qxF "127.0.0.1 glpi.local" /etc/hosts || echo "127.0.0.1 glpi.local" >> /etc/hosts

echo "⚙️ Ativando session.cookie_httponly no PHP..."
PHPINI=$(php -r "echo php_ini_loaded_file();")
if ! grep -q "^session.cookie_httponly" "$PHPINI"; then
    echo "session.cookie_httponly = On" >> "$PHPINI"
else
    sed -i 's/^session.cookie_httponly.*/session.cookie_httponly = On/' "$PHPINI"
fi
systemctl restart apache2

echo "🧹 Limpando arquivo de instalação..."
rm -rf /var/www/html/glpi/install/install.php

echo ""
echo "✅ GLPI instalado com segurança e pronto para uso!"
echo "🌐 Acesse: http://glpi.local ou http://localhost/glpi"
echo "🔑 Login padrão: glpi / glpi"
