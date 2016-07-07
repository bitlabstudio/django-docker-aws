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

At first I intended to write the setup steps below only for setting up THIS
particular project, but I figured, that the problems, I faced lied in upgrading
a different existing project to this stack, so I'll go over all of the steps
required and leave it up to you to skip, what you don't need.

The referenced files can obviously looked up inside this repo. They won't fit
all purposes, but might be a good starting point.


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
    * ...
    * Profit!
    

## Continuous Integration

* make an account at circleci.com or log in and link your github account
* go to "ADD PROJECTS" and find the project, you'd like to build and click "Build project"
* the first build will probably do nothing but run 0 tests, which results in a
  successful build
* now add a `circle.yml` that actually does stuff and some tests, if you don't
  have any already
* commit and push the changes and circleci will pick up on that and execute the
  commands from `circle.yml`
  
Before we continue here, we'll set up Docker Hub.


## Docker Hub

* make an account at hub.docker.com or log in. The first private repo is free.
* create a new private repo `username/myproject`
* go back to circleci and go to your new project and to "Project Settings"
* there go to "Environment Variables"
* define variables `DOCKER_EMAIL`, `DOCKER_PASS` (password) and `DOCKER_USER`
* also while you're at it, you need to define `AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY` and `AWS_DEFAULT_REGION`
    * look up AWS availability zones or use something like `ap-southeast-1` for
      Singapore. It doesn't really matter, if you just want to test
* add a `deploy.sh` and add that to the `cirlce.yml`
    * what the `deploy.sh` should do at this stage is build the docker image
      and push it to the docker hub.



# Notes and TODOs

I use this section to just quickly note down some things, that I or you should
keep in mind.

* ATM I use gunicorn instead of uwsgi, because it just worked as opposed to
  uwsgi, which seemed to fail even in the simplest of setups.  
  To verify this, clone the project and do the following steps:
    * open `Dockerfile` and commend out the 2nd last line and comment in the
      last. You should now have enabled the `CMD` containing `uwsgi`.
    * comment uWSGI back in in the `requirements.txt` file
    * if you haven't already created a virtual machine for `myproject` enter
      `docker-machine create -d virtualbox --virtual-memory "4048" myproject`
    * `eval $(docker-machine env myproject)`
    * `docker-compose build`
    * `docker-compose up -d`
    * `docker-machine ls` and copy the IP there
    * navigate to the IP in a browser
    * It should show a 503 or a 404 error depending on how future commits might
      change the `uwsgi.ini`
