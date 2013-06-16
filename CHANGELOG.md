# 0.6.0 - TBD
  - * You can now pass variables as an Array to URITemplate#expand ( thanks to @bmaland )
      Example:

        tpl = URITemplate.new("/{var}/")
        tpl.expand(["value"]) # => '/value/'
  - * BUGFIX: Expanding arrays/hashes with a length limit now actually works

# 0.5.2 - 24.02.2013
  - + The colon based uri templates now allow more characters in variable names.

# 0.5.1 - 23.09.2012
  - * f*** bug.

# 0.5.0 - 23.09.2012
  - - Removed draft7
  - - splitted absoulte? method into host? and scheme?
  - + the URITemplate interface is now much stronger
  - * code quality _significantly_ improved
  - + concat method

# 0.4.0 - 06.07.2012
  - + expand now accepts symbols as keys ( thanks to @peterhellber )
  - + expand now accepts arrays of pairs ( thanks to @peterhellber )
  - * fixed some testing bugs

# 0.3.0 - 24.05.2012
  - + Implemented the final version. Default implementation is now RFC 6570
  - * BUGFIX: variables with terminal dots were allowed
  - * BUGFIX: lists of commas were parsed incorrectly

# 0.2.1 - 30.12.2011
  - * Compatibility: Works now with MRI 1.8.7 and REE

# 0.2.0 - 03.12.2011
  - * Reworked the escaping mechanism
  - + escape_utils can now be used to boost escape/unescape performance

# 0.1.4 - 19.11.2011
  - * Compatiblity: Works now with MRI 1.9.3, Rubinius and JRuby
  - * Various (significant!) performance improvements

# 0.1.3 - 15.11.2011
  - * BUGFIX: Draft7./ now concatenates literals correctly
  - * BUGFIX: Draft7.tokens is now public

# 0.1.2 - 10.11.2011
  - + added a new template-type: Colon
    this should allow (some day) to  rails-like routing tables
  - + made the tokens-method mandatory and added two interfaces for tokens.
    this allows cross-type features like variable anaylisis

# 0.1.1 -  4.11.2011
  - + added a bunch of useful helper methods

# 0.1.0 -  2.11.2011
  - - Removed Sections. They made too many headaches.
  - + Made draft7 template concatenateable. This should replace sections.
  - * BUGFIX: multiline uris were matched
  - * BUGFIX: variablenames were decoded when this was not appreciated

# 0.0.2 -  1.11.2011
  - * BUGFIX: Concatenating empty sections no more leads to catch-all templates, when an emtpy template was appreciated.
  - + The extracted variables now contains the keys :suffix and :prefix if the match didn't consume the whole uri.

# 0.0.1 - 30.10.2011
  - Initial version
