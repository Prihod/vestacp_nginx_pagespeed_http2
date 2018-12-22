# Description
Rebuild Nginx with Google PageSpeed and http/2 for VestaCP.  
Overwrite templates default.stpl and default.tpl.  
Rebuild config Nginx for all sites.
# Install
    cd /usr/local/src/
    git clone https://github.com/Prihod/vestacp_nginx_pagespeed_http2.git
    cd vestacp_nginx_pagespeed_http2/
    chmod +x rebuild.sh
    sudo ./rebuild.sh
Links
-----------
<https://vestacp.com/>

<http://nginx.org/download/>  

<https://developers.google.com/speed/pagespeed/module/>  

<https://www.openssl.org/source/> 

[Vesta upgrade PHP](https://www.mysterydata.com/how-to-upgrade-php-7-0-to-php-7-1-or-php-7-2-on-ubuntu-vestacp/)

[Vesta dkim public key located](https://github.com/serghey-rodin/vesta/issues/320)

[Vesta FIX phpmyadmin](https://forum.vestacp.com/viewtopic.php?t=10307)


Useful console commands Vesta
-----------
v-rebuild-web-domains USER [RESTART] - rebuild web domains
