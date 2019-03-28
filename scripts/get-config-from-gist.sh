#!/bin/bash

gistid=`cat ../sync.gist`
gisturl="https://gist.githubusercontent.com/${gistid}/raw"

curl -k -o ../extensions.json "${gisturl}/extensions.json"
curl -k -o ../settings.json "${gisturl}/settings.json"
