# Simple research template for Django on AWS

This is WIP. Not intended to be used in the wild, yet.

This project aims to aid in researching an AWS infrastructure including:

* Running a scalable cluster on ECS/EC2 with Django/uwsgi/nginx
* S3 and and Postgres on RDS for file and data storage needs
* Elasticache for Memcached
* CircleCI for testing and building
* Docker and Docker Hub for containerizing and storing builds
* Celery, RabbitMQ and Redis for running tasks
* A yet undefined thumbnailing service
* A service, that triggers certain commands once per deployment

# Setting up the project

## Starting from an empty project you need to...

* Add docker files: `Dockerfile`, `docker-compose.yml`
* Add config files: `nginx.conf`, `uwsgi.ini`, `server_settings.py.myproject`
* Add CI config: `circle.yml`
* Add deploy script for CI: `deploy.sh`

I might add guides to set them up later.


## Once the project is ready

WIP
