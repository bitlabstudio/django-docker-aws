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

For this guide I assume, that you have accounts on:

* AWS
* circleci.com
* hub.docker.com
* github.com (bitbucket.com will work, too)


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

* Log in to circleci.com and link your github account
* Go to "ADD PROJECTS" and find the project, you'd like to build and click "Build project"
* The first build will probably do nothing but run 0 tests, which results in a
  successful build
* Now add a `circle.yml` that actually does stuff and some tests, if you don't
  have any already
* Commit and push the changes and circleci will pick up on that and execute the
  commands from `circle.yml`
  
Before we continue here, we'll set up Docker Hub.


## Docker Hub

* Log in at hub.docker.com
* Create a new private repo `username/myproject`
* Go back to circleci and go to your new project and to "Project Settings"
* There go to "Environment Variables"
* Define variables `DOCKER_EMAIL`, `DOCKER_PASS` (password) and `DOCKER_USER`
* Also while you're at it, you need to define `AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY` and `AWS_DEFAULT_REGION`
    * look up AWS availability zones or use something like `ap-southeast-1` for
      Singapore. It doesn't really matter, if you just want to test
* Add a `deploy.sh` and add that to the `cirlce.yml`
    * what the `deploy.sh` should do at this stage is build the docker image
      and push it to the docker hub.


## Preparing secret settings

* Go to Amazon IAM > Roles > ecsInstanceRole (that's the one ECS just created)
* Click on "Create Role Policy" > Custom Policy
* Add the following code and replace the BUCKETNAME with something secret  
  (we're about to create that bucket in a second)
  
  
    {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Action": [
                  "s3:GetObject"
              ],
              "Sid": "Stmt0123456789",
              "Resource": [
                  "arn:aws:s3:::BUCKETNAME/ecs.config",
                  "arn:aws:s3:::BUCKETNAME/server_settings.py.myproject"
              ],
              "Effect": "Allow"
          }
      ]
    }
    
* Locally create the file ecs.config and add


    ECS_ENGINE_AUTH_TYPE=dockercfg
    ECS_ENGINE_AUTH_DATA={"https://index.docker.io/v1/":{"auth":"AUTH_TOKEN","email":"DOCKER_EMAIl"}}
    
* Obviously you want to enter your docker email instead of `DOCKER_EMAIL`
* The `AUTH_TOKEN` you can aquire by typing `docker login` and entering your
  username and password. It then outputs a path, where the credentials are
  saved along with the token.
* Install `awscli` (AWS Command Line Interface) if you haven't already
    * run `aws configure` and enter the required information
    * see here for details http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-using-examples
* Go to Amazon S3
* Create a new bucket named `BUCKETNAME`
* Run `aws s3 cp ecs.config s3://BUCKETNAME/ecs.config`
* This will by default create a file, that is only accessible by authenticated
  users
  
This is btw how we will later deal with secret server settings as well.


## ECS

* I found it easiest to just run the EC2 Container Service "first run" wizard
  once. It will setup instance and service roles for you and show you how a
  running cluster would look like
* Afterwards you can delete the cluster again by clicking the X on the cluster
  on the ECS dashboard
  

## Provisioning with CloudFormation

* Add CloudFormation template to your project
    * you can download the ECS default template and go from there or take the
      one from this project as example to customize to your needs
* Go To Amazon CloudFormation
* Click "Create Stack"
* Choose to upload your template
    * Optionally you can upload the template to one of your S3 buckets and
      just insert the link
* Click Next
* Fill out "Stack name" and other required fields
    * "SecretsBucket" refers to the `BUCKETNAME`, that we've used earlier
* Click Next and Next again (which skips the Options/Tags step)
* Review and click "Create"
* Wait until the stack is created and then visit EC2 Container Service, where
  you can review your cluster running 
  

## Deploy issues

I had the problem, that once there are 2 running tasks and the script updates
them, they get stuck and the deploy script returns "Waiting for stale
deployments" and will eventually time out.
A way to work around this is to stop the running tasks right after the script
has pushed to the docker hub and then it can re-deploy the new ones.
Sometimes you need to repeatedly stop the tasks in order for it to work.

This is obviously not, what a deployment should look like.
According to the docs, the container service should re-deploy one container
after the other.

**WIP**


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
* I'm actually thinking about giving Amazon ECR a go. But I think it isn't
  available in all zones
* I'm experiencing an issue, that after updating the launch configuration of a
  cluster, afterwards there's a new cluster `default` where the new instances
  are spawned in, leaving the original cluster empty.  
  How to verify:
  * spawn a new cluster `myproject` through the first run wizard
  * go through the launch configuration setup (copy, add user data, copy again)
  * once you have set the ASG to respawn 2 instances and they get to the 
    initializing state, the second cluster appears.
  * I assume, that it's an error with the CloudFormation template used by ECS.
    `Parameters.EcsClusterName.Default` is `default`. Could it be, that it
    falls back to this value?
