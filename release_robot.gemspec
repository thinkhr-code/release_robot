# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'release_robot/version'

Gem::Specification.new do |spec|
  spec.name          = 'release_robot'
  spec.version       = ReleaseRobot::VERSION
  spec.authors       = ['Mark J. Lehman']
  spec.email         = ['markopolo@gmail.com']
  spec.description   = %q{Automate release tasks}
  spec.summary       = %q{Automate tasks surrounding releasing and deploying new code, informing stakeholders, and getting feedback.}
  spec.homepage      = 'https://github.com/MammothHR/release_robot'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.0'
  spec.add_development_dependency 'pry', '~> 0'
  spec.add_development_dependency 'bundler', '> 1.3'
  spec.add_development_dependency 'rake', '~> 10.5'

  spec.add_runtime_dependency 'octokit', '~> 4.6.2', '>= 4.6.0'
  spec.add_runtime_dependency 'highline', '~> 1.7.0', '>= 1.7.0'
end
