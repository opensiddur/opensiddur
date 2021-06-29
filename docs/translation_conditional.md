Translation Conditional
===

To specify translations, use:
```xml
<tei:fs type="opensiddur">
    <tei:f name="translation">
        <tei:string>{PREFERENCE 1}</tei:string>
        <tei:string>{PREFERENCE 2}</tei:string>
        <tei:string>{PREFERENCE 3}</tei:string>
        ...
    </tei:f>
</tei:fs>
```

Translations are referenced by the `j:parallelText/tei:idno` element in `linkage` type files.
To use translation, at least one translation preference must be specified. If more than one translation is specified,
the translation that will be chosen for display will be the first one specified with a linkage to a
document.

To turn translations off, set the `translation` setting to no string value.

When the translation setting is set, a processor may choose to switch translations 
immediately *or* only when including document via `tei:ptr`. 

When including a new document, translations are not guaranteed to align with the inclusion.
If the translation does not align perfectly, a processor may choose to expand the translation
around the included region.