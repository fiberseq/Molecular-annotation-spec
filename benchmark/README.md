# MA tag compression benchmark

Does moving annotation lengths out of the `MA:Z` tag into a separate `AL` array
compress better? This benchmarks the two encodings on real HPRC v2 Fiber-seq data.

- **inline** (current `ft` + spec): `MA:Z:len;nuc.:315-266,582-264,...`
- **split** (proposed): `MA:Z:len;nuc.:315,582,...` + `AL:B:I` uint32 lengths

Results and the full write-up: [`compression/RESULTS.md`](compression/RESULTS.md).

## Layout

```
samples.txt            46 HPRC dsa.cram URLs (committed)
scripts/
  sample_one.sh        download 1 sample: stream, -s 0.1, first 10k reads,
                       reset (blank CIGAR), convert-tags -> inline-MA BAM
  download_all.sh      run sample_one.sh over samples.txt in parallel
  reshape_ma.py        read one inline BAM, write all 24 benchmark outputs
                       (inline/split x full/tag x level{1,6,9} x BAM/CRAM),
                       compressing in-process; print size rows
  bench_one.sh         run reshape for one sample in a temp dir, then delete it
  run_bench.sh         run bench_one over all samples, print the table
test-data/hprc/        the kept inline-MA samples (gitignored)
compression/           RESULTS.md (committed); results.tsv + summary.txt (generated)
```

Only the inline-MA sample BAMs are persisted; every benchmark-derived file is
written to temp space and deleted after its sizes are recorded.

## Run

```bash
pixi install
pixi run download                 # -> test-data/hprc/*.10k.bam  (network heavy)
pixi run bench                    # -> compression/summary.txt + results.tsv
```

### On a cluster (all 46 at once)

`bench` fans out with `xargs -P $JOBS`. Each sample is roughly main-thread bound
(~4 cores) and buffers CRAM slices in RAM, so size the node accordingly.

```bash
JOBS=46 pixi run bench            # all samples concurrently
JOBS=46 RESHAPE_THREADS=2 pixi run bench
```

`results.tsv` is long-format: `sample form scope level container bytes`
(plus `META` rows carrying read/annotation counts).
