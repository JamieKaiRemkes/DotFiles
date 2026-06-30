#!/bin/bash
# Parse deployment.yaml files for resource info
BASE="/Users/kai/Code/Wartsila/expert-insight-cluster-state/expert-insight-tst"
TMPFILE="/tmp/deploy_resources.txt"
> "$TMPFILE"

for dir in "$BASE"/*/; do
    app=$(basename "$dir")
    file="$dir/deployment.yaml"
    [ -f "$file" ] || continue

    replicas=$(grep -m1 'replicas:' "$file" | awk '{print $2}')
    [ -z "$replicas" ] && replicas=1

    cpu_req=$(grep -A20 'requests:' "$file" | grep -m1 'cpu:' | awk '{print $2}' | tr -d '"')
    cpu_lim=$(grep -A20 'limits:' "$file" | grep -m1 'cpu:' | awk '{print $2}' | tr -d '"')
    mem_req=$(grep -A20 'requests:' "$file" | grep -m1 'memory:' | awk '{print $2}' | tr -d '"')
    mem_lim=$(grep -A20 'limits:' "$file" | grep -m1 'memory:' | awk '{print $2}' | tr -d '"')

    # Convert CPU to millicores
    cpu_to_milli() {
        local v="$1"
        if [ -z "$v" ]; then echo 0; return; fi
        if [[ "$v" == *m ]]; then echo "${v%m}"; return; fi
        echo "$v" | awk '{printf "%.0f", $1 * 1000}'
    }

    # Convert memory to MiB
    mem_to_mib() {
        local v="$1"
        if [ -z "$v" ]; then echo 0; return; fi
        if [[ "$v" == *Gi ]]; then echo "${v%Gi}" | awk '{printf "%.0f", $1 * 1024}'; return; fi
        if [[ "$v" == *Mi ]]; then echo "${v%Mi}"; return; fi
        if [[ "$v" == *Ki ]]; then echo "${v%Ki}" | awk '{printf "%.0f", $1 / 1024}'; return; fi
        if [[ "$v" == *G ]]; then echo "${v%G}" | awk '{printf "%.0f", $1 * 1024}'; return; fi
        if [[ "$v" == *M ]]; then echo "${v%M}"; return; fi
        echo "$v"
    }

    cr=$(cpu_to_milli "$cpu_req")
    cl=$(cpu_to_milli "$cpu_lim")
    mr=$(mem_to_mib "$mem_req")
    ml=$(mem_to_mib "$mem_lim")

    # Total memory = replicas * mem_limit (or mem_request if no limit)
    eff_mem=$ml
    [ "$eff_mem" -eq 0 ] 2>/dev/null && eff_mem=$mr
    total_mem=$((replicas * eff_mem))

    echo "$total_mem|$app|$replicas|$cr|$cl|$mr|$ml" >> "$TMPFILE"
done

# Sort by total memory descending, print table
printf "%-45s %3s %8s %8s %9s %9s %10s\n" "Application" "Rep" "CPU Req" "CPU Lim" "Mem Req" "Mem Lim" "Tot Mem"
printf '%0.s-' {1..100}; echo

fmt_cpu() { [ "$1" -eq 0 ] 2>/dev/null && echo "-" || echo "${1}m"; }
fmt_mem() { [ "$1" -eq 0 ] 2>/dev/null && echo "-" || echo "${1}Mi"; }

sort -t'|' -k1 -rn "$TMPFILE" | while IFS='|' read -r tm app rep cr cl mr ml; do
    printf "%-45s %3s %8s %8s %9s %9s %10s\n" "$app" "$rep" "$(fmt_cpu $cr)" "$(fmt_cpu $cl)" "$(fmt_mem $mr)" "$(fmt_mem $ml)" "$(fmt_mem $tm)"
done

printf '%0.s-' {1..100}; echo

# Totals
awk -F'|' '{gcr+=$4*$3; gcl+=$5*$3; gmr+=$6*$3; gml+=$1} END {
    fc = gcr > 0 ? gcr"m" : "-"
    fl = gcl > 0 ? gcl"m" : "-"
    fr = gmr > 0 ? int(gmr)"Mi" : "-"
    fml = gml > 0 ? int(gml)"Mi" : "-"
    printf "%-45s %3s %8s %8s %9s %9s %10s\n", "TOTAL (all replicas)", "", fc, fl, fr, fml, fml
}' "$TMPFILE"

rm -f "$TMPFILE"

