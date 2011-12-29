Gem::Specification.new do |s|
  s.name = 'uri_template'
  s.version = '0.2.1'
  s.date = '2011-12-30'
  s.authors = ["HannesG"]
  s.email = %q{hannes.georg@googlemail.com}
  s.summary = 'A templating system for URIs.'
  s.homepage = 'http://github.com/hannesg/uri_template'
  s.description = 'A templating system for URIs, which implements http://tools.ietf.org/html/draft-gregorio-uritemplate-07 . An implementation of an older version of that spec is known as addressable. This gem however is intended to be extended when newer specs evolve. For now only draft 7 and a simple colon based format are supported.'
  
  s.require_paths = ['lib']
  
  s.files = Dir.glob('lib/**/**/*.rb') + ['uri_template.gemspec', 'README', 'CHANGELOG']
  
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'yard'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'bundler'
end
