#!/usr/bin/env bash
set -uo pipefail
# Download step: stream one HPRC dsa.cram URL, subsample 10%, keep the first 10k
# reads, then reset (blank CIGAR) and convert legacy tags to inline MA. The kept
# per-sample artifact is this inline-MA BAM -- the single thing we persist and
# reuse. Only the split reshape + size measurement live in the benchmark.
#
# awk exits at 10k reads, SIGPIPEing the upstream `samtools view -s` (exit 141);
# that is expected, so no `set -e`. Completeness is checked on the raw 10k count.
url=$1
name=$(basename "$url"); samp=${name%.dsa.cram}
mkdir -p test-data/hprc
out=test-data/hprc/${samp}.10k.bam
[ -s "$out" ] && { echo "skip $samp (exists)"; exit 0; }
raw="$out.raw.tmp"

# subsample 10% -> first 10k reads
samtools view -h -s 0.1 "$url" 2>/dev/null \
  | awk 'BEGIN{n=0}/^@/{print;next}{if(n++<10000)print;else exit}' \
  | samtools view -b -o "$raw" - 2>/dev/null
n=$(samtools view -c "$raw" 2>/dev/null || echo 0)
if [ "$n" -ne 10000 ]; then rm -f "$raw"; echo "FAIL $samp (got $n reads)"; exit 1; fi

# reset (blank CIGAR) + convert legacy fiberseq tags -> inline MA
samtools reset -@2 -O bam -o - "$raw" 2>/dev/null | ft convert-tags - "$out.tmp" 2>/dev/null
rm -f "$raw"
mv "$out.tmp" "$out"
echo "done $samp"
