#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

clusters="${clusters:-c0}"
cluster_list="$clusters"

# create k3d clusters
for K3D_CLUSTER_NAME in $cluster_list
do
  k3d cluster delete "${K3D_CLUSTER_NAME}"
done