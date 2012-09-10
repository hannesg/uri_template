URITemplate - a uri template library
========================

[![Build Status](https://secure.travis-ci.org/hannesg/uri_template.png)](http://travis-ci.org/hannesg/uri_template)
[![Dependency Status](https://gemnasium.com/hannesg/uri_template.png)](https://gemnasium.com/hannesg/uri_template)
[![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/hannesg/uri_template)

With URITemplate you can generate URIs based on simple templates and extract variables from URIs using the same templates. There are currently two syntaxes defined. Namely the one defined in [RFC 6570]( http://tools.ietf.org/html/rfc6570 ) and a colon based syntax, similiar to the one used by sinatra.

From version 0.2.0, it will use escape_utils if available. This will significantly boost uri-escape/unescape performance if more characters need to be escaped ( may be slightly slower in trivial cases. working on that ... ), but does not run everywhere. To enable this, do the following:

    # escape_utils has to be loaded when uri_templates is loaded
    gem 'escape_utils'
    require 'escape_utils'
    
    gem 'uri_template'
    require 'uri_template'
    
    UriTemplate::Utils.using_escape_utils? #=> true


Examples
-------------------

    require 'uri_template'
    
    tpl = URITemplate.new('http://{host}{/segments*}/{file}{.extensions*}')
    
    # This will give: http://www.host.com/path/to/a/file.x.y
    tpl.expand('host'=>'www.host.com','segments'=>['path','to','a'],'file'=>'file','extensions'=>['x','y'])
    
    # This will give: { 'host'=>'www.host.com','segments'=>['path','to','a'],'file'=>'file','extensions'=>['x','y']}
    tpl.extract('http://www.host.com/path/to/a/file.x.y')
    
    # If you like colon templates more:
    tpl2 = URITemplate.new(:colon, '/:x/y')
    
    # This will give: {'x' => 'z'}
    tpl2.extract('/z/y')


RFC 6570 Syntax
--------------------

The syntax defined by [RFC 6570]( http://tools.ietf.org/html/rfc6570 ) is pretty straight forward. Basically anything surrounded by curly brackets is interpreted as variable.

    URITemplate.new('{variable}').expand('variable' => 'value') #=> "value"

The way variables are inserted can be modified using operators. The operator is the first character between the curly brackets. There are seven operators defined `#`, `+`, `;`, `?`, `&`, `/` and `.`. So if you want to create a form-style query do this:

    URITemplate.new('{?variable}').expand('variable' => 'value') #=> "?variable=value"

Benchmarks
-----------------------

 * System: Core 2 Duo T9300, 4 gb ram, ubuntu 12.04 64 bit, ruby 1.9.3, 100_000 repetitions
 * Implementation: RFC6570 ( version 0.3.0 ) vs. Addressable ( 2.2.8 )
 * Results marked with * means that the template object is reused.

                                                       Addressable | Addressable* | RFC6570 | RFC6570* |
    --Expansion-----------------------------------------------------------------------------------------
    Empty string                                             8.505 |        8.439 |   0.539 |    0.064 |
    One simple variable                                     19.717 |       19.721 |   3.031 |    1.169 |
    One escaped variable                                    21.873 |       22.017 |   3.573 |    1.705 |
    One missing variable                                     9.676 |       11.981 |   2.633 |    0.352 |
    Path segments                                           29.901 |       31.698 |   4.929 |    3.051 |
    Arguments                                               36.584 |       36.531 |   9.540 |    5.982 |
    Full URI                                               109.102 |      116.458 |  19.806 |   10.548 |
    Segments and Arguments                                 108.103 |      107.750 |  14.059 |    7.593 |
    total                                                  343.461 |      354.596 |  58.109 |   30.464 |
    --Extraction----------------------------------------------------------------------------------------
    Empty string                                            21.422 |       21.843 |   3.122 |    0.804 |
    One simple variable                                     39.860 |       43.840 |  10.671 |    2.874 |
    One escaped variable                                    51.321 |       50.790 |  10.963 |    2.040 |
    One missing variable                                    26.125 |       26.320 |   9.400 |    1.847 |
    Path segments                                           62.712 |       64.191 |  18.502 |    4.518 |
    Arguments                                               81.350 |       81.258 |  20.762 |    5.401 |
    Full URI                                               145.339 |      141.795 |  45.306 |   11.096 |
    Segments and Arguments                                 124.431 |      122.885 |  34.208 |    8.126 |
    Segments and Arguments ( not extractable )              34.183 |       34.200 |  26.542 |    0.410 |
    total                                                  586.743 |      587.122 | 179.476 |   37.116 |

SUCCESS - URITemplate was faster in every test!

