# sigh, same setting everywhere ...
source "http://rubygems.org"
gemspec

group :development do
  gem 'escape_utils', :platforms => [:ruby_20, :ruby_19, :ruby_18]
  gem 'coveralls', :require => false, :platforms => [:ruby_20, :ruby_19, :jruby]
  gem 'simplecov-console', :platforms => [:ruby_20, :ruby_19]
end

group :masochism do
  gem 'mutant', :platforms => [:ruby]
end

group :documentation do
  gem 'redcarpet', :platforms => [:mri_19]
end

group :benchmark do
  gem 'addressable'
end
