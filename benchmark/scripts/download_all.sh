#!/usr/bin/env bash
set -euo pipefail
# Download all samples in parallel (bash, so system xargs -P works; pixi's task
# shell does not implement xargs -P).
xargs -P 8 -n1 scripts/sample_one.sh < samples.txt
