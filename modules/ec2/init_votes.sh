#!/bin/bash
set -x
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 273440013219.dkr.ecr.us-east-1.amazonaws.com
docker run -d -p 9002:9002 --restart unless-stopped --name votes 273440013219.dkr.ecr.us-east-1.amazonaws.com/votes:latest
