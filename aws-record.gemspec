# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'aws-record'
  spec.version       = File.read(File.expand_path('VERSION', __dir__)).strip
  spec.authors       = ['Amazon Web Services']
  spec.email         = ['aws-dr-rubygems@amazon.com']
  spec.summary       = 'AWS Record library for Amazon DynamoDB'
  spec.description   = 'Provides an object mapping abstraction for Amazon DynamoDB.'
  spec.homepage      = 'https://github.com/aws/aws-sdk-ruby-record'
  spec.license       = 'Apache 2.0'

  spec.require_paths = ['lib']
  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'CHANGELOG.md', 'VERSION']

  spec.add_dependency 'ostruct', '~> 0'

  # Require 1.85.0 for user_agent_frameworks config
  spec.add_dependency 'aws-sdk-dynamodb', '~> 1', '>= 1.85.0'

  spec.required_ruby_version = '>= 2.7'
end
