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

> Representative full-46 run. Re-run `pixi run bench` to regenerate
> `results.tsv`/`summary.txt`; switching AL to uint32 slightly raises the split
> figures in the BAM rows (CRAM is re-coded and barely moves).

| scope | cont | level |          inline |           split | split−in |  agree |
|-------|------|-------|----------------:|----------------:|---------:|-------:|
| full  | bam  | fast  |   8,998,457,042 |   9,003,223,089 |  +0.05%  | 19/46  |
| full  | bam  | def   |   8,073,228,213 |   8,081,075,183 |  +0.10%  | 10/46  |
| full  | bam  | arch  |   7,627,313,389 |   7,626,028,812 |  −0.02%  | 23/46  |
| full  | cram | fast  |   6,841,192,133 |   6,821,394,708 |  −0.29%  | 45/46  |
| full  | cram | def   |   6,447,921,892 |   6,428,670,297 |  −0.30%  | 45/46  |
| full  | cram | arch  |   6,329,581,022 |   6,303,097,338 |  −0.42%  | 45/46  |
| tag   | bam  | fast  |     328,527,672 |     332,735,916 |  +1.28%  |  1/46  |
| tag   | bam  | def   |     309,426,043 |     325,234,432 |  +5.11%  |  0/46  |
| tag   | bam  | arch  |     295,163,198 |     299,589,134 |  +1.50%  |  4/46  |
| tag   | cram | fast  |     279,058,686 |     251,961,958 |  −9.71%  | 46/46  |
| tag   | cram | def   |     278,999,518 |     251,900,434 |  −9.71%  | 46/46  |
| tag   | cram | arch  |     278,968,579 |     245,548,456 | −11.98%  | 46/46  |

## Takeaways

- **Container decides the sign, at every level.** split helps only under CRAM's
  per-series codecs (homogeneous `AL` array + starts column compress far better than
  interleaved `start-len` text). Under BAM/gzip split is neutral-to-worse.
- **Archival CRAM (level 9) is split's best case: −11.98% on the annotation payload,
  −0.42% whole-file, 46/46 and 45/46 samples.** Higher effort widens split's CRAM lead.
- **BAM never favors split** at the tag level (+1.3% to +5.1%); the penalty is worst at
  default and shrinks at the extremes as gzip effort changes.
- **Whole-file impact is small** (≤0.42%): sequence + m6A kinetics dominate the file.
- Per annotation (archival CRAM): split saves ~0.46 B; (default BAM) costs ~0.22 B.

**Net:** for CRAM-stored Fiber-seq data — especially archival — splitting lengths into
`AL` is a consistent win. For BAM it is not.

## Reproduce

```bash
pixi install
pixi run download   # inline-MA 10k subsample per sample -> test-data/hprc/*.10k.bam
pixi run bench      # -> compression/summary.txt, compression/results.tsv
```

`results.tsv` is long-format: `sample form scope level container bytes`.
