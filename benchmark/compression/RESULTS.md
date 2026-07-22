# MA tag compression: inline vs split lengths

**Question:** does moving annotation lengths out of the `MA:Z` tag into a separate
`AL` array compress better?

- **inline** (current `ft` + README spec): `MA:Z:len;nuc.:315-266,582-264,...`
- **split** (proposed): `MA:Z:len;nuc.:315,582,...` + `AL:B:I` uint32 lengths

## Method

46 HPRC v2 Fiber-seq donor-specific-assembly CRAMs (PacBio + ONT), from
`s3://stergachis/public/HPRCv2/FIRE-bams/` (see `../samples.txt`). `pixi run download`
keeps a 10k-read 10% subsample per sample, reset (CIGAR blanked) and converted to
inline MA. `pixi run bench` then, per sample, reads that inline BAM once and writes
**both** forms at every setting from a single pass (`reshape_ma.py`), pysam doing the
compression in-process (`format_options=["level=N"]`) so it is identical by
construction. Round-trip split→inline verified.

- **full** = whole record (seq + m6A kinetics, CIGAR blanked).
- **tag**  = only MA/AL/AQ/AN (seq/qual/kinetics stripped) — isolates the representation.
- levels: **1** (fast), **6** (default), **9** (archival).

**46 samples · 452,199 reads · 73,422,314 annotations.**

## Results (total bytes over all 46; `agree` = samples where split is smaller)

| level | scope | cont |          inline |           split | split−in |  agree |
|-------|-------|------|----------------:|----------------:|---------:|-------:|
| fast  | full  | bam  |   8,998,456,782 |   9,024,176,501 |  +0.29%  |  0/46  |
| fast  | full  | cram |   6,841,336,024 |   6,843,414,267 |  +0.03%  | 10/46  |
| fast  | tag   | bam  |     328,527,266 |     350,614,816 |  +6.72%  |  0/46  |
| fast  | tag   | cram |     279,061,960 |     274,297,298 |  −1.71%  | 46/46  |
| def   | full  | bam  |   8,073,228,090 |   8,095,765,102 |  +0.28%  |  0/46  |
| def   | full  | cram |   6,447,248,370 |   6,428,092,060 |  −0.30%  | 44/46  |
| def   | tag   | bam  |     309,425,800 |     340,254,627 |  +9.96%  |  0/46  |
| def   | tag   | cram |     279,002,967 |     253,606,283 |  −9.10%  | 46/46  |
| arch  | full  | bam  |   7,627,313,335 |   7,634,670,495 |  +0.10%  |  3/46  |
| arch  | full  | cram |   6,339,317,375 |   6,313,959,152 |  −0.40%  | 45/46  |
| arch  | tag   | bam  |     295,163,012 |     314,145,700 |  +6.43%  |  0/46  |
| arch  | tag   | cram |     278,971,833 |     247,210,576 | −11.39%  | 46/46  |

## Takeaways

- **Container decides the sign, unanimously.** Every BAM tag row is 0/46 (split
  bigger); every CRAM tag row is 46/46 (split smaller). split wins only under CRAM's
  per-series codecs, which pack the homogeneous `AL` integer array and the starts
  column far better than interleaved `start-len` text.
- **Archival CRAM (level 9) is split's best case: −11.39% on the annotation payload,
  −0.40% whole-file (46/46 and 45/46 samples).** More compression effort widens the
  CRAM lead (tag CRAM −1.71% fast → −9.10% default → −11.39% archival).
- **BAM never favors split**, and the uint32 `AL` makes it clearly worse: +6.4% to
  +10.0% on the tag payload (0/46), worst at the default level.
- **Whole-file impact stays small** (≤0.40%): sequence + m6A kinetics dominate the file
  regardless of MA layout.
- Per annotation: split **saves ~0.43 B** in archival CRAM; **costs ~0.42 B** in default BAM.

**Net:** for CRAM-stored Fiber-seq data — especially archival — splitting lengths into
`AL` is a consistent win. For BAM it is not.

## Reproduce

```bash
pixi install
pixi run download   # inline-MA 10k subsample per sample -> test-data/hprc/*.10k.bam
JOBS=46 pixi run bench   # -> compression/summary.txt, compression/results.tsv
```

`results.tsv` is long-format: `sample form scope level container bytes` (plus `META`
rows carrying read/annotation counts).
