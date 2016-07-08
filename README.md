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


## ECS

* Log in to aws.amazon.com
* Go to EC2 Container Service (short: ECS)
* Click "Get started" 
    * if you already have a cluster, visit the first run wizard again through
      this link https://console.aws.amazon.com/ecs/home?region=us-east-1#/firstRun
    * change region to whatever you want
* Uncheck "Store container images securelt with Amazon ECR" > Continue
* Now consistent naming is important!
* Task definition name: myproject-task
* Container name: nginx
* Image: nginx
* The rest we keep for now > Next step
* Service name: myproject-service
* Desired number of tasks: 2
* Container name:host port: nginx:80
* The Rest can stay like this. The IAM Role at the bottom should be created.
  ECS takes care of this for you then. > Next step
* Cluster name: myproject
* EC2 instance type: keept it at t2.micro for now. Probably want at least a
  small later, because we'll be adding Celery workers to each instance as well.  
  But micro is within the free tier, so let's keep it at this.
* Number of instances: 2 (the same as No of tasks)
* Create a Key Pair in the EC2 console (link below the dropdown) and select that.  
  Make sure, you have the file ready and safely stored as you will need it for
  SSH.
* Here you do the same with the instance IAM role as we did before with the
  service role. > Review & launch
* Check for typos again and if everything looks correct click "Launch instance
  & run service"
* Now ECS will pull up its Amazon CloudFormation template to create all
  security groups, instances, ELB, ASG etc.
* Once that is done click "View Service"

Thkre should now be 2 instances listed and a desired task count of 2.
The issue is however, that the instances won't be able to pull from the docker
hub, because we've created a private repo.
We need to work around this a little bit.


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
  

## Updating Launch Configurations

* Go to Amazon EC2 Console
* Go to launch configurations
* Select the launch configuration, that ECS just generated
* Click "Copy launch configuration"
* Open "Configure Details" Tab and "Advanced Details"
* Replace "User data" with following code:


    #!/bin/bash
    yum install -y aws-cli
    aws s3 cp s3://BUCKETNAME/ecs.config /etc/ecs/ecs.config
    
* This means, that this is executed every time a container instance is launched
  from this launch configuration
* Skip to Review
* Create launch configuration
* Select key pair, that you've previously created and Create launch configuration
* Go to Auto Scaling Groups and select the ECS created one
* On the Details tab click Edit
* Select the copied launch configuration AND the load balancer, that ECS created
* Set Desired and Min to 0 and click Save
* This will actually despawn all the instances, but that's okay, we want them to
  be recreated with the new LC later

Now there's one problem. Since the new LC is called something like
`EC2ContainerService-myproject-EcsInstanceLc-somethingCopy`, this isn't the name
that was assigned in the CloudFormation Template, that was used to spawn the
instances in the first place, when we used the wizard earlier.
That means, when you want to change it in the backend, things might not work,
because it doesn't recognize it any more.
I found that you can do the following:

* Go to LC screen again
* Select the original LC (without the "Copy" at the end) and click Actions
  > Delete launch configuration
* Select the new LC and click "Copy launch configuration" again
* Now go to "Configure details" again, but only remove the "CopyCopy" from the
  name
* Skip to Review > Create > select key > Create > Close
* Back to the auto scaling group again and > Edit
* Set Desired back to 2 and Min back to 1
* Select the Launch Configuration, that doesn't have the "Copy" at the end
* Save

Now this will respawn the 2 instances with the new LC, that contains the proper
`ecs.config`, which means, that the instance is now able to pull from our
private docker repo.


## Making first deployment

* You should see, that the myproject cluster shows 2 registered container
  instances
* When you open the cluster and go to the Tasks tab, you might see a pending
  task pop up or see a bunch of stopped tasks under the "stopped" filter.
* Now we need to rebuild with the full `deploy.sh` script since for now we
  only pushed the image to the hub. Now we also want to tell ECS, what the
  new image is called exactly and update the task definition and the service
  of our cluster. That means, that it will be able to pull the new image and
  deploy it on the instances.
* Submit the updated `deploy.sh` to the repo or if you already have it, just
  go to circleci and click "Rebuild".
* Wait for it. It should run the tests really fast and then upload the image
  and after that is done update the task definition.
  
If everything is correct, then you can check the cluster and notice, that under
the service Tab, the task definition should have changed from `myproject-task:1`
to `myproject-task:2`, which means, it's the new version of the task with the
new image.
And under Tasks it should either have 2 tasks with status "RUNNING" or "PENDING"
which should soon turn into "RUNNING".

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
