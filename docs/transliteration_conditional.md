Transliteration Conditional
===

To turn transliteration ON, set:
```xml
<tei:fs type="opensiddur:transliteration">
    <tei:f name="active"><j:on/></tei:f>
    <tei:f name="table">{SCHEMA_NAME}</tei:f>
    <tei:f name="script">{SCRIPT}</tei:f>
</tei:fs>
```

`j:on` and `j:yes` are equivalent and will both turn transliteration on. Any other
setting will turn it off. `on` and `off` are recommended over `yes` and `no` because
`active` is a two-way switch.

The `SCHEMA_NAME` parameter is the resource name of a transliteration schema stored
in the `/data/transliteration` directory on the database.

The `SCRIPT` will be used to choose which `tr:table` to use, based on the 
`tr:table/tr:lang` element. The input language/script will be that of the input text.
The output script will be that of the `@out` attribute.