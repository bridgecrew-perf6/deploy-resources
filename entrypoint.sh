#!/bin/sh -l

echo "Deploying $GITHUB_JOB"

## Check before script

export RUN_ID=$GITHUB_RUN_ID ## Make this variable depending CI/CD provider
if [[ -z $ECR_REPO ]]
    then echo "ECR repo name defined by repo name"
    export REPO_NAME=$(echo $GITHUB_REPOSITORY|cut -d '/' -f2)
else
    echo "ECR repo name defined by env var ECR_REPO"
    export REPO_NAME=$ECR_REPO
fi
export AWS_DEFAULT_REGION=$AWS_REGION

echo $K8S_KUBECONFIG | base64 -d > ./kube_config
kubectl config use-context $K8S_CLUSTER
if [[ -f deploy/secrets.yml ]]
  then echo "adding secrets"
  envsubst < deploy/secrets.yml > secrets.yml
  export creds=$(awk -v ORS="\n        " 1 secrets.yml)
fi
if [[ $local_redis == "true" ]]
  then echo "adding local redis"
  export REDIS_HOST="localhost"
  envsubst < manifests/sockets/redis.yml > redis.yml
  export redis=$(awk -v ORS="\n      " 1 redis.yml)
fi
if [[ $k8s_probes == "true" ]]
  then echo "adding readiness and liveness probes"
  envsubst < manifests/sockets/k8s_probes.yml > k8s-probes.yml
  export probes=$(awk -v ORS="\n        " 1 k8s-probes.yml)
fi
if [[ $volume_name ]]
  then echo "adding volume"
  envsubst < manifests/sockets/volume.yml > volume.yml
  envsubst < manifests/sockets/volume_mounts.yml > volume_mounts.yml
  export volume=$(awk -v ORS="\n      " 1 volume.yml)
  export volume_mounts=$(awk -v ORS="\n        " 1 volume_mounts.yml)
fi
if [[ $SERVICE == "true" ]];
  then echo "deploying service resources"
  export SERVICE_NAME=$REPO
  if [[ $ROUTE ]]
    then echo "adding custom path / route"
    export SERVICE_NAME=$ROUTE
  fi
  envsubst < manifest/ingress.yml > ingress.yml
  envsubst < manifest/deployment.yml > deployment.yml
  envsubst < manifest/service.yml > service.yml
else
  echo "deploying sockets ingress"
  envsubst < manifest/ingress.yml > ingress.yml
  envsubst < manifest/deployment.yml > deployment.yml
  envsubst < manifest/service.yml > service.yml
fi
cat deployment.yml
cat service.yml
cat ingress.yml
# kubectl apply -f deployment.yml -n $CI_JOB_STAGE
# kubectl apply -f service.yml -n $CI_JOB_STAGE
# kubectl apply -f ingress.yml -n $CI_JOB_STAGE