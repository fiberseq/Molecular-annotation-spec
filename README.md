# Molecular annotation (MA:Z:) tag

With the advent of functional single-molecule sequencing, there is an emerging need to annotate non-genetic elements on individual DNA molecules. This is handled for base modifications using the MM and ML tags. However, we have a need for a more extensible format beyond base modifications that allows for generic annotation of any segment of a molecule. To accomplish this we are proposing the `MA` tag, and we describe the format of this tag below:

## Format Specification

### Structure

```
MA:Z:annotation_type1:start1#len1#qual1#strand1,start2#len2#qual2#strand2;annotation_type2:start1#len1#qual1#strand1
```

Regex:

```
^(([a-zA-Z0-9_]+):((\d+#\d+#\d+#[+-])?(,\d+#\d+#\d+#[+-])*);?)+$
```

### Delimiters

| Delimiter | Purpose                                  | Example                       |
| --------- | ---------------------------------------- | ----------------------------- |
| `;`       | Separates different annotation types     | `msp:...;nuc:...;fire:...`    |
| `:`       | Separates annotation type name from data | `msp:100#50#255#+`            |
| `,`       | Separates annotations of the same type   | `100#50#255#+,200#60#200#+`   |
| `#`       | Separates fields within an annotation    | `start#length#quality#strand` |

### Annotation Fields

Each annotation consists of four fields separated by `#`:

1. **start** (i64): Start position in molecular coordinates (0-based)
2. **length** (i64): Length of the annotation in base pairs
3. **quality** (u8): Quality score (0-255)
4. **strand** (char): Strand orientation (`+` or `-`)

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
MA:Z:msp:100#50#255#+,200#60#200#+
```

- Two MSP annotations on the forward strand
- First MSP: position 100, length 50, quality 255, forward strand
- Second MSP: position 200, length 60, quality 200, forward strand

### Multiple Annotation Types

```
MA:Z:msp:100#50#255#+,200#60#200#+;nuc:150#103#0#+,300#100#0#+
```

- 2 MSP annotations (forward strand)
- 2 nucleosome annotations (forward strand)

## Coordinate System

### Molecular Coordinates

- **0-based, half-open intervals** [start, end)
- Coordinates are in the orientation of the sequenced molecule
- For reverse-strand alignments, coordinates do not change; they reflect the original molecule orientation

### Strand Information

- **`+`**: Annoation is on the forward strand of the sequenced molecule
- **`-`**: Annotation is on the reverse strand of the sequenced molecule

### Converting to Reference Coordinates

Reference coordinates are computed on-the-fly using the BAM alignment (CIGAR string) and are not stored in the `MA:Z` tag.

## Quality Scores

Quality scores (0-255) represent confidence in the annotation using the same convention as base modification quality scores.
