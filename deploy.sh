#!/usr/bin/env bash

# credits go to https://github.com/circleci/circle-ecs/blob/master/deploy.sh

set -e
set -u
set -o pipefail

PROJECT_NAME="myproject"

# more bash-friendly output for jq
JQ="jq --raw-output --exit-status"

deploy_image() {

    # this copies the secret settings from our private bucket into the build folder for the docker file to find
#    aws s3 cp s3://mysecretbucket/server_settings.py.$PROJECT_NAME ../server_settings.py --region ap-southeast-1
    docker-compose build web
    docker images
    # TODO find better way to define this container name > not hard coded
    docker tag djangodockeraws_web $DOCKER_USER/$PROJECT_NAME:$CIRCLE_SHA1
    docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS
    docker push $DOCKER_USER/$PROJECT_NAME:$CIRCLE_SHA1 | cat

}

# reads $CIRCLE_SHA1
# sets $task_def
make_task_def() {

    task_template='[
	{
	    "name": "web",
	    "image": "$DOCKER_USER/$PROJECT_NAME:%s",
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
	    "cpu": 256,
	    "memory": 128,
	    "essential": true
	},
    ]'

    task_def=$(printf "$task_template" $CIRCLE_SHA1)

}

# reads $family
# sets $revision
register_definition() {

    if revision=$(aws ecs register-task-definition --container-definitions "$task_def" --family $family | $JQ '.taskDefinition.taskDefinitionArn'); then
        echo "Revision: $revision"
    else
        echo "Failed to register task definition"
        return 1
    fi

}

deploy_cluster() {

    family="$PROJECT_NAME-task"

    make_task_def
    register_definition
    if [[ $(aws ecs update-service --cluster $PROJECT_NAME --service $PROJECT_NAME-service --task-definition $revision | \
                   $JQ '.service.taskDefinition') != $revision ]]; then
        echo "Error updating service."
        return 1
    fi

    # wait for older revisions to disappear
    # not really necessary, but nice for demos
    for attempt in {1..30}; do
        if stale=$(aws ecs describe-services --cluster $PROJECT_NAME --services $PROJECT_NAME-service | \
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