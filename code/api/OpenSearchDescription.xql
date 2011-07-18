xquery version "1.0";
(:~ Return an Open Search description, as described at http://www.opensearch.org/Specifications/OpenSearch/1.1 :)
import module namespace paths="http://jewishliturgy.org/modules/paths" 
  at "xmldb:exist:///code/modules/paths.xqm";

declare default element namespace "http://a9.com/-/spec/opensearch/1.1/";
declare option exist:serialize "method=xml media-type=application/opensearchdescription+xml indent=yes omit-xml-declaration=no";

<OpenSearchDescription>
  <ShortName>Open Siddur Search</ShortName>
  <Description>Full text search of Open Siddur texts.</Description>
  <Tags>siddur</Tags>
  <Contact>efraim@opensiddur.org</Contact>
  <Url type="application/xhtml+xml" 
    template="{request:get-parameter('source', '')}?q={{searchTerms}}&amp;start={{startIndex?}}&amp;max-results={{count?}}"
    />
</OpenSearchDescription>
