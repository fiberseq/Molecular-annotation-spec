# Molecular annotations

Molecular annotations describe intervals on the primary sequence as originally
reported by the sequencing instrument. Examples include nucleosome positions,
methylation-accessible patches, protein binding sites, and inferred regulatory
elements. These annotations describe molecular features spanning one or more
bases, not modifications of a single base.

As with base modifications, annotation positions are recorded against the
original orientation of the sequenced molecule.

## MA:Z

MA:Z:length(;type[-+.][PQ]*:start-length(,start-length)*)+

The first field is the length of SEQ at the time the MA value was last written.
This allows tools to detect when SEQ has later been trimmed, clipped, or
otherwise altered. If this length differs from the current SEQ length,
coordinates in MA should not be assumed to index the current SEQ.

Each annotation block begins with a type name, followed by a strand character
and optional quality specifier. Type names contain letters, digits, or
underscores and are case-sensitive. Strand is one of '+' for the same strand as
the original sequenced molecule, '-' for the opposite strand, or '.' for
unstranded, unknown, or inapplicable strand.

The optional quality specifier declares the number and interpretation of AQ
values per annotation. 'P' indicates one Phred-scaled confidence value. 'Q'
indicates one linearly scaled probability value, using the same byte mapping as
ML. Multiple characters, such as 'PQ', indicate multiple AQ values per
annotation in the stated order. If the specifier is absent, no AQ values are
stored for annotations in that block.

The coordinate list is a comma-separated list of intervals written
start-length. Starts are 1-based positions on the original sequenced molecule.
Lengths are the number of bases spanned by the annotation, so 101-50 covers
bases 101 through 150 inclusive. Starts and lengths must be positive, and no
interval may extend beyond the length recorded at the start of MA.

The same type name may appear in multiple blocks, for example to represent
strand-specific annotations. All blocks with the same type name must use the
same quality specifier. Parsers should reject an MA tag where one type name is
used with conflicting quality specifiers.

Reference coordinates are not stored in MA. They may be computed from the read
alignment and CIGAR string when needed.

## AQ:B:C

AQ:B:C,qualities

The optional AQ tag lists quality values for annotations in MA order. The SAM
encoding uses a byte array of type 'C'. The number of AQ elements must equal the
sum, over all MA blocks, of the number of intervals multiplied by the number of
quality-specifier characters in that block.

For 'Q' values, the continuous probability range 0.0 to 1.0 is remapped in equal
sized portions to integer values 0 to 255 inclusive. Thus the probability range
corresponding to integer value N is N/256 to (N + 1)/256. 'P' values are
Phred-scaled confidence values.

## AN:Z

AN:Z:names

The optional AN tag lists comma-separated names or labels for annotations in MA
order. Empty fields are used for unnamed annotations when other annotations are
named. The number of fields in AN must equal the total number of intervals in
MA. Names must not contain commas.

## Examples

For example:

MA:Z:1000;msp+P:100-50,200-60;nuc.:300-147;fire.Q:500-75
AQ:B:C,40,35,200
AN:Z:msp1,,nuc1,

This describes two msp annotations with Phred-scaled qualities, one unstranded
nuc annotation without a quality value, and one unstranded fire annotation with
a linearly scaled quality value. The first msp and nuc annotations have names.

Similarly:

MA:Z:10;ctcf+Q:1-4;ctcf-Q:6-3
AQ:B:C,200,180

This describes two ctcf annotations on a molecule of length 10. The first is on
the same strand as the original sequenced molecule and covers bases 1 through 4.
The second is on the opposite strand and covers bases 6 through 8.
