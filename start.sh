#!/bin/bash

serverName=${SERVER_NAME:-default}
if [ -z "$UPSTREAM_SERVER" ]; then
  echo "missing UPSTREAM_SERVER env var"
  exit 1
fi
upstream=${UPSTREAM_SERVER}
echo "setting $serverName to proxy to $upstream"
listenPort=${PORT:-${PORT0:-80}}
disableVerify=""
if [ -n "$DISABLE_SSL_VERIFY" ]; then
  disableVerify="proxy_ssl_verify       off;"
fi

if [ -z "$TCP_PROXY" ]; then
  cat << EOF > /etc/nginx/conf.d/http_proxy.conf
server {
  listen $listenPort;
  listen [::]:$listenPort;

  server_name $serverName;

  location / {
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header Host \$host;
      proxy_ssl_server_name on;
      proxy_ssl_session_reuse on;
      $disableVerify
      proxy_pass $upstream;
  }
}
EOF
else
  cat << EOF > /etc/nginx/stream.d/tcp_proxy.conf
upstream backend {
   server $upstream;
}

server {
  listen $listenPort;
  proxy_pass backend;
}
EOF
fi

cat << EOF > /etc/nginx/nginx.conf

user  nginx;
worker_processes  1;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types; default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;
}

stream {
    log_format main '\$remote_addr [\$time_local] '
                 '\$protocol \$bytes_sent \$bytes_received '
                 '\$session_time "\$upstream_addr" '
                 '"\$upstream_bytes_sent" "\$upstream_bytes_received" "\$upstream_connect_time"';

    access_log /var/log/nginx/access.log  main;
    error_log  /var/log/nginx/error.log;

    include /etc/nginx/stream.d/*.conf;
}
EOF

echo "starting nginx on $listenPort with conf:"

cat /etc/nginx/nginx.conf /etc/nginx/conf.d/*.conf /etc/nginx/stream.d/*.conf

exec nginx -g "daemon off;"
