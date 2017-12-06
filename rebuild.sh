#!/bin/bash
#http://nginx.org/download/
#https://developers.google.com/speed/pagespeed/module/
#https://www.openssl.org/source/

DEF_OPENSSL_VER=1.1.0g
DEF_NPS_VERSION=1.12.34.3-stable
DEF_NGNX_VER=$(nginx -v 2>&1 | grep "/" | awk -F '/' '{print $2}')
DIR_VESTA_NGNX_TPL="/usr/local/vesta/data/templates/web/nginx/"

echo -n "Enter version ngnx [$DEF_NGNX_VER]:"
read NGNX_VER
if [ -z $NGNX_VER ]
then
NGNX_VER=$DEF_NGNX_VER
fi

echo -n "Enter version openssl [$DEF_OPENSSL_VER]:"
read OPENSSL_VER
if [ -z $OPENSSL_VER ]
then
OPENSSL_VER=$DEF_OPENSSL_VER
fi

echo -n "Enter version pagespeed [$DEF_NPS_VERSION]:"
read NPS_VERSION
if [ -z $NPS_VERSION ]
then
NPS_VERSION=$DEF_NPS_VERSION
fi

echo  "Start install dependecies"
sudo apt-get update
sudo apt-get upgrade
#install dependecies
sudo apt-get install libpcre3 libpcre3-dev checkinstall zlib1g-dev build-essential unzip libssl-dev -y 
sudo apt-get build-dep nginx -y

echo  "Start download nginx"
#download nginx
wget http://nginx.org/download/nginx-${NGNX_VER}.tar.gz
if [[ $? -ne 0 ]]; then
    echo "Error download nginx"
    exit 1; 
fi
tar -xvzf nginx-${NGNX_VER}.tar.gz
cd nginx-${NGNX_VER}/

echo  "Start download pagespeed"
#pagespeed module
wget https://github.com/pagespeed/ngx_pagespeed/archive/v${NPS_VERSION}.zip
if [[ $? -ne 0 ]]; then
    echo "Error download pagespeed"
    exit 1; 
fi
unzip v${NPS_VERSION}.zip
cd ngx_pagespeed-${NPS_VERSION}/
psol_url=https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz
[ -e scripts/format_binary_url.sh ] && psol_url=$(scripts/format_binary_url.sh PSOL_BINARY_URL)

echo  "Start download PSOL"
wget ${psol_url}
if [[ $? -ne 0 ]]; then
    echo "Error download PSOL"
    exit 1; 
fi
tar -xzvf $(basename ${psol_url}) 
cd ..

echo  "Start download openssl"
#download openssl
wget https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz
if [[ $? -ne 0 ]]; then
    echo "Error download openssl"
    exit 1; 
fi
tar -xzvf openssl-${OPENSSL_VER}.tar.gz

echo  "Start configure nginx"
#configure
make clean

#if [ "$(uname -m)" = x86_64 ]; then
#export CFLAGS="-fPIC"
#fi

configure="./configure "
configure+=$(nginx -V 2>&1 | grep "configure arguments:" | awk -F'configure arguments: ' '{print $2}')
configure+=" --with-openssl=openssl-${OPENSSL_VER}"
configure+=" --add-module=ngx_pagespeed-${NPS_VERSION}"
echo $configure;
eval $configure

if [[ $? -ne 0 ]]; then
    echo "Error configure nginx"
    exit 1; 
fi

echo  "Start make nginx"
#compile
make

if [[ $? -ne 0 ]]; then
    echo "Error make nginx"
    exit 1; 
fi

echo -n "Build and install new nginx? [yes] (Y/n)"
read inst
if [[ $overwrite = n || $overwrite = N ]]
then
  checkinstall --install=no -y
  exit 1;
fi

checkinstall -y
if [[ $? -ne 0 ]]; then
    echo "Error build package nginx"
    exit 1; 
fi
nginx -V


echo -n "Overwrite web templates nginx? [yes] (Y/n)"
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


echo -n "Rebuild config nginx for all sites? [yes] (Y/n)"
read rebuild
if [[ $rebuild = y || $rebuild = Y || -z $rebuild ]]
then
   for user in $(v-list-sys-users plain); do v-rebuild-web-domains $user; done
    nginx -t
fi

echo -n "Restart nginx? [yes] (Y/n)"
read restart
if [[ $restart = n || $restart = N ]]
then
    exit 1
fi

systemctl daemon-reload
service nginx restart