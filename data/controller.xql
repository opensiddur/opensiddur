xquery version "1.0";
(: this controller simply redirects to /code/api :)
declare namespace exist="http://exist.sourceforge.net/NS/exist";

declare variable $exist:path external;

<exist:dispatch>
  <exist:redirect url="/code/api/data/{$exist:path}"/>
</exist:dispatch>
