FROM nginx
COPY _app/etc/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY _site /usr/share/nginx/html
