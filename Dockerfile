# The main Dockerfile for our web container
FROM python:2.7

VOLUME /etc/nginx/conf.d/
COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY . /home/docker/code/

WORKDIR /home/docker/code/

RUN pip install -r requirements.txt

# I use gunicorn here, because it just works as opposed to uwsgi, which seems to
# fail starting even with the simplest of setups
CMD /usr/local/bin/gunicorn myproject.wsgi:application -w 2 -b :8000
#CMD ["uwsgi", "--ini", "/home/docker/code/uwsgi.ini"]
