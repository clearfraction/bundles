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
&& curl --retry 3 -s https://api.github.com/repos/clearfraction/bundles/releases \
      | grep browser_download_url  | grep 'repo' \
      | cut -d '"' -f 4 | head -n 4 > /tmp/urls \
&& tac /tmp/urls | while read line; do curl --retry 3 -s -LO $line \
    && tar xf `basename $line` --strip-components=3 -C /tmp/update && rm -f `basename $line`; \
    done \
&& echo "Extract certificate from v37180" && curl --retry 3 -s -LO https://github.com/clearfraction/bundles/releases/download/37180/repo-37180.tar && tar xf repo-37180.tar tmp/repo/update/37180/files/f1d6861ae3d2f063490238750b53f75ecff91e766c23eba75290c1cc047ea035.tar --strip-components=3 && rm -rf repo-37180.tar && mv 37180 /tmp/update \   
&& curl --retry 3 -s https://raw.githubusercontent.com/clearfraction/clearfraction.github.io/main/media/favicon.ico -o /var/www/favicon.ico \    
&& mv /tmp/update /var/www/ && rm -rf /tmp/*
CMD /usr/bin/sed -i 's/DEFAULT/'"$PORT"'/'  /etc/nginx/conf.d/mixer-server.conf && /usr/bin/nginx -g 'daemon off;'
