#!/bin/bash
yum -y install epel-release
yum -y update
yum -y install git open-vm-tools nfs-utils

# create user for docker file access
groupadd -g 1001 nfs_svc
useradd -u 666 -g 1001 nfs_svc

# add nfs mount my dockerfiles
echo "10.8.10.100:/mnt/media/dockerfiles      /mnt/nfs/dockerfiles    nfs     auto,bg,nolock,noatime,actimeo=1800     0 0" >> /etc/fstab
# mount the new nfs link
mount -a

firewall-cmd --permanent --add-port=8080/tcp --zone=public
firewall-cmd --permanent --add-service=http/tcp --zone=public
firewall-cmf --reload
