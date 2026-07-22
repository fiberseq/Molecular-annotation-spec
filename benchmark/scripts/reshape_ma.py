#!/usr/bin/env python3
"""Read an inline-MA BAM once and write every benchmark output in a single pass:
inline vs split, full vs tags-only, each as BAM and CRAM at compression levels
{1,6,9} -- 24 files. pysam does the compression itself (format_options=level=N),
so there is no separate samtools re-encode step. Emits one TSV size row per file:

    sample  form(inline|split)  scope(full|tag)  level  container  bytes

plus two META rows carrying read/annotation counts. bench_one.sh just supplies a
temp dir and deletes it afterwards.

  inline: MA:Z:len;nuc.:315-266,...            (lengths inline)
  split : MA:Z:len;nuc.:315,... + AL:B:I ...   (lengths in a uint32 array)
"""
import os
import sys
from array import array

import pysam
from tqdm import tqdm

LEVELS = (1, 6, 9)
CONTAINERS = (("bam", "wb"), ("cram", "wc"))


def al_array(lengths):
    """AL is always uint32 (BAM 'I'). Lengths are positive and < read length."""
    return array("I", lengths)


def split_ma(ma):
    """inline MA -> (starts_only_ma, [lengths]); lengths follow MA left-to-right."""
    parts = ma.split(";")
    sections, lengths = [], []
    for sec in parts[1:]:
        if not sec:
            continue
        header, coords = sec.split(":", 1)
        starts = []
        for tok in coords.split(","):
            s, l = tok.split("-")  # start-length; starts 1-based positive, no other '-'
            starts.append(s)
            lengths.append(int(l))
        sections.append(f"{header}:{','.join(starts)}")
    return ";".join([parts[0]] + sections), lengths


def main(inline, outdir, sample, threads=1):
    src = pysam.AlignmentFile(inline, "rb", check_sq=False, threads=threads)
    hdr = src.header

    # 24 writers: (form, scope) x level x container, each at its own level
    writers, paths = {}, {}
    for form in ("inline", "split"):
        for scope in ("full", "tag"):
            for lvl in LEVELS:
                for cname, mode in CONTAINERS:
                    p = f"{outdir}/{form}.{scope}.L{lvl}.{cname}"
                    writers[form, scope, lvl, cname] = pysam.AlignmentFile(
                        p, mode, header=hdr, threads=threads,
                        format_options=[f"level={lvl}"])
                    paths[form, scope, lvl, cname] = p

    def write_all(form, scope, rec):
        for lvl in LEVELS:
            for cname, _ in CONTAINERS:
                writers[form, scope, lvl, cname].write(rec)

    reads = annos = 0
    for r in tqdm(src, desc=f"reshape {sample}", unit=" reads",
                  file=sys.stderr, mininterval=0.5):
        reads += 1
        ma = r.get_tag("MA") if r.has_tag("MA") else None
        aq = r.get_tag("AQ") if r.has_tag("AQ") else None
        an = r.get_tag("AN") if r.has_tag("AN") else None
        starts_ma, lengths = split_ma(ma) if ma is not None else (None, [])
        annos += len(lengths)

        # --- full records (seq intact) ---
        if ma is not None:
            r.set_tag("MA", ma, "Z")
        write_all("inline", "full", r)
        if ma is not None:
            r.set_tag("MA", starts_ma, "Z")
            if lengths:
                r.set_tag("AL", al_array(lengths))
            write_all("split", "full", r)
            if lengths:
                r.set_tag("AL", None)
            r.set_tag("MA", ma, "Z")
        else:
            write_all("split", "full", r)

        # --- tags-only records (strip seq/qual and all but annotation tags) ---
        r.query_sequence = None
        base = []
        if ma is not None:
            base.append(("MA", ma, "Z"))
        if aq is not None:
            base.append(("AQ", array("B", aq), None))
        if an is not None:
            base.append(("AN", an, "Z"))
        r.set_tags(base)
        write_all("inline", "tag", r)

        sp = []
        if ma is not None:
            sp.append(("MA", starts_ma, "Z"))
            if lengths:
                sp.append(("AL", al_array(lengths), None))
        if aq is not None:
            sp.append(("AQ", array("B", aq), None))
        if an is not None:
            sp.append(("AN", an, "Z"))
        r.set_tags(sp)
        write_all("split", "tag", r)

    for w in writers.values():
        w.close()
    src.close()

    for key, p in paths.items():
        form, scope, lvl, cname = key
        print(f"{sample}\t{form}\t{scope}\t{lvl}\t{cname}\t{os.path.getsize(p)}")
    print(f"{sample}\tMETA\treads\t0\t-\t{reads}")
    print(f"{sample}\tMETA\tannos\t0\t-\t{annos}")


if __name__ == "__main__":
    th = int(sys.argv[4]) if len(sys.argv) > 4 else 1
    main(sys.argv[1], sys.argv[2], sys.argv[3], th)
