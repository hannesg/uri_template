# sigh, same setting everywhere ...
source "http://rubygems.org"
gemspec

group :development do
  gem 'escape_utils', :platforms => [:mri_19, :mri_18]
  gem 'coveralls', :require => false, :platforms => [:mri_19]
  gem 'simplecov-console', :platforms => [:mri_19]
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
