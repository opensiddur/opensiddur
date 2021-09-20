Merge Algorithm
===

The problem: given an XML original data file and another file that purports to represent
the same text (1) from the same source or (2) from a different source, how do we 
produce a new XML original data file that represents both?

Header
---
fileDesc/
    titleStmt/
        title - keep original?
    publicationStmt/
        distributor/ - no change
        availability/ - check for license compatibility
    sourceDesc
        bibl/ - join (but modify to point to sources)
    revisionDesc
        join, add a new tei:change showing the poster merging

bibl - possibilities are:
- same source, same pages: this is just editing
- data are from the same source, different pages *or* different sources; add the new bibl 

Links
---
??

Conditionals
---

Text
---
streamText - can only have 1 xml:id; standardize on the old one (require that they be the same, rec #stream)
xml content - pass thru
text - split to words

option 1: try to automatically merge documents if they represent the same text.

issues:
- externally referenced xml:ids must be maintained. we will have to *enforce*
  the single use of anchors policy, which is not enforced now.
- sourcing conditionals have to apply to text and hierarchy - put a j:conditional link on the hierarchy element
  *or* support multiple j:concurrent hierarchies, one for each source
- sourcing conditionals can overlap: not a problem - when constructing the phony conditionals for sources, use *or* logic
- potential for duplicate xml:ids between the files (add a random hash before xml:ids in the new file?)

option 2: support multiple streamTexts, each one for one source; 
still have to assume that xml:ids are document unique;
This is essentially no different than option 3, except that we will explicitly
put all of the texts in the same file.

option 3: do not allow two documents in the same "project/input set" to have
the same name.
if a document in the input set has the same name as a document in the database,
rename it x-1 and mass change all of the pointers into it. We will have multiple 
copies of the same texts that will have to be manually merged and edited.