#!/usr/bin/env bash
set -euo pipefail
# Benchmark: for each inline-MA sample, reshape_ma.py reads it once and writes
# every output (inline/split x full/tag x level{1,6,9} x BAM/CRAM), compressing
# in-process, and prints size rows. Aggregate into a table.
#
# Parallelism knobs (set on the cluster to run many/all samples at once):
#   JOBS             samples processed concurrently        (default 8)
#   RESHAPE_THREADS  htslib threads per pysam reader/writer (default 2)
# Each sample is ~main-thread bound (~4 cores) and buffers CRAM slices in RAM, so
# size a node with enough cores/RAM before cranking JOBS. To run all 46 at once:
#   JOBS=46 pixi run bench
JOBS=${JOBS:-8}
export RESHAPE_THREADS=${RESHAPE_THREADS:-2}

mkdir -p compression
ls test-data/hprc/*.10k.bam | xargs -P "$JOBS" -n1 scripts/bench_one.sh \
  | sort > compression/results.tsv

awk -F'\t' '
$2=="META" && $3=="reads" { reads+=$6; next }
$2=="META" && $3=="annos" { annos+=$6; next }
{ g=$3"|"$5"|"$4; tot[g,$2]+=$6; val[$1,g,$2]=$6; seen[$1]=1 }
END{
  N=0; for(s in seen) N++
  printf "MA inline-vs-split compression across levels\n"
  printf "%d samples, %d reads, %d annotations\n\n", N, reads, annos
  printf "| %-5s | %-5s | %-4s | %15s | %15s | %8s | %6s |\n","level","scope","cont","inline","split","split-in","agree"
  printf "|-------|-------|------|-----------------|-----------------|----------|--------|\n"
  ns=split("full tag",SC," "); nc=split("bam cram",CO," "); nl=split("1 6 9",LV," ")
  for(k=1;k<=nl;k++) for(i=1;i<=ns;i++) for(j=1;j<=nc;j++){   # sort: level, scope, cont
    g=SC[i]"|"CO[j]"|"LV[k]; a=tot[g,"inline"]; b=tot[g,"split"]
    if(a==0) continue
    # agree = samples whose per-sample sign matches the aggregate direction
    adir=(b>=a)?1:-1; agree=0
    for(s in seen){ d=val[s,g,"split"]-val[s,g,"inline"]
      if(d>0 && adir>0) agree++; else if(d<0 && adir<0) agree++ }
    lab = (LV[k]==1?"1fast":(LV[k]==6?"6def":"9arch"))
    printf "| %-5s | %-5s | %-4s | %15d | %15d | %+7.2f%% | %2d/%d |\n", lab,SC[i],CO[j],a,b,(b-a)/a*100,agree,N
  }
}' compression/results.tsv | tee compression/summary.txt
