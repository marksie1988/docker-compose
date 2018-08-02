#!/bin/bash
yum -y install epel-release
yum -y update
yum -y install open-vm-tools nfs-utils mariadb-server mariadb httpd php php-mysql php-xml php-intl php-gd php-xcache nodejs npm vim-enhanced git policycoreutils-python

# create NFS Directories
if [ ! -d "/mnt/nfs/wiki" ]; then
  mkdir -p /mnt/nfs/wiki/dbs
  mkdir -p /mnt/nfs/wiki/data
fi

# add nfs mount
if grep -Fxq "10.8.10.100:/mnt/media/wiki/" /etc/fstab
then
echo "10.8.10.100:/mnt/media/wiki/      /mnt/nfs/wiki    nfs     auto,bg,nolock,noatime,actimeo=1800     0 0" >> /etc/fstab
fi

# mount the new nfs link
mount -a



ln -s /mnt/nfs/wiki/dbs  /var/lib/mysql
ln -s /mnt/nfs/wiki/data  /var/www/html

# enable and start services
sudo systemctl enable httpd.service
sudo systemctl enable mariadb
sudo systemctl start httpd.service
sudo systemctl start mariadb

# allow http through firewall
firewall-cmd --permanent --add-service=http --zone=public
firewall-cmd --permanent --zone=public --add-port=8000/tcp
firewall-cmd --reload

# setup mediawiki

curl -O https://releases.wikimedia.org/mediawiki/1.31/mediawiki-1.31.0.tar.gz
tar xvzf mediawiki-*.tar.gz
sudo mv mediawiki-1.24.1/* /var/www/html

# check mariadb is started

if ps ax | grep -v grep | grep mariadb > /dev/null
then
  # mysql secure install
  mysql -sfu root < "mysql_secure_installation.sql"
  # create database
  mysql -sfu root < "mwiki_mysql.sql"
else
    sudo systemctl start mariadb
    mysql -sfu root < "mysql_secure_installation.sql"
    mysql -sfu root < "mwiki_mysql.sql"
fi


# install Parsoid
cd ~
git clone https://gerrit.wikimedia.org/r/p/mediawiki/services/parsoid
cp -r ~/parsoid /opt/
cd /opt/parsoid/
npm install

cat <<EOT >> /opt/parsoid/api/localsettings.js
'use strict';
exports.setup = function(parsoidConfig) {

        parsoidConfig.setMwApi('yourwiki', { uri: 'http://localhost/api.php' });

};
EOT

chown -Rv root:root /opt/parsoid
chmod -Rv u+rw,g+r,o+r /opt/parsoid

semanage port -m -t http_port_t -p tcp 8000
setsebool httpd_can_network_connect 0

cat <<EOT >> /etc/systemd/system/parsoid.service
[Unit]
Description=Mediawiki Parsoid web service on node.js
Documentation=http://www.mediawiki.org/wiki/Parsoid
Wants=local-fs.target network.target
After=local-fs.target network.target

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/opt/parsoid
# EnvironmentFile=-/etc/parsoid/parsoid.env
ExecStart=/usr/bin/node /opt/parsoid/api/server.js
KillMode=process
Restart=on-success
PrivateTmp=true
StandardOutput=syslog
EOT

systemctl start parsoid.service
systemctl enable parsoid.service



git clone https://gerrit.wikimedia.org/r/p/mediawiki/extensions/VisualEditor.git
git clone https://gerrit.wikimedia.org/r/p/mediawiki/extensions/UniversalLanguageSelector.git
cp -r VisualEditor /var/www/html/extensions/
cp -r UniversalLanguageSelector /var/www/html/extensions/

cat <<EOT >> /var/www/html/LocalSettings.php
# UniversalLanguageSelector
require_once "$IP/extensions/UniversalLanguageSelector/UniversalLanguageSelector.php";

#VisualEditor
require_once "$IP/extensions/VisualEditor/VisualEditor.php";

// Enable by default for everybody
$wgDefaultUserOptions['visualeditor-enable'] = 1;

// Don't allow users to disable it
#$wgHiddenPrefs[] = 'visualeditor-enable';

// OPTIONAL: Enable VisualEditor's experimental code features
#$wgDefaultUserOptions['visualeditor-enable-experimental'] = 1;

// URL to the Parsoid instance
// MUST NOT end in a slash due to Parsoid bug
// Use port 8142 if you use the Debian package
$wgVisualEditorParsoidURL = 'http://localhost:8000';

// Interwiki prefix to pass to the Parsoid instance
// Parsoid will be called as $url/$prefix/$pagename
$wgVisualEditorParsoidPrefix = 'yourwiki';

# Namespces for VE
$wgVisualEditorNamespaces = array_merge(
        $wgContentNamespaces,
        array( * )
);

# Timeout for HTTP requests to Parsoid in seconds
$wgVisualEditorParsoidTimeout = 200;
EOT
