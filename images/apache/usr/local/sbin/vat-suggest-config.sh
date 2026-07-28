#!/bin/bash

apacheName="apache2"
reserved=20
maxRequests=500
fpmJson=$(ps -C php-fpm -o rss= --no-headers | awk '{sum+=$1; count++} END {if (count > 0) printf "{\"total\": %.2f, \"processes\": %d, \"average\": %.2f}\n", sum/1024, count, (sum/1024)/count; else print "{\"error\": \"no php-fpm processes found\"}"}')
apacheJson=$(ps -C "apache2" -o rss= --no-headers | awk '{sum+=$1; count++} END {if (count > 0) printf "{\"total\": %.2f, \"processes\": %d, \"average\": %.2f}\n", sum/1024, count, (sum/1024)/count; else print "{\"error\": \"no apache2 or httpd processes found\"}"}')
apacheUnique=$(top -b -n 1 | grep -E "apache2|httpd" | awk '{rss+=$6; shr+=$7; count++} END {if (count > 0) {unique=(rss-shr); printf "{\"unique_total\": %.2f, \"processes\": %d}\n", unique/1024, count} else print "{\"error\": \"no apache processes found\"}"}')
freeMemory=$(free -m |head -n 2 |tail -n 1 |awk '{free=($4 + $6); print free}')
apacheAvg=$(jq '.average' <<< "$apacheJson")
apacheUnq=$(jq '.unique' <<< "$apacheUnique")
apacheProc=$(jq '.processes' <<< "$apacheJson")
apacheAvg=$(awk "BEGIN {print ($apacheAvg + $apacheUnq) / 2}")
apacheEst=$(awk "BEGIN {print $apacheAvg * $apacheProc}")
fpmAvg=$(jq '.average' <<< "$fpmJson")
fpmProc=$(jq '.processes' <<< "$fpmJson")
fpmTotal=$(jq '.total' <<< "$fpmJson")
freeNoApache=$(awk "BEGIN {print $freeMemory + $apacheEst }")
freeNoPhp=$(awk "BEGIN {print $freeMemory + $fpmTotal }")
freeNoWeb=$(awk "BEGIN {print $freeMemory + $fpmTotal + $apacheEst }")
freeSafe=$(awk "BEGIN {print $freeNoWeb * ((100-$reserved)/100) }")
swapMem=$(free -m |head -n 4 |tail -n 1 |awk '{swap=($2); print swap}')
cpuCores=$(cat /proc/cpuinfo | awk '/^processor/{print $3}' | wc -l);
totalMem=$(grep MemTotal /proc/meminfo | awk '{print $2}' | awk '{ byte = int($1 /1024); print byte "" }');
maxReqWorkers=$(echo | awk "{ print ${freeSafe} / ${apacheAvg} }")
serverLimitThreads=$(echo | awk "{ print ($maxReqWorkers + 1) }")
serverLimitThreads=$(printf '%.*f\n' 0 "$serverLimitThreads");
serverLimitWorkers=$(echo | awk "{ print ($serverLimitThreads * 2) }")
pmMaxChildren=$(awk "BEGIN {print $freeSafe / $fpmAvg }")
pmMinSpareServers=$(awk "BEGIN {print int($pmMaxChildren * .25) }")
pmMaxSpareServers=$(awk "BEGIN {print int($pmMaxChildren * .75) }")
pmMaxChildren=$(awk "BEGIN { print int($pmMaxChildren) }")
pmStartServers=$pmMinSpareServers
swapValid="true"
[ "$totalMem" -gt "$swapMem" ] && swapValid=false
json=$(cat <<EOF
{
  "processes": {
    "php": "$fpmProc",
    "apache": "$apacheProc"
  },
  "average":{
    "php": "$fpmAvg",
    "apache": "$apacheAvg"
  },
  "usage":{
    "php": "$fpmTotal",
    "apache": "$apacheEst"
  },
  "free": {
    "php": "$freeNoPhp",
    "apache": "$freeNoApache",
    "without": "$freeNoWeb",
    "safe": "$freeSafe",
    "total": "$freeMemory"
  },
  "total": "$totalMem",
  "swap": "$swapMem",
  "swap_valid": $swapValid,
  "cpu_cores": "$cpuCores",
  "apache": {
    "start_servers": "$cpuCores",
    "min_spare_threads": "25",
    "max_spare_servers": "75",
    "thread_limit": "$serverLimitThreads",
    "threads_per_child": "$serverLimitThreads",
    "max_request_workers": "$serverLimitWorkers",
    "max_connections_per_child": "$maxRequests"
  },
  "php_fpm": {
    "pm": "dynamic",
    "max_children": "$pmMaxChildren",
    "start_servers": "$pmStartServers",
    "min_spare_servers": "$pmMinSpareServers",
    "max_spare_servers": "$pmMaxSpareServers"
  }
}
EOF
)

jq <<< "$json"