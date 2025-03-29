#!/bin/bash

# Ensure version and coin value arguments are provided
if [[ -z "$1" ]] || [[ -z $2 ]]; then
  echo "Usage: $0 <qclient_version> <coin_count>"
  echo "e.g.: $0 2.0.4.1 100"
  exit 1
fi

qclient_version=$1
coin_count=$2

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    release_os="linux"
    if [[ $(uname -m) == "aarch64"* ]]; then
        release_arch="arm64"
    else
        release_arch="amd64"
    fi
else
    release_os="darwin"
    release_arch="arm64"
fi

echo "Searching for up to $coin_count coins to merge"

#Get coins
coins=$(./qclient-$qclient_version-$release_os-$release_arch --public-rpc token coins)

#Join coin addresses with requested value into space-separated string
coin_addrs=$(echo "$coins" | grep -oP '(?<=Coin\s)[0-9a-fx]+' | head -n $coin_count | tr '\n' ' ')

#Exit if no coin addresses were found
if [[ -z "$coin_addrs" ]]; then
  echo "Sorry, no coins were found"
  exit 1
fi

echo "Merging coins: $coin_addrs"

#Merge coins
./qclient-$qclient_version-$release_os-$release_arch --public-rpc token merge $coin_addrs"