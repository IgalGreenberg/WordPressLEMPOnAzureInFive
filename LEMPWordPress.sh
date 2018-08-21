#!/bin/bash
location=<Azure Location> # Azure region westeurope for instance
rootname=<Root name> # the name of this project; best kept short (5 characters or less).
subscriptionname=<Azure Subscription Name>
# The level of security of this project relies heavily on the strength of these variables
# best to use a strong password generator and a password management tool
# consider using characters and numberic values to avoid needing to escape special characters
wordpressmysqlrootpassword=<WordPress MySQL root password>
wordpressmysqldbname=<WordPress MySQL database name>
wordpressmysqldbusername=<WordPress MySQL database username>
wordpressmysqldbpassword=<WordPress MySQL database user password>
dns_name=$rootname
resource_group_name=$rootname"rg"
vm_name=$rootname"vm"
publicipname=$rootname"publicip"
fqdn_name=$dns_name"."$location".cloudapp.azure.com"
subscriptionid=$(az account list --output json --query "[?name=='$subscriptionname']|[0].id" | tr -d '"')
az account set --subscription $subscriptionid
az group create \
    --name $resource_group_name \
    --location $location \
    --subscription $subscriptionid
[ -f ./cloud-init-web-server.yml ] && rm ./cloud-init-web-server.yml
cat >> ./cloud-init-web-server.yml <<EOF
#cloud-config
package_upgrade: true
packages:
 - nginx
 - mariadb-server  
 - mariadb-client
 - expect
 - software-properties-common
 - python-software-properties
 - php-fpm
 - php-common
 - php-mbstring
 - php-xmlrpc
 - php-soap
 - php-gd
 - php-xml
 - php-intl
 - php-mysql
 - php-cli
 - php-mcrypt
 - php-zip
 - php-curl
write_files:
  - path: /etc/nginx/sites-available/wordpress
    content: |
      server {
          listen 80;
          listen [::]:80;
          root /var/www/html/wordpress;
          index  index.php index.html index.htm;
          server_name  $fqdn_name;
      
          client_max_body_size 100M;

          location / {
              try_files \$uri \$uri/ /index.php?\$args;
          }
      
          location ~ \.php$ {
               include snippets/fastcgi-php.conf;
               fastcgi_pass unix:/var/run/php/php7.0-fpm.sock;
               fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
               include fastcgi_params;
          }
      }
  - owner: azureuser:azureuser
  - path: /tmp/SECURE_MYSQL
    content: |
      #!/bin/bash
      expect -c "
      set timeout 10
      spawn sudo mysql_secure_installation
      expect \"Enter current password for root (enter for none):\"
      send \"\r\"
      expect \"Set root password?\"
      send \"Y\r\"
      expect \"New password:\"
      send \"$wordpressmysqlrootpassword\r\"
      expect \"Re-enter new password:\"
      send \"$wordpressmysqlrootpassword\r\"
      expect \"Remove anonymous users?\"
      send \"Y\r\"
      expect \"Disallow root login remotely?\"
      send \"Y\r\"
      expect \"Remove test database and access to it?\"
      send \"Y\r\"
      expect \"Reload privilege tables now?\"
      send \"Y\r\"
      expect eof
      "
  - owner: azureuser:azureuser
  - path: /tmp/MYSQL_SCRIPT 
    content: |
      CREATE DATABASE $wordpressmysqldbname DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
      GRANT ALL ON $wordpressmysqldbname.* TO '$wordpressmysqldbusername'@'localhost' IDENTIFIED BY '$wordpressmysqldbpassword';
      FLUSH PRIVILEGES;
  - owner: azureuser:azureuser
  - path: /tmp/certbotinstall
    content: |
      #!/bin/bash
      sudo apt-get install software-properties-common python-software-properties -y
      echo "\r" | sudo add-apt-repository ppa:certbot/certbot
      sudo apt-get update -y
      sudo apt-get install python-certbot-nginx -y
runcmd:
  - systemctl stop nginx.service
  - systemctl start nginx.service
  - systemctl enable nginx.service
  - systemctl stop mysql.service
  - systemctl start mysql.service
  - systemctl enable mysql.service
  - /bin/bash /tmp/SECURE_MYSQL
  - systemctl restart mysql.service
  - mysql -u root -p$wordpressmysqlrootpassword < /tmp/MYSQL_SCRIPT
  - sed -i 's/^memory_limit = 128M/memory_limit = 256M/' /etc/php/7.2/fpm/php.ini
  - sed -i 's/^upload_max_filesize = 2M/upload_max_filesize = 100M/' /etc/php/7.2/fpm/php.ini
  - sed -i 's/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/7.2/fpm/php.ini
  - sed -i 's/^max_execution_time = 30/max_execution_time = 360/' /etc/php/7.2/fpm/php.ini
  - sed -i "s/^;date.timezone =$/date.timezone = \"Europe\/London\"/" /etc/php/7.2/fpm/php.ini
  - systemctl restart nginx.service
  - systemctl restart php7.0-fpm.service
  - wget https://wordpress.org/latest.tar.gz -O /tmp/latest.tar.gz
  - tar -zxvf /tmp/latest.tar.gz -C /var/www/html
  - chown -R www-data:www-data /var/www/html/wordpress/
  - chmod -R 755 /var/www/html/wordpress/
  - ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
  - mv /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
  - sed -i "s/database_name_here/$wordpressmysqldbname/" /var/www/html/wordpress/wp-config.php
  - sed -i "s/username_here/$wordpressmysqldbusername/" /var/www/html/wordpress/wp-config.php
  - sed -i "s/password_here/$wordpressmysqldbpassword/" /var/www/html/wordpress/wp-config.php
  - systemctl restart nginx.service
  - systemctl restart php7.0-fpm.service
  - /bin/bash /tmp/certbotinstall
final_message: "The system is finally up, after $UPTIME seconds"
EOF

az vm create \
    --verbose \
    --resource-group $resource_group_name \
    --name $vm_name \
    --image UbuntuLTS \
    --size Standard_D2_v2 \
    --admin-username azureuser \
    --ssh-key-value ~/.ssh/id_rsa.pub \
    --custom-data ./cloud-init-web-server.yml  \
    --public-ip-address $publicipname \
    --public-ip-address-allocation static \
    --public-ip-address-dns-name $dns_name \
    --subscription $subscriptionid

az vm open-port \
    --resource-group $resource_group_name \
    --name $vm_name \
    --port 80

az vm open-port \
    --resource-group $resource_group_name \
    --name $vm_name \
    --port 443 \
    --priority 1100
