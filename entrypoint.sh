#!/bin/sh

echo "parsing configs"
for i in $(cat deploy/config.json|jq -r '.|keys[] as $k| "\($k),\(.[$k])"' )
  do export $(echo $i|cut -d',' -f1)=$(echo $i|cut -d',' -f2)
done

env