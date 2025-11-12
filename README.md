# Molecular annotation tags

With the advent of functional single-molecule sequencing, there is an emerging need to annotate non-genetic elements on individual DNA molecules. This is handled for base modifications using the MM and ML tags. However, we have a need for a more extensible format beyond base modifications that allows for generic annotation of any segment of a molecule. To accomplish this we are proposing the `MA` tag, and we describe the format of this tag below.

Integration of this spec or a similar one into the SAM/BAM/CRAM is needed to standardize the representation of molecular annotations across different sequencing platforms and analysis tools. Importantly, a standardized format will allow for integration in a wide range of genomic tools, e.g. visualization in genome browsers and allow developers to be justified in spending time integrating this format into their tools.

## Format Specification

### Structure

The molecular annotation format uses four related tags:

- **MA:Z:** - Molecular Annotation start positions (required u32 integers)
- **AL:B:I** - Annotation Lengths (required signed 32-bit integers)
- **AQ:B:C** - Annotation Quality scores (required unsigned 8-bit integers)
- **AN:Z:** - Annotation Names (optional labels for individual annotations)

```
MA:Z:annotation_type1+:start1,start2;annotation_type2-:start1
AL:B:I,len1,len2,len3
AQ:B:C,qual1,qual2,qual3
AN:Z:name1,name2,name3
```

Regex for MA tag:

```
^(([a-zA-Z0-9_]+)[+-.]:((\d+)(,\d+)*);?)+$
```

### Molecular Coordinates

All coordinates in the MA tag are "molecular coordinates" meaning:

- **0-based positions**: Start positions use 0-based indexing (first base of the read is position 0)
- **Half-open intervals**: The annotated region spans [start, start+length), where start is inclusive and end is exclusive
- **Read orientation**: Coordinates are always in the orientation of the sequenced molecule, counting from the left
- **Alignment independent**: For reverse-strand alignments, coordinates do not change; they reflect the original molecule orientation

### Delimiters

**MA tag delimiters:**

| Delimiter | Purpose                                  | Example                       |
| --------- | ---------------------------------------- | ----------------------------- |
| `;`       | Separates different annotation types     | `msp+:...;nuc-:...;fire.:...` |
| `:`       | Separates annotation type name from data | `msp+:100,200`                |
| `,`       | Separates start positions                | `100,200,300`                 |

**AL, AQ, AN tag delimiters:**

| Delimiter | Purpose          | Example    |
| --------- | ---------------- | ---------- |
| `,`       | Separates values | `50,60,70` |

### Annotation Type within the MA Tag

The annotation type name is an alphanumeric string (including underscores) that describes the type of annotation followed by a strand indicator where:

- **`+`**: Annotation is on the forward strand of the sequenced molecule
- **`-`**: Annotation is on the reverse strand of the sequenced molecule
- **`.`**: Strand information is not applicable or unknown

e.g., `msp+`, `nuc-`, `fire.`

#### Strand Convention

Strand information is relative to the sequenced molecule and follows the same convention as the MM and ML tags for base modifications in the SAM specification:

- **All coordinates are in read orientation**: Coordinates always refer to positions on the forward strand of the original read sequence (i.e. starting from the leftmost base of the unaligned read).
- **For reverse-strand annotations (`-`)**: The annotation feature is on the reverse/Crick strand of the DNA molecule; however, coordinates still start from the left of the read sequence on the forward strand.
- **Strand is independent of alignment**: The strand indicator describes the biology of the feature, not the alignment orientation. If a read aligns to the reverse strand of a reference, the MA tag strand indicators remain unchanged.

**Example of strand-specific annotations** on a read of length 10 (where `#` marks the annotated region, `-` marks unannotated positions, and coordinates are 0-based):

This shows CTCF annotations on both the forward strand (start 0 length 4) and reverse strand (start 5 length 3).

```
MA:Z:ctcf+:0;ctcf-:5
AL:B:I,4,3
AQ:B:C,200,180

Position: 0123456789
Forward:  ####------
Reverse:  -----###--
```

### Annotation Data

Each annotation is represented across the four tags with corresponding values:

1. **MA tag** - Start position in molecular coordinates (0-based, i64)
2. **AL tag** - Length of the annotation in base pairs (i32)
3. **AQ tag** - Quality score (0-255, u8)
4. **AN tag** - Optional name/label for the annotation (string)

The values in AL, AQ, and AN tags correspond positionally to the annotations defined in the MA tag. For example, the first start position in the MA tag corresponds to the first length in AL, the first quality in AQ, and the first name in AN.

**Note:** When using the AN tag, if some annotations have names and others don't, use a `.` (period) to represent missing names. This maintains positional correspondence across all tags.

### Converting to Reference Coordinates

Reference coordinates are computed on-the-fly using the BAM alignment (CIGAR string) and are not stored in the `MA:Z` tag. i.e. alignment does not change the `MA` tag.

## Quality Scores

Quality scores (0-255) represent confidence in the annotation using the same convention as base modification quality scores.

## Common Annotation Types

### Standard Fiber-seq Annotations

| Type   | Description                                                         |
| ------ | ------------------------------------------------------------------- |
| `msp`  | Methylation-accessible patches (linker regions between nucleosomes) |
| `nuc`  | Nucleosome positions                                                |
| `fire` | Fiber-seq inferred regulatory elements (e.g., promoters, enhancers) |

### Custom Annotations

The format supports arbitrary annotation type names, allowing for:

- Custom chromatin features
- User-defined regions of interest
- Experimental annotations

## Examples

### Single Annotation Type

```
MA:Z:msp+:100,200
AL:B:I,50,60
AQ:B:C,255,200
```

- Two MSP annotations on the forward strand
- First MSP: start position 100, length 50, quality 255
- Second MSP: start position 200, length 60, quality 200

### Multiple Annotation Types

```
MA:Z:msp+:100,200;nuc+:150,300
AL:B:I,50,60,103,100
AQ:B:C,255,200,0,0
```

- 2 MSP annotations (forward strand)
- 2 nucleosome annotations (forward strand)

### With Partial Names

```
MA:Z:msp+:100,200;nuc+:150,300
AL:B:I,50,60,103,100
AQ:B:C,255,200,0,0
AN:Z:msp1,.,.,nuc2
```

- Only the first MSP and second nucleosome have names
- Unnamed annotations are represented with `.` to maintain positional correspondence
