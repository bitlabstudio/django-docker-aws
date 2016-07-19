#!/usr/bin/env bash

# credits go to https://github.com/circleci/circle-ecs/blob/master/deploy.sh

set -e
set -u
set -o pipefail
PROJECT_NAME="myproject"

# more bash-friendly output for jq
JQ="jq --raw-output"

# These variables usually get defined by circleci, if you want to run this
# script locally though, you need to provide the projectvars.json file

CONTAINER_NAME="djangodockeraws_web"
# TODO this causes an error on circleci, that makes it skip this step, but locally it works and it looks as if the deployment would still work correctly
if [ -z "${DOCKER_USER:''}" ]; then
    # this was basically just meant to be a simplification to work locally
    # but if you're into storing credentials in a json file locally, you cen
    # of course use it too
    CIRCLE_SHA1="latest"
    CLUSTER_NAME="$(cat projectvars.json | $JQ ".[0].clustername")"
    SERVICE_NAME="$(cat projectvars.json | $JQ ".[0].servicename")"
    TASK_NAME="$(cat projectvars.json | $JQ ".[0].taskname")"
    CONTAINER_NAME="$(cat projectvars.json | $JQ ".[0].containername")"
    DOCKER_PASS="$(cat projectvars.json | $JQ ".[0].dockerpass")"
    DOCKER_USER="$(cat projectvars.json | $JQ ".[0].dockeruser")"
    DOCKER_EMAIL="$(cat projectvars.json | $JQ ".[0].dockeremail")"
fi;

deploy_image() {

    # this copies the secret settings from our private bucket into the build folder for the docker file to find
#    aws s3 cp s3://mysecretbucket/server_settings.py.$PROJECT_NAME ../server_settings.py --region ap-southeast-1
    docker-compose build web
    docker images
    docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS
    # tag with current sha to uniquely identify image and upload
    # TODO find better way to define this container name > not hard coded
    docker tag $CONTAINER_NAME $DOCKER_USER/$PROJECT_NAME:$CIRCLE_SHA1
    docker push $DOCKER_USER/$PROJECT_NAME:$CIRCLE_SHA1 | cat
    # tag again as latest for easier reference and upload again
    docker tag $CONTAINER_NAME $DOCKER_USER/$PROJECT_NAME:latest
    docker push $DOCKER_USER/$PROJECT_NAME:latest | cat

}

# reads $CIRCLE_SHA1
# sets $task_def
make_task_def() {

    task_template='[
	{
	    "name": "web",
	    "image": "%s/%s:%s",
	    "portMappings": [
            {
                "containerPort": 8000,
                "hostPort": 8000
            }
	    ],
	    "cpu": 256,
	    "memory": 300,
	    "essential": true
	},
	{
	    "name": "nginx",
	    "image": "nginx",
	    "portMappings": [
            {
                "containerPort": 80,
                "hostPort": 80
            }
	    ],
        "links": [
          "web"
        ],
	    "volumesFrom": [
	        {
	            "sourceContainer": "web",
                "readOnly": true
	        }
	    ],
	    "cpu": 256,
	    "memory": 128,
	    "essential": true
	}
    ]'

    task_def=$(printf "$task_template" $DOCKER_USER $PROJECT_NAME $CIRCLE_SHA1)

}

# reads $task_name
# sets $revision
register_definition() {

    if revision=$(aws ecs register-task-definition --container-definitions "$task_def" --family "$TASK_NAME" | $JQ '.taskDefinition.taskDefinitionArn'); then
        echo "Revision: $revision"
    else
        echo "Failed to register task definition"
        return 1
    fi

}

deploy_cluster() {

    make_task_def
    register_definition
    if [[ $(aws ecs update-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" --task-definition $revision | \
                   $JQ '.service.taskDefinition') != $revision ]]; then
        echo "Error updating service."
        return 1
    fi
    # CI only triggers the deployment when passing it to the service.
    # The actual deployment is then done by ECS, so we can end here.
    echo "Service updated! Please check ECS for information on the status of the deployment."
    return 0
}

deploy_image
deploy_cluster