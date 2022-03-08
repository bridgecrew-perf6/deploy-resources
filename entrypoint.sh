#!/bin/sh

echo "Deploying $GITHUB_JOB"

## Clone templates

git clone --single-branch --branch master https://github.com/nicolasdonoso/templates.git

## Check before script

export AWS_DEFAULT_REGION=$AWS_REGION
export RUN_ID=$GITHUB_RUN_ID ## Make this variable depending CI/CD provider

export CONTAINER_PORT=`cat Dockerfile | grep EXPOSE | cut -d ' ' -f 2`
if [[ $CONTAINER_PORT == "" ]]; then export CONTAINER_PORT=8888 ; fi

if [[ -z $ECR_REPO ]]
    then echo "ECR repo name defined by repo name"
    export REPO_NAME=$(echo $GITHUB_REPOSITORY|cut -d '/' -f2)
else
    echo "ECR repo name defined by env var ECR_REPO"
    export REPO_NAME=$ECR_REPO
fi

echo $K8S_KUBECONFIG | base64 -d > ./kube_config
kubectl config use-context $K8S_CLUSTER

if [[ -f deploy/secrets.yml ]]
  then echo "adding secrets"
  envsubst < deploy/secrets.yml > secrets.yml
  export creds=$(awk -v ORS="\n        " 1 secrets.yml)
fi
if [[ $local_redis == 'true' ]]
  then echo "adding local redis"
  export REDIS_HOST="localhost"
  envsubst < templates/manifests/sockets/redis.yml > redis.yml
  export redis=$(awk -v ORS="\n      " 1 redis.yml)
fi
if [[ $k8s_probes == 'true' ]]
  then echo "adding readiness and liveness probes"
  envsubst < templates/manifests/sockets/k8s_probes.yml > k8s-probes.yml
  export probes=$(awk -v ORS="\n        " 1 k8s-probes.yml)
fi
if [[ $volume_name ]]
  then echo "adding volume"
  envsubst < templates/manifests/sockets/volume.yml > volume.yml
  envsubst < templates/manifests/sockets/volume_mounts.yml > volume_mounts.yml
  export volume=$(awk -v ORS="\n      " 1 volume.yml)
  export volume_mounts=$(awk -v ORS="\n        " 1 volume_mounts.yml)
fi
if [[ $SERVICE == 'true' ]];
  then echo "deploying service resources"
  export SERVICE_NAME=$REPO
  if [[ $ROUTE ]]
    then echo "adding custom path / route"
    export SERVICE_NAME=$ROUTE
  fi
  envsubst < templates/manifests/sockets/ingress.yml > ingress.yml
  envsubst < templates/manifests/sockets/deployment.yml > deployment.yml
  envsubst < templates/manifests/sockets/service.yml > service.yml
else
  echo "deploying sockets ingress"
  envsubst < templates/manifests/sockets/ingress.yml > ingress.yml
  envsubst < templates/manifests/sockets/deployment.yml > deployment.yml
  envsubst < templates/manifests/sockets/service.yml > service.yml
fi

## DEPLOYMENT 
if [ -f deploy/deployment.yml ]
  then echo "local deployment files"
  envsubst < deploy/deployment.yml > deployment.yml
  kubectl apply -f deployment.yml -n $CI_JOB_STAGE
elif [[ $kind == "cron" ]]
  then echo "deploying cron"
  envsubst < templates/crons/cron.yml > cron.yml
  # cat cron.yml
  kubectl delete -f cron.yml -n $CI_JOB_STAGE || true;
  kubectl apply -f cron.yml -n $CI_JOB_STAGE
else
  # cat deployment.yml
  kubectl apply -f deployment.yml -n $CI_JOB_STAGE
fi

## SERVICE/INGRESS
if [ -f deploy/service.yml ]
  then echo "local service files"
  envsubst < deploy/service.yml > service.yml
else
  if [ ! -z "$DOCKER_PORT" ]; then kubectl apply -f service.yml -n $CI_JOB_STAGE; else echo 'no service'; fi
fi
# cat ingress.yml
if [ -f deploy/ingress.yml ]
  then echo "local ingress files"
  envsubst < deploy/ingress.yml > ingress.yml
else
  if [ ! -z "$DOCKER_PORT" ]; then kubectl apply -f ingress.yml -n $CI_JOB_STAGE; else echo 'no ingress'; fi
fi