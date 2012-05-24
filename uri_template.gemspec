Gem::Specification.new do |s|
  s.name = 'uri_template'
  s.version = '0.3.0'
  s.date = '2012-05-24'
  s.authors = ["HannesG"]
  s.email = %q{hannes.georg@googlemail.com}
  s.summary = 'A templating system for URIs.'
  s.homepage = 'http://github.com/hannesg/uri_template'
  s.description = 'A templating system for URIs, which implements RFC 6570: http://tools.ietf.org/html/rfc6570. An implementation of an older version of that spec is known as addressable. This gem however is intended to be extended when newer specs evolve. For now only draft 7 and a simple colon based format are supported.'
  
  s.require_paths = ['lib']
  
  s.files = Dir.glob('lib/**/**/*.rb') + ['uri_template.gemspec', 'README', 'CHANGELOG']
 
  s.add_development_dependency 'multi_json'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'yard'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'bundler'
end
