# Molecular annotations

The molecular annotation tags (`MA`, `AQ`, and `AN`) describe intervals (`annotations`) on the sequence as
originally reported by the sequencing instrument. These `annotations` describe
molecular features (`annotation types`) spanning one or more bases, for example:
nucleosome positions, methylation-accessible patches, and protein binding
sites.

Molecular annotations use three related tags. `MA` records the
`annotation types` and `annotations`. `AQ` optionally records per `annotation`
quality values. `AN` optionally records per `annotation` names.

As with base modifications, positions are recorded against the original
orientation of the sequenced molecule. Starts in `MA` are 1-based.

## MA:Z

`MA:Z:length(;type[-+.][PQ]*:start-length(,start-length)*)+`

The first field is the length of `SEQ` at the time the `MA` value was last
written. This allows tools to detect when `SEQ` has later been trimmed, clipped,
or otherwise altered. If this length differs from the current `SEQ` length,
the interval positions in `MA` tag have been invalidated.

Each block begins with an `annotation type` name, followed by a strand character
and optional quality specifier. An `annotation type` is the feature being
reported, such as a nucleosome, methylation-accessible patch, or
protein-binding site. It is analogous to a base modification code in `MM`. The
intervals in the block are individual `annotations` of that type.

Type names contain letters, digits, or underscores and are case-sensitive.
Strand is one of `+` for the same strand as the original sequenced molecule,
`-` for the opposite strand, or `.` for unstranded, unknown, or inapplicable
strand.

The optional quality specifier declares the number and interpretation of `AQ`
values per `annotation`. `P` indicates one Phred-scaled confidence value. `Q`
indicates one linearly scaled probability value, using the same byte mapping as
`ML`. Multiple characters, such as `PQ`, indicate multiple `AQ` values per
`annotation` in the stated order. If the specifier is absent, no `AQ` values are
stored for `annotations` of that `annotation type`.

The coordinate list is a comma-separated list of intervals written
`start-length`. Lengths are the number of bases spanned by the `annotation`, so
`101-50` covers bases 101 through 150 inclusive. Starts and lengths must be
positive, and no interval may extend beyond the length recorded at the start of
`MA`.

The same type name may appear in multiple blocks, for example to represent
strand-specific `annotations`. This follows the same convention as `MM`, where
strand is encoded in the block while positions are still counted on the original
sequence. All blocks with the same type name must use the same quality
specifier. Parsers should reject an `MA` tag where one type name is used with
conflicting quality specifiers.

## AQ:B:C

`AQ:B:C,qualities`

The optional `AQ` tag lists quality values for `annotations` in `MA` order, stored in a u8 array. It
is omitted when no `annotation type` has quality values. The SAM encoding uses a
byte array of type `C`. The number of `AQ` elements must equal the sum, over all
`MA` blocks, of the number of intervals multiplied by the number of
quality-specifier characters in that block.

For `Q` values, the continuous probability range 0.0 to 1.0 is remapped in equal
sized portions to integer values 0 to 255 inclusive, as in `ML`. Thus the
probability range corresponding to integer value `N` is `N/256` to
`(N + 1)/256`. `P` values are Phred-scaled confidence values, using the Phred convention
defined by the main SAM specification.

## AN:Z

`AN:Z:names`

The optional `AN` tag lists comma-separated names or labels for individual
`annotations` in `MA` order. `AN` names `annotations`, not `annotation types`.
If no `annotations` have names, `AN` should be omitted.

If some `annotations` are named and others are not, empty fields are used for
the unnamed `annotations`. The number of fields in `AN` must equal the total
number of intervals in `MA`. Names must not contain commas.

## Examples

For example:

```
MA:Z:1000;ctcf+Q:100-25,700-30;gata1-Q:350-18
AQ:B:C,220,205,180
```

The `ctcf` `annotation type` has two individual `annotations` on the same strand
as the original sequenced molecule. The `gata1` `annotation type` has one
`annotation` on the opposite strand. All three `annotations` have linearly
scaled probability values in `AQ`.

An `annotation type` may also have `annotations` on both strands:

```
MA:Z:1000;ctcf+Q:100-25,700-30;ctcf-Q:350-18
AQ:B:C,220,205,180
```

The two `ctcf` blocks are the same `annotation type`, split by strand. The
first block contains two `annotations` on the same strand as the original
sequenced molecule; the second contains one `annotation` on the opposite strand.

Similarly:

```
MA:Z:1000;msp.P:100-50,200-60,320-45;nuc.:500-147
AQ:B:C,40,35,38
AN:Z:msp1,,msp3,
```

The `msp` `annotation type` has three unstranded `annotations` with
Phred-scaled qualities. The `nuc` `annotation type` has one unstranded
`annotation` without a quality value. `AN` names the first and third msp
`annotations`. The second msp and the nuc `annotation` are unnamed.
