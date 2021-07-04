Source Conditionals
===

Status: Not yet implemented

All documents reference their own source(s) in the `tei:sourceDesc` section of the header.
Within the `tei:bibl/tei:ptr[@type='bibl-content']`, the `@target` attribute references which 
ranges in the `streamText` are from that source. In addition, if a document has multiple
concurrent hierarchies from different sources, the hierarchies should also be referenced in 
the header.

We define the following conditional:
```xml
<tei:fs type="opensiddur">
    <tei:f name="sources">
        <tei:string>{SOURCE PREFERENCE 1}</tei:string>
        <tei:string>{SOURCE PREFERENCE 2}</tei:string>
    </tei:f>
</tei:fs>
```

The `opensiddur/sources` feature contains an ordered list of sources, such that, in 
cases where a document derives from multiple sources, the first one present in the
document will be selected.

If an included document does not derive from any of the
listed sources, the result is undefined. The processor may choose any or all of the
available sources.

### Implementation

The `sourceDesc` will add an additional phony conditional layer that specifies source
conditionals.