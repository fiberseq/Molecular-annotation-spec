# MA tag compression: inline vs split lengths

Does moving annotation lengths out of `MA:Z` into a separate `AL` array compress better?

- **inline** (spec): `MA:Z:len;nuc.:315-266,582-264,...`
- **split**: `MA:Z:len;nuc.:315,582,...` + `AL:B:I` uint32 lengths

46 HPRC v2 Fiber-seq crams (`../samples.txt`), 10k-read subsample each, reset (CIGAR
blanked) and converted to inline MA. `reshape_ma.py` reads each once and writes both
forms at every setting, pysam compressing in-process so it is identical by
construction. **full** = whole record (seq + m6A kinetics); **tag** = only MA/AL/AQ/AN
(isolates the representation). **46 samples · 452,199 reads · 73,422,314 annotations.**

## Results (total bytes; `agree` = samples matching the row's direction)

| level | scope | cont |          inline |           split | split−in |  agree |
|-------|-------|------|----------------:|----------------:|---------:|-------:|
| fast  | full  | bam  |   8,998,456,782 |   9,024,176,501 |  +0.29%  | 46/46  |
| fast  | full  | cram |   6,841,336,024 |   6,843,414,267 |  +0.03%  | 36/46  |
| fast  | tag   | bam  |     328,527,266 |     350,614,816 |  +6.72%  | 46/46  |
| fast  | tag   | cram |     279,061,960 |     274,297,298 |  −1.71%  | 46/46  |
| def   | full  | bam  |   8,073,228,090 |   8,095,765,102 |  +0.28%  | 46/46  |
| def   | full  | cram |   6,447,248,370 |   6,428,092,060 |  −0.30%  | 44/46  |
| def   | tag   | bam  |     309,425,800 |     340,254,627 |  +9.96%  | 46/46  |
| def   | tag   | cram |     279,002,967 |     253,606,283 |  −9.10%  | 46/46  |
| arch  | full  | bam  |   7,627,313,335 |   7,634,670,495 |  +0.10%  | 43/46  |
| arch  | full  | cram |   6,339,317,375 |   6,313,959,152 |  −0.40%  | 45/46  |
| arch  | tag   | bam  |     295,163,012 |     314,145,700 |  +6.43%  | 46/46  |
| arch  | tag   | cram |     278,971,833 |     247,210,576 | −11.39%  | 46/46  |

**Verdict:** split helps only under CRAM, more so with effort (tag CRAM −1.7% → −9.1% →
−11.4% over fast/def/arch, 46/46). Under BAM it is always worse (tag +6–10%, 46/46) — a
uint32 array only beats compact ASCII digits with a column-aware codec. Whole-file
impact is ≤0.4% either way (seq + m6A kinetics dominate). Net: worth it for archival
CRAM, not for BAM.

## Reproduce

```bash
pixi run download && JOBS=46 pixi run bench   # -> compression/summary.txt, results.tsv
```
