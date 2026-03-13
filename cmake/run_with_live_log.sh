#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <log-file> <command> [args...]" >&2
  exit 2
fi

log_file=$1
shift

mkdir -p "$(dirname "$log_file")"

"$@" 2>&1 | tee "$log_file"
cmd_status=${PIPESTATUS[0]}
exit "$cmd_status"
