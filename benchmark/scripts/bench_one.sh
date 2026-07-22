#!/usr/bin/env bash
set -uo pipefail
# Benchmark one inline-MA sample. reshape_ma.py reads it once and writes all 24
# benchmark outputs (inline/split x full/tag x level{1,6,9} x BAM/CRAM), doing
# the compression itself, and prints the size rows. We just give it a temp dir
# and delete it afterwards.
# Cols: sample form(inline|split) scope(full|tag) level container bytes  (+ META)
inline=$1
samp=$(basename "$inline" .10k.bam)
t=$(mktemp -d "${TMPDIR:-/tmp}/ma_${samp}.XXXXXX")
trap 'rm -rf "$t"' EXIT

RESHAPE_THREADS=${RESHAPE_THREADS:-1}
python scripts/reshape_ma.py "$inline" "$t" "$samp" "$RESHAPE_THREADS"
