#! /bin/bash

docker build \
    --build-arg USER_ID=$(id -u ${USER}) \
    --build-arg GROUP_ID=$(id -g ${USER}) \
    --build-arg LOCALE="sk_SK.UTF-8" \
    --build-arg TZ="Europe/Bratislava" \
    -t myvs_full2 \
    .
