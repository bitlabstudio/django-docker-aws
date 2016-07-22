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
* Celery and RabbitMQ for running tasks
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

* Create an IAM role named `ecsServiceRole` with the permission policy
  `AmazonEC2ContainerServiceRole`
* Create an IAM role named `ecsInstanceRole` with the permission policy
  `AmazonEC@ContainerServiceEC2Role`
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
                  "arn:aws:s3:::BUCKETNAME/server_settings.py.myproject",
                  "arn:aws:s3:::BUCKETNAME/ecs.config",
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


## Static files

* add a `custom_storages.py` file as you can see in this project under
  `myproject/`
  We need these classes so static and media files can reside in the same
  bucket, but under different folders.
* probably have set up a S3 bucket by now. If not go ahead and do so
* create a `local_settings.py` file from `local_settings.py.sample`. This file
  is not in version control
* add AWS credentials and bucket name to the config and point to the storage
  class in the `custom_storages` file you just added
  *Note: You probably want to add a local storage or dev bucket here, because
  you might not want to use the prod bucket in development, but for testing
  it won't matter.*
* you could now run `python manage.py collectstatic` and it should copy
  your static files to S3.
  Also if you have a filefield somewhere, all uploaded files should land inside
  that bucket as well.
* Since we want this to work on the server as well, we now want to create
  secret server settings, that our CI will bake into our secret image of our
  web container.
* Create a `server_settings.py` file from `local_settings.py.sample`.
  This file is also excluded from version control
* Here you want to add the credentials and bucket name of your prod bucket,
  that will be used by your servers.
* Now remember your secret bucket name? You'll need that now:


    aws s3 cp server_settings.py s3://secretbucketname/server_settings.py.myproject
    
* The deploy script will then pull this before CI builds the image so that
  CI can copy it to the container image.

## Issues

1. When you use a CloudFront Change Set to scale the cluster, the service
   returns to task revision 1.
   I'm not sure how bad this problem is, since 1 holds the `latest` image
   from our initial CF based provisioning, but this is obviously not how it's
   supposed to be.
   It should retain the task revision, that was on the service before the
   change is triggered.
2. While the deployment is running, ECS exchanges the containers with their new
   versions. It does this 50% at a time. When the first batch of new containers
   is deployed, there's a window of about 10 seconds, where there are new AND
   old containers on the cluster and users might randomly end up on either of
   them.
   This could cause problems especially when altering data through forms.
   User flows (ordering, paying, creating object, all kinds of wizards) could
   get broken for a that time.


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
