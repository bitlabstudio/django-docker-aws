FROM nginx
COPY /home/docker/code/nginx.conf /etc/nginx/conf.d/default.conf
CMD nginx -g 'daemon off;'
