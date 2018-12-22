#!/bin/bash

# Detect OS
case $(head -n1 /etc/issue | cut -f 1 -d ' ') in
    Debian)     OS_NAME="debian" ;;
    Ubuntu)     OS_NAME="ubuntu" ;;
    Amazon)     OS_NAME="amazon" ;;
    CentOS)     OS_NAME="centos" ;;
    *)          OS_NAME="rhel" ;;
esac

OS_GROUP=1
DEF_OPENSSL_VER=1.1.1a
DEF_NPS_VERSION=1.13.35.2-stable
DEF_NGNX_VER=$(nginx -v 2>&1 | grep "/" | awk -F '/' '{print $2}')
DIR_VESTA_NGNX_TPL="/usr/local/vesta/data/templates/web/nginx/"

if [[ $OS_NAME == "debian" || $OS_NAME == "ubuntu" ]]
then
    OS_GROUP=2
fi

echo -n "Enter version Nginx [$DEF_NGNX_VER]: "
read NGNX_VER
if [ -z $NGNX_VER ]
then
    NGNX_VER=$DEF_NGNX_VER
fi

echo -n "Enter version OpenSSL [$DEF_OPENSSL_VER]: "
read OPENSSL_VER
if [ -z $OPENSSL_VER ]
then
    OPENSSL_VER=$DEF_OPENSSL_VER
fi

echo -n "Enter version PageSpeed [$DEF_NPS_VERSION]: "
read NPS_VERSION
if [ -z $NPS_VERSION ]
then
    NPS_VERSION=$DEF_NPS_VERSION
fi

echo  "Start install dependecies"
#install dependecies
if [[ $OS_GROUP  == 1 ]]
then
    sudo yum check-update || sudo yum update -y
    sudo yum install gcc-c++ pcre-devel zlib-devel make unzip libuuid-devel gcc
else
    sudo apt-get update
    sudo apt-get upgrade
    sudo apt-get install libpcre3 libpcre3-dev checkinstall zlib1g-dev uuid-dev build-essential unzip libssl-dev -y
    sudo apt-get build-dep nginx -y
fi

if [[ $OS_NAME == "centos" ]]
then
    PS_NGX_EXTRA_FLAGS="--with-cc=/opt/rh/devtoolset-2/root/usr/bin/gcc"
    sudo rpm --import http://linuxsoft.cern.ch/cern/slc6X/i386/RPM-GPG-KEY-cern
    sudo wget -O /etc/yum.repos.d/slc6-devtoolset.repo http://linuxsoft.cern.ch/cern/devtoolset/slc6-devtoolset.repo
    sudo yum install devtoolset-2-gcc-c++ devtoolset-2-binutils
fi


echo  "Start download Nginx"
#download nginx
wget http://nginx.org/download/nginx-${NGNX_VER}.tar.gz
if [[ $? -ne 0 ]]; then
    echo "Error download Nginx"
    exit 1;
fi
tar -xvzf nginx-${NGNX_VER}.tar.gz
cd nginx-${NGNX_VER}/


echo  "Start download PageSpeed"
#pagespeed module
wget https://github.com/pagespeed/ngx_pagespeed/archive/v${NPS_VERSION}.zip
if [[ $? -ne 0 ]]; then
    echo "Error download PageSpeed"
    exit 1;
fi
unzip v${NPS_VERSION}.zip

nps_dir=$(find . -name "*pagespeed-ngx-${NPS_VERSION}" -type d)
cd "$nps_dir"
NPS_RELEASE_NUMBER=${NPS_VERSION/beta/}
NPS_RELEASE_NUMBER=${NPS_VERSION/stable/}
psol_url=https://dl.google.com/dl/page-speed/psol/${NPS_RELEASE_NUMBER}.tar.gz
[ -e scripts/format_binary_url.sh ] && psol_url=$(scripts/format_binary_url.sh PSOL_BINARY_URL)

echo  "Start download PSOL"
wget ${psol_url}
if [[ $? -ne 0 ]]; then
    echo "Error download PSOL $psol_url"
    exit 1;
fi

tar -xzvf $(basename ${psol_url})
cd ..


echo  "Start download OpenSSL"
#download openssl
wget https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz
if [[ $? -ne 0 ]]; then
    echo "Error download OpenSSL"
    exit 1;
fi
tar -xzvf openssl-${OPENSSL_VER}.tar.gz

echo  "Start configure Nginx"
#configure
make clean

configure="./configure "
configure+=$(nginx -V 2>&1 | grep "configure arguments:" | awk -F'configure arguments: ' '{print $2}')
configure+=" --with-openssl=openssl-${OPENSSL_VER}"
configure+=" --add-module=$nps_dir ${PS_NGX_EXTRA_FLAGS}"
echo $configure;
eval $configure

if [[ $? -ne 0 ]]; then
    echo "Error configure Nginx"
    exit 1;
fi

echo  "Start make Nginx"
#compile
make

if [[ $? -ne 0 ]]; then
    echo "Error make Nginx"
    exit 1;
fi


if [[ $OS_GROUP == 1 ]]
then
    sudo make install
else
    sudo checkinstall -y
fi


if [[ $? -ne 0 ]]; then
    echo "Error build package Nginx"
    exit 1;
fi
nginx -V


echo -n "Overwrite web templates Nginx? [yes] (Y/n) "
read overwrite
if [[ $overwrite = y || $overwrite = Y || -z $overwrite ]]
then
    cd ../tpl
    for file in *; do
        oldFile="$DIR_VESTA_NGNX_TPL$file"
        if [ -f $oldFile ]; then
            mv $oldFile "${oldFile}.old"
        fi
        cp $file "$DIR_VESTA_NGNX_TPL$file"
    done
fi


echo -n "Rebuild config Nginx for all sites? [yes] (Y/n) "
read rebuild
if [[ $rebuild = y || $rebuild = Y || -z $rebuild ]]
then
   for user in $(v-list-sys-users plain); do v-rebuild-web-domains $user; done
    nginx -t
fi

echo -n "Restart Nginx? [yes] (Y/n) "
read restart
if [[ $restart = n || $restart = N ]]
then
    exit 1
fi

if [[ $OS_GROUP  == 2 ]]
then
    systemctl daemon-reload
fi

service nginx restart