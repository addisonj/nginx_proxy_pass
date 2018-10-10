FROM nginx:1.15

COPY start.sh /usr/local/bin/start_nginx

CMD ["start_nginx"]
