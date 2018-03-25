#!/bin/bash
#
# An automated script to fetch the proper qcacld-2.0 driver from the repository according
# to the base Kernel branch instead of maintaining a local copy of it inside the Kernel
# git tree.
#
# The repository is a clone of the driver from QCOM with applied patches for the target.
# Reference:
# https://source.codeaurora.org/quic/la/platform/vendor/qcom-opensource/wlan/qcacld-2.0
#
set -e

BRANCH="lineage-15.1" # LA.UM.6.5.r1-06700-8x96.0
FOLDER="drivers/staging"
MODULE="qcacld-2.0"
REMOTE="https://github.com/GalaticStryder/android_vendor_qcom-opensource_wlan_qcacld-2.0"

if [ $GITHUB_USERNAME ] && [ $GITHUB_ACCESS_TOKEN ]; then
  git_curl="curl -u $GITHUB_USERNAME:$GITHUB_ACCESS_TOKEN";
elif [ ! $GITHUB_ACCESS_TOKEN ]; then
  git_curl="curl -u $GITHUB_USERNAME";
else
  git_curl="curl";
fi;

LOC="git/refs/heads/$BRANCH"
API=$(echo $REMOTE | sed s#github.com#api.github.com/repos#)
URL="$API/$LOC"
if [ -x "$(command -v jq)" ]; then
  $git_curl -s $URL | jq -r '.object.sha' > /tmp/HEAD;
else
  $git_curl -s $URL | python3 -c "import sys, json; print(json.load(sys.stdin)['object']['sha'])" > /tmp/HEAD;
fi;

exit 0;

if [ -f $FOLDER/$MODULE/HEAD ]; then
  if [ "$(cat /tmp/HEAD)" != "$(cat $FOLDER/$MODULE/HEAD)" ]; then
    if [ ! -d /tmp/$MODULE ]; then
      mkdir -p /tmp/$MODULE;
      git clone --depth 1 $REMOTE -b $BRANCH /tmp/$MODULE;
    fi;
    if [ -d /tmp/$MODULE/.git ]; then
      rm -rf /tmp/$MODULE/.git;
    fi;
    if [ -f /tmp/$MODULE/Android.mk ]; then
      rm -f /tmp/$MODULE/Android.mk;
    fi;
    if [ -d /tmp/$MODULE ]; then
      cp -r /tmp/$MODULE/* $FOLDER/$MODULE/;
    fi;
    echo cp /tmp/HEAD $FOLDER/$MODULE/HEAD;
  fi;
fi;

