#!/usr/bin/env bash
tag=$1
url=$2
dir=$3
echo $url
echo $tag
if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
fi
docker build -t $tag ../$dir/
aws ecr get-login-password | docker login --username AWS --password-stdin $url
docker tag $tag:latest $url
docker push $url:latest --quiet


