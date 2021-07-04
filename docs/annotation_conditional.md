Annotation conditional
===

The annotation conditional is used to specify which annotations will be included. It takes the form:
```xml
<tei:fs type="opensiddur:annotation">
    <tei:f name="{ANNOTATION_ID_1}"><j:on/></tei:f>
    <tei:f name="{ANNOTATION_ID_2}"><j:on/></tei:f>
    ...
</tei:fs>
```

The annotation ID is the resource name (excluding the path `/data/notes`) of a resource
containing annotations. If the resource is on, all annotations from that source will be
included.

More than one annotation source may be included.

To turn off annotations from a particular source, set its annotation ID to `j:off`.
