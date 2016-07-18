# Simple research template for Django on AWS

This is WIP. Not intended to be used in the wild, yet.

If you stumble across this and can't get it to work or have questions, please
open an issue.
I will try to create a extensive guide on how all of the components are set up
in the future.

This project aims to aid in researching an AWS infrastructure including:

* Running a scalable cluster on ECS/EC2 with Django/uwsgi/nginx
* S3 file storage
* Postgres on RDS
* Elasticache for Memcached
* CircleCI for testing and building
* Docker and Docker Hub for containerizing and storing builds
* Celery, RabbitMQ and Redis for running tasks
* A yet undefined automatic thumbnailing service
* A service, that triggers certain commands once per deployment

Note: I will go over all the setup steps very briefly and I'll assume, that you
are kind of familiar with docker to write dockerfiles and compose files on your
own. Also it helps to know how circleci or similar CI services are set up.
The referenced files however can obviously looked up inside this repo. They
won't fit all purposes, but might be a good starting point.

If you use this repo as starting point/boilerplate or to try it out, this guide
should probably provide enough information to get everything running, even if
you don't know all that stuff I mentioned.

For this guide I assume, that you have accounts on:

* AWS
* circleci.com
* hub.docker.com
* github.com (bitbucket.com should work, too)


# Setting up the project

If you don't just clone this repo, you will need some kind of minimal django
project, that you now want to move to AWS.
Minimal means, that you can run `./manage.py runserver` locally and get some
positive response. Be it a CMS page or just some `TemplateView`. Anything
that will render something on the home page.


## Starting from an empty project you need to...

(you don't need this, if you use this example project, but it might be worth
to take a look)

* Add docker files: `Dockerfile`, `docker-compose.yml`
* Add config files: `nginx.conf`, `uwsgi.ini`, `server_settings.py.myproject`
* Add CI config: `circle.yml`
* Add deploy script for CI: `deploy.sh`


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
* Go to "ADD PROJECTS" and find the project, you'd like to build and click
  "Build project"
  
The next steps only apply to a new, empty project
  
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
* Add a `deploy.sh` and add its execution to the `cirlce.yml`
    * what the `deploy.sh` should do at this stage is build the docker image
      and push it to the docker hub. Check `deploy.sh` and `circle.yml`. The
      `deploy.sh` is largely how circleci provides it.
      

## IAM

* Create an IAM role `ecsInstanceRole` with the permission policy
  `AmazonEC@ContainerServiceEC2Role`
* And another one named `ecsServiceRole` with the permission policy
  `AmazonEC2ContainerServiceRole`


## Provisioning with CloudFormation (skip if you prefer CLI)

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
  

## Alternative CloudFormation way using CLI

* Create a json file `docker.json` with your docker auth token and email:


    [{
        "ParameterKey": "DockerAuthToken",
        "ParameterValue": "sometoken"
    },
    {
        "ParameterKey": "DockerEmail",
        "ParameterValue": "mail@example.com"
    }]

* This file should not live inside version control!
* Install `awscli` (AWS Command Line Interface) if you haven't already
    * run `aws configure` and enter the required information
    * see here for details http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-using-examples
* Enter the following command:


    aws cloudformation create-stack --stack-name myproject --template-body file:://path/to/my/cloudformation_template.json --parameters file://path/to/my/docker.json
    
* The files can also be urls. However if you provide a url to the template body
  file, you need to use `--template-url` instead.
* Open the CloudFormation console to watch the stack be created.


## Deploy issues

1. The CF stack gets stuck on deploying the service's tasks and triggers a
   rollback. This is because the containers don't run properly.
   ATM the uwsgi/gunicorn setup isn't running correctly.


**WIP**


## Preparing secret settings

This section needs to be revised. It was formerly a provisioning step, but now
has become obsolete due to CF templates.
It will however be necessary for secret setting still.

* Go to Amazon IAM > Roles > ecsInstanceRole (that's the one ECS has created)
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
