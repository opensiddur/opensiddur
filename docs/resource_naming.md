Resource Naming
===

Database resources names have the following properties:
1. Database resources may not have whitespace characters.
   1. Leading and trailing whitespace shall be removed.
   1. Multiple whitespace characters in a row shall be converted to a single underscore (`_`) character.
1. Names may only contain alphanumeric characters. Diacritics shall be removed.
   1. An exception is made for linkage files, which may contain an `=` character joining the names of the 
      resources being linked.
1. For alphabets with case, names must be stored lowercase.
   1. An exception is made for user names, where the resource name may be uppercased if the user name is.
1. Names are stored URL encoded.
1. Duplicate named resources are disambiguated by appending a `-` followed by a number.