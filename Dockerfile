FROM clearlinux:latest
RUN swupd bundle-add nginx curl --quiet && swupd clean --all --quiet \
&& mkdir -p  /etc/nginx/conf.d && mkdir -p /var/www && cp -f /usr/share/nginx/conf/nginx.conf.example /etc/nginx/nginx.conf \
&& echo -e "\
server { \n\
  server_name localhost; \n\
  listen DEFAULT; \n\
  location / { \n\
      root /var/www/; \n\
      autoindex on;  \n\
      } \n\
} \n\  
" > /etc/nginx/conf.d/mixer-server.conf \
&& mkdir /tmp/update \
&& curl -s https://api.github.com/repos/clearfraction/bundles/releases/latest \
      | grep browser_download_url | grep 'repo'  \
      | cut -d '"' -f 4 | xargs -n 1 curl -s -L -o /tmp/latest.tar \
&& tar xf /tmp/latest.tar -C /tmp && mv /tmp/tmp/repo/update/* /tmp/update \
&& curl -s https://api.github.com/repos/clearfraction/bundles/releases \
      | grep browser_download_url  | grep 'repo' \
      | cut -d '"' -f 4 | sed '1d' | head -n 2 > /tmp/urls \
&& cat /tmp/urls | while read line; do curl -s -LO $line \
    && file=`basename $line` \
    && ver=`echo $file | sed -e s/[^0-9]//g` \
    && tar xf $file tmp/repo/update/$ver -C /tmp && rm -f $file \
    && mv /tmp/repo/update/$ver /tmp/update; \
    done \
&& mv /tmp/update /var/www/ && rm -rf /tmp/*
CMD /usr/bin/sed -i 's/DEFAULT/'"$PORT"'/'  /etc/nginx/conf.d/mixer-server.conf && /usr/bin/nginx -g 'daemon off;'