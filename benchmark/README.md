# Benchmarks

## MA tag compression benchmark

Does moving annotation lengths out of the `MA:Z` tag into a separate `AL` array
compress better? This benchmarks the two encodings on real HPRC v2 Fiber-seq data.

- **inline** (current `ft` + spec): `MA:Z:len;nuc.:315-266,582-264,...`
- **split** (proposed): `MA:Z:len;nuc.:315,582,...` + `AL:B:I` uint32 lengths

Results and the full write-up: [`compression/RESULTS.md`](compression/RESULTS.md).

### Run

```bash
pixi install
pixi run download                 # -> test-data/hprc/*.10k.bam  (network heavy)
pixi run bench                    # -> compression/summary.txt + results.tsv
```

