#!/bin/bash

#############################################
#
# Call this script as
# ./pcap.sh <node> [<filters>]
# examples: ./pcap.sh r1
#           ./pcap.sh r2 ip proto 89
#
# Set these values according to your environment:
#
# USER         – SSH username on the netlab host
# NETLAB_HOST  – IP or hostname of the netlab host
# NETLAB_VENV  – path to Python virtual environment that contains netlab
#
#############################################

USER=
NETLAB_HOST=
NETLAB_VENV=

LIBVIRT_ENV="export LIBVIRT_DEFAULT_URI=qemu:///system"

[[ "$#" -eq 0 ]] && { echo "usage: $0 <node> [<filters>]"; exit 1; }

node=$1
filter="${@:2}"

report=$(ssh $USER@$NETLAB_HOST "source $NETLAB_VENV && \
  netlab report -i default --node $node addressing" 2>&1)

if [[ "$?" -ne 0 || "$report" == *FatalError* ]]; then
  echo "$report"
  exit 1
fi

declare -A interfaces_dict

echo "$report" | awk 'NR==4'
index=1
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  echo "$line"
  interfaces_dict[$index]=$(echo "$line" | awk '{ print $2 }')
  ((index++))
done < <(echo "$report" | tail -n +5 | awk 'NF { $1=$1; print }' | nl -w1 -s ') ')

read -p "Enter interface number: " iface_key
if [[ -z "${interfaces_dict[$iface_key]}" ]]; then
  echo "Invalid key: $iface_key"
  exit 1
fi

iface="${interfaces_dict[$iface_key]}"

ssh $USER@$NETLAB_HOST "$LIBVIRT_ENV; \
  source $NETLAB_VENV && netlab capture -i default $node $iface -U -w - $filter" 2>/dev/null | \
  wireshark -o "gui.window_title:$node $iface" -k -i - > /dev/null 2>&1 &
