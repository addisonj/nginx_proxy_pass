FROM nginx:1.15

RUN rm /etc/nginx/conf.d/* && mkdir -p /etc/nginx/stream.d/
COPY start.sh /usr/local/bin/start_nginx

CMD ["start_nginx"]
