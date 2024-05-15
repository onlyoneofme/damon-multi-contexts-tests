#!/bin/bash

function handle_sigint {
	killall -9 masim
	exit 0
}

if [[ "$EUID" != 0 ]]; then
	echo "You must be root!" >/dev/stderr
	exit 1
fi

printf "INFO: current pid: %d\n" "$BASHPID"

PERF=/usr/bin/perf
PERF_DURATION=30 # in seconds
PERF_OUTPUT="masim.data"
PERF_SCRIPT_OUTPUT="masim.perf.script"
PERF_TRACEPOINT="damon:damon_aggregated"

MASIM_DIR=$(pwd)/masim
MASIM="$MASIM_DIR"/masim
MASIM_CONFIGS=("zigzag.cfg")

KDAMONDS_DIR=/sys/kernel/mm/damon/admin/kdamonds

LOG_DIR="$(pwd)"/log

# create log directory
rm -rf  "$LOG_DIR"; mkdir "$LOG_DIR"

# remove all previous data
rm -f "$PERF_OUTPUT" "$PERF_SCRIPT_OUTPUT"

# remove all previous kdamonds
echo 0 > "$KDAMONDS_DIR"/nr_kdamonds

# create 1 kdamond and 1 context
echo 1 > "$KDAMONDS_DIR"/nr_kdamonds
echo 1 > "$KDAMONDS_DIR"/0/contexts/nr_contexts

# kdamond will have as many targets as masim
# configs are going to run
echo "${#MASIM_CONFIGS[@]}" > "$KDAMONDS_DIR"/0/contexts/0/targets/nr_targets

# configure kdamond's operation to monitor
# virtual address space
echo vaddr > "$KDAMONDS_DIR"/0/contexts/0/operations

# update time is 1 second
echo 1000000 > "$KDAMONDS_DIR"/0/contexts/0/monitoring_attrs/intervals/update_us

TARGETS_DIR="$KDAMONDS_DIR"/0/contexts/0/targets

timeout "$PERF_DURATION" "$PERF" record -a -e "$PERF_TRACEPOINT" -o "$PERF_OUTPUT" &

# start masim configs
for ((i = 0; i < "${#MASIM_CONFIGS[@]}"; i++)); do
	cfg_path="$MASIM_DIR"/configs/"${MASIM_CONFIGS[$i]}"

	log_file="$(basename -- $cfg_path)"

	log_file="${log_file%.*}".log
	err_file="${log_file%.*}".err

	# start masim
	pid=$("$MASIM" "$cfg_path" >"$LOG_DIR"/"$log_file" 2>"$LOG_DIR"/"$err_file" & echo $!)

	# create kdamond's target
	echo "$pid" > "$TARGETS_DIR"/"$i"/pid_target
done

# start kdamond
echo on > "$KDAMONDS_DIR"/0/state

# Make sure all masim process will die
# if we're tired of them with Ctr+C
trap handle_sigint SIGINT
trap handle_sigint EXIT

sleep $((PERF_DURATION+10))

# turn off kdamond
echo off > "$KDAMONDS_DIR"/0/state

# create human readable data
eval "$PERF" script --force -i "$PERF_OUTPUT" > "$PERF_SCRIPT_OUTPUT"
