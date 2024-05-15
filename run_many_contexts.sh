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
PERF_SCRIPT_OUTPUT="masim.script"
PERF_TRACEPOINT="damon:damon_aggregated"

MASIM_DIR=$(pwd)/masim
MASIM="$MASIM_DIR"/masim
MASIM_CONFIGS=("demo.cfg" "stairs.cfg" "zigzag.cfg")

KDAMONDS_DIR=/sys/kernel/mm/damon/admin/kdamonds

LOG_DIR="$(pwd)"/log

# create log directory
rm -rf  "$LOG_DIR"; mkdir "$LOG_DIR"

# remove all previous data
rm -f "$PERF_OUTPUT" "$PERF_SCRIPT_OUTPUT"

# remove all previous kdamonds
echo 0 > "$KDAMONDS_DIR"/nr_kdamonds

# create 1 kdamond
echo 1 > "$KDAMONDS_DIR"/nr_kdamonds

# kdamond will have as many contexts as masim
# contexts are going to run
echo "${#MASIM_CONFIGS[@]}" > "$KDAMONDS_DIR"/0/contexts/nr_contexts

CONTEXTS_DIR="$KDAMONDS_DIR"/0/contexts

# prepare contexts
for ((i = 0; i < "${#MASIM_CONFIGS[@]}"; i++)); do
	ctx_dir="$CONTEXTS_DIR"/"$i"

	# configure kdamond's operation to monitor
	# processes' virtual address space
	echo vaddr > "$ctx_dir"/operations

	# update time is 1 second
	echo 1000000 > "$ctx_dir"/monitoring_attrs/intervals/update_us

	# reserve one target
	echo 1 > "$ctx_dir"/targets/nr_targets
done

# start masim configs
for ((i = 0; i < "${#MASIM_CONFIGS[@]}"; i++)); do
	cfg_path="$MASIM_DIR"/configs/"${MASIM_CONFIGS[$i]}"

	log_file="$(basename -- $cfg_path)"

	log_file="${log_file%.*}".log
	err_file="${log_file%.*}".err

	# start masim
	pid=$("$MASIM" "$cfg_path" >"$LOG_DIR"/"$log_file" 2>"$LOG_DIR"/"$err_file" & echo $!)

	# create kdamond's target
	echo "$pid" > "$CONTEXTS_DIR"/"$i"/targets/0/pid_target
done

# start kdamond
echo on > "$KDAMONDS_DIR"/0/state

# Make sure all masim process will die
# if we're tired of them with Ctr+C
trap handle_sigint SIGINT
trap handle_sigint EXIT

timeout "$PERF_DURATION" "$PERF" record -a -e "$PERF_TRACEPOINT" -o "$PERF_OUTPUT"

# create human readable data
eval "$PERF" script --force -i "$PERF_OUTPUT" > "$PERF_SCRIPT_OUTPUT"
