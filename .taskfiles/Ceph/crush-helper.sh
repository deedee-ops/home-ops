#!/usr/bin/env bash

echo "ceph osd crush add-bucket ephemeral root"
echo "ceph osd crush add-bucket persistent root"

echo "ceph osd crush rule create-replicated replicated_mgr ephemeral host"
echo "ceph osd pool set .mgr crush_rule replicated_mgr"

jq -r '.cluster.ceph.storage_nodes[] | . as $node | .devices[] | ("ceph osd crush add-bucket " + $node.name + "-" + .config.crushRoot + " host")' < "$1"
jq -r '.cluster.ceph.storage_nodes[] | . as $node | .devices[] | ("ceph osd crush move " + $node.name + "-" + .config.crushRoot + " root=" + .config.crushRoot)' < "$1"

echo "ceph osd crush rule create-simple ephemeral ephemeral host firstn"
echo "ceph osd crush rule create-simple persistent persistent host firstn"

for osd in $(ceph osd ls); do ceph osd metadata "${osd}" | jq -r '(.bluestore_bdev_dev_node + ":" + .hostname + " " + (.id|tostring) + " " + ((.bluestore_bdev_size|tonumber) / 1099511627776 | tostring))'; done > /tmp/ceph-osd

jq -r '.cluster.ceph.storage_nodes[] | . as $node | .devices[] | ("ceph osd crush set osd." + .name + ":" + $node.name + " WEIGHT root=" + .config.crushRoot + " host=" + $node.name + "-" + .config.crushRoot)' < "$1" | sed -f <(awk '{ print "s@" $1 " WEIGHT@" $2 " " $3 "@g"}' /tmp/ceph-osd)
