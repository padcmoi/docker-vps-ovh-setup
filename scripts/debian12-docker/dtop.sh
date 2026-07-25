#!/usr/bin/env bash
# dtop - live docker stats, htop-style bars. Usage: dtop.sh [interval_seconds]

INTERVAL="${1:-2}"
BARWIDTH=20

bar() {
  local pct=${1%.*}
  [ -z "$pct" ] && pct=0
  (( pct > 100 )) && pct=100
  (( pct < 0 )) && pct=0
  local filled=$(( pct * BARWIDTH / 100 ))
  local empty=$(( BARWIDTH - filled ))
  local color="\e[32m"
  (( pct >= 50 )) && color="\e[33m"
  (( pct >= 80 )) && color="\e[31m"
  printf "${color}"
  [ "$filled" -gt 0 ] && printf '%0.s#' $(seq 1 "$filled")
  printf "\e[0m"
  [ "$empty" -gt 0 ] && printf '%0.s.' $(seq 1 "$empty")
}

render() {
  local load mem_line count data sorted
  load=$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)
  mem_line=$(free -h | awk '/^Mem:/ {print $3" used / "$2" total (avail "$7")"}')
  count=$(docker ps -q | wc -l)
  data=$(docker stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemPerc}}|{{.MemUsage}}|{{.PIDs}}' 2>/dev/null)
  sorted=$(echo "$data" | sort -t'|' -k1,1)

  echo -e "\e[1mdtop\e[0m - $(date '+%Y-%m-%d %H:%M:%S')   load avg: ${load}   host mem: ${mem_line}   containers: ${count}   (refresh ${INTERVAL}s, Ctrl+C pour quitter)"
  echo
  printf "%-32s %7s %-22s %7s %-22s %-10s %6s\n" "CONTAINER" "CPU%" "" "MEM%" "" "MEM USAGE" "PIDS"

  while IFS='|' read -r name cpu mem memusage pids; do
    [ -z "$name" ] && continue
    cpuval=${cpu%\%}
    memval=${mem%\%}
    printf "%-32s %7s " "$name" "$cpu"
    bar "$cpuval"
    printf " %7s " "$mem"
    bar "$memval"
    printf " %-22s %6s\n" "$memusage" "$pids"
  done <<< "$sorted"
}

cleanup() {
  tput cnorm 2>/dev/null
  tput rmcup 2>/dev/null
  exit 0
}
trap cleanup INT TERM

tput smcup 2>/dev/null
tput civis 2>/dev/null

while true; do
  frame=$(render)
  tput cup 0 0
  printf '%s\n' "$frame"
  tput ed
  sleep "$INTERVAL"
done
