xquery version "3.0";

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

(: add $target/data/sources/Born Digital using src:post() or src:put() :)
()
(: add $target/data/styles/generic.xml using sty:post() or sty:put() :)