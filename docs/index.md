# WP On Azure In Five
Get an Azure VM up and running with WordPress on LEMP in five minutes. The VM would use Ubuntu 16, Apache 2, MariaDB, PHP 7.0 and latest wordpress.
I have used several websites to create this entry.  The biggest thanks goes to:
1. https://docs.microsoft.com/en-us/azure/virtual-machines/linux/tutorial-lemp-stack
2. https://websiteforstudents.com/setup-wordpress-on-ubuntu-16-04-17-10-18-04-with-nginx-mariadb-php-7-2-and-lets-encrypt-ssl-tls-certificates/
There are so many more to thank.  

Install prerequisites:
1. This install uses bash.  If using windows use Bash on Windows: https://docs.microsoft.com/en-us/windows/wsl/install-win10.
2. Azure cli: Install the Azure cli api: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
3. Generate SSH keys on your bash prorile.

To install wordpress on lamp on Azure in less than five minutes fire up bash:
```bash
az login
git clone https://github.com/IgalGreenberg/WordPressLEMPOnAzureInFive.git
cd WordpressLEMPonAzureInFive/
```
Edit LEMPWordPress.sh and enter strong values for:
 - location
 - rootname
 - subscriptionname
 - wordpressmysqlrootpassword
 - wordpressmysqldbname
 - wordpressmysqldbusername
 - wordpressmysqldbpassword

Run the Azure Cloud installer:
```bash
sh LEMPWordPress.sh
```

You now have a LEMP server with Wordpress on Azure!
You can check the install by reviewing /var/log/cloud-init-output.log

If you need an SSL certificate for your new server:
```bash
publicip=$(az vm list-ip-addresses -n $vm_name --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress -o tsv)
# one can check the install by examining /var/log/cloud-init-output.log
echo "sudo certbot --apache -m \"admin@$fqdn_name\" -d \"$fqdn_name\""
ssh azureuser@$fqdn_name
# run the echo command on the remote server
# next you can configure a monthly scheduled SSL certificate update:
crontab -e
0 0 1 * * /usr/bin/letsencrypt renew >> /var/log/letsencrypt-renew.log
sudo service cron restart
```

Hopefully this script provided you with a VM on Azure in five minutes.  Do let me know if this works for you.
In case you are using a custom DNS name this would be a good time to setup your DNS using your public IP (or a DNS Zone in Azure).  Once doing that do update the FQDN entry in /etc/apache2/sites-available/wordpress.conf.  Update the fqdn_name variable and run certbot again as above.
