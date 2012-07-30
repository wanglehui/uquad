#!/bin/bash -e
# start server
if [ ! `pidof -s server` = "" ]; then
    echo "Server already running..."
else
    cd ../src/build/check_net
    make
    ./server &
    cd -
    # wait for server
    echo "Wait for server to start..."
    sleep 2
    echo "Server running"
fi
ssh root@10.42.43.2

