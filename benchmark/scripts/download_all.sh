#!/usr/bin/env bash
set -euo pipefail
# Download all samples in parallel (bash, so system xargs -P works; pixi's task
# shell does not implement xargs -P). Network-bound: each sample streams ~10x the
# kept reads (10% subsample -> first 10k). JOBS controls concurrency.
JOBS=${JOBS:-8}
xargs -P "$JOBS" -n1 scripts/sample_one.sh < samples.txt
