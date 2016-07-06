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

* install docker toolbox https://www.docker.com/products/docker-toolbox
* you can test the setup locally by running
    * `docker-machine create -d virtualbox --virtual-memory "4048" myproject`
    * `eval $(docker-machine env myproject)`
    * `docker-compose build`
    * `docker-compose up -d`
    * `docker-machine ls` and copy the IP there
    * navigate to the IP in a browser
    
If you were only to create a single server project on AWS, you could just finish
this by setting up your AWS credentials and by then typing:


    docker-machine create -d amazonec2 myprojectaws
    eval $(docker-machine env myprojectaws)
    docker-compose build
    docker-compose up -d
    
Then you should have your single instance ready and deployed on AWS. Note, that
default availability zone is US East.

But obviously we don't want that. So we'll continue with CI.


# Notes and TODOs

I use this section to just quickly note down some things, that I or you should
keep in mind.

* ATM I use gunicorn instead of uwsgi, because it just worked as opposed to
  uwsgi, which seemed to fail even in the simplest of setups
