# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'rake', require: false

group :test do
  gem 'cucumber'
  gem 'rspec'

  gem 'activemodel', '< 7.0'
  gem 'simplecov', require: false

  gem 'mutex_m' if RUBY_VERSION >= '3.4'
  gem 'rexml' if RUBY_VERSION >= '3.0'
end

group :docs do
  gem 'yard'
  gem 'yard-sitemap', '~> 1.0'
end

group :release do
  gem 'octokit'
end

group :development do
  gem 'pry'
  gem 'rubocop'
end
