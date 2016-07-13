#!/usr/bin/env bash

# credits go to https://github.com/circleci/circle-ecs/blob/master/deploy.sh

set -e
set -u
set -o pipefail

PROJECT_NAME="myproject"

# more bash-friendly output for jq
JQ="jq --raw-output --exit-status"



cluster_name="myproject-EcsCluster-2UV2SK2QHSFE"
service_name="myproject-EcsService-1EMF7GAO9Q3FF"
task_name="myproject-EcsTaskDefinition-1EANXEO6KRI93"
DOCKER_PASS=$(cat ../docker.json | $JQ ".[0].pass")
DOCKER_USER=$(cat ../docker.json | $JQ ".[0].user")
DOCKER_EMAIL=$(cat ../docker.json | $JQ ".[0].email")

deploy_image() {

    # this copies the secret settings from our private bucket into the build folder for the docker file to find
#    aws s3 cp s3://mysecretbucket/server_settings.py.$PROJECT_NAME ../server_settings.py --region ap-southeast-1
    docker-compose build web
    docker images
    docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS
    # tag with current sha to uniquely identify image and upload
    # TODO find better way to define this container name > not hard coded
    docker tag djangodockeraws_web $DOCKER_USER/$PROJECT_NAME:$CIRCLE_SHA1
    docker push $DOCKER_USER/$PROJECT_NAME:$CIRCLE_SHA1 | cat
    # tag again as latest for easier reference and upload again
    docker tag djangodockeraws_web $DOCKER_USER/$PROJECT_NAME:latest
    docker push $DOCKER_USER/$PROJECT_NAME:latest | cat

}

# reads $CIRCLE_SHA1
# sets $task_def
make_task_def() {
#	{
#	    "name": "web",
#	    "image": "%s/%s:%s",
#	    "portMappings": [
#            {
#                "containerPort": 8000,
#                "hostPort": 8000
#            }
#	    ],
#	    "cpu": 256,
#	    "memory": 300,
#	    "essential": true
#	},

    task_template='[
	{
	    "name": "nginx",
	    "image": "nginx",
	    "portMappings": [
            {
                "containerPort": 80,
                "hostPort": 80
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

    if revision=$(aws ecs register-task-definition --container-definitions "$task_def" --family "$task_name" | $JQ '.taskDefinition.taskDefinitionArn'); then
        echo "Revision: $revision"
    else
        echo "Failed to register task definition"
        return 1
    fi

}

deploy_cluster() {

    make_task_def
    register_definition
    if [[ $(aws ecs update-service --cluster "$cluster_name" --service "$service_name" --task-definition $revision | \
                   $JQ '.service.taskDefinition') != $revision ]]; then
        echo "Error updating service."
        return 1
    fi

    # wait for older revisions to disappear
    # not really necessary, but nice for demos
    for attempt in {1..30}; do
        if stale=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" | \
                       $JQ ".services[0].deployments | .[] | select(.taskDefinition != \"$revision\") | .taskDefinition"); then
            echo "Waiting for stale deployments:"
            echo "$stale"
            sleep 5
        else
            echo "Deployed!"
            return 0
        fi
    done
    echo "Service update took too long."
    return 1
}

deploy_image
deploy_cluster