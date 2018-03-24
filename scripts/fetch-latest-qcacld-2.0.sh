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
set -e;

# The branch should match what the Kernel expects as per QCOM tags.
BRANCH="lineage-15.1" # LA.UM.6.5.r1-06700-8x96.0
# The folder is the Kernel path, nothing special.
FOLDER="drivers/staging/qcacld-2.0"
# The remote contains a copy of the original repository with a few patches.
REMOTE="https://github.com/GalaticStryder/android_vendor_qcom-opensource_wlan_qcacld-2.0"

# The three options for curling api.github.com:
if [ $GITHUB_USERNAME ] && [ $GITHUB_ACCESS_TOKEN ]; then
  # If username and access point are available in environment.
  git_curl="curl -u $GITHUB_USERNAME:$GITHUB_ACCESS_TOKEN";
elif [ ! $GITHUB_ACCESS_TOKEN ]; then
  # If only username is available in environment.
  git_curl="curl -u $GITHUB_USERNAME";
else
  # If none of those are available, watchout for max rate limit of 60!
  git_curl="curl";
fi;

# Curl api.github.com to check the current remote HEAD.
LOC="git/refs/heads/$BRANCH"
API=$(echo $REMOTE | sed s#github.com#api.github.com/repos#)
URL="$API/$LOC"
if [ -x "$(command -v jq)" ]; then
  # If 'jq' parser is available, use it.
  $git_curl -s $URL | jq -r '.object.sha' > /tmp/HEAD;
else
  # Otherwise use python3...
  $git_curl -s $URL | python3 -c "import sys, json; print(json.load(sys.stdin)['object']['sha'])" > /tmp/HEAD;
fi;

# Compare the current remote HEAD to the local one to decide what to do next.
HEAD=$(cat /tmp/HEAD)
if [ -f $FOLDER/HEAD ]; then
  if [ "$HEAD" = "$(cat $FOLDER/HEAD)" ]; then
    # If the HEAD on the remote is the same as the local one: skip.
    force_clone=false;
  else
    # If the HEAD on the remote has changed: force clone it.
    force_clone=true;
  fi;
else
  # If there's no HEAD, force clone it as well.
  force_clone=true;
fi;

# The version file is generated in the end of the script, it will not exist in a clean state.
if [ -f $FOLDER/Version ]; then
  if [ "$BRANCH" != "$(cat $FOLDER/Version)" ]; then
    # If the version of the driver changes (e.g. changing the base Kernel branch)
    # we ought to force clone the driver to avoid using an incorrect version.
    force_clone=true;
  fi;
fi;

if [ "$force_clone" = "false" ]; then
  exit 0
fi;

# If the conditions demands to force clone, just do it...
if [ "$force_clone" = "true" ]; then
  # Recreate /tmp and final folders before cloning...
  if [ -d $FOLDER ]; then
    rm -rf $FOLDER;
  fi;
  mkdir -p $FOLDER;
  if [ -d /tmp/$FOLDER ]; then
    rm -rf /tmp/${FOLDER};
  fi;
  mkdir -p /tmp/${FOLDER};
  # Use shallow clone with small history count, it's a mirror only.
  git clone --depth 1 $REMOTE -b $BRANCH /tmp/${FOLDER};
fi;

# Remove git traces as it's not needed.
if [ -d /tmp/$FOLDER/.git ]; then
  rm -rf /tmp/${FOLDER}/.git;
fi;
# Remove the Android.mk file as it's not wanted.
if [ -f /tmp/${FOLDER}/Android.mk ]; then
  rm -f /tmp/${FOLDER}/Android.mk;
fi;
# Finally, copy everything left to the Kernel tree.
cp -r /tmp/${FOLDER}/* ${FOLDER}/;
# Write out the branch for checking in the next episode.
echo "$BRANCH" > ${FOLDER}/Version;
echo "$HEAD" > ${FOLDER}/HEAD;
