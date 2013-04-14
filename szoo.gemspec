# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = 'szoo'
  spec.version       = '1.2.3' # retrieve this value by: Gem.loaded_specs['szoo'].version.to_s
  spec.authors       = ['Kenn Ejima', 'GWoo']
  spec.email         = ['kenn.ejima@gmail.com', 'gwoohoo@gmail.com']
  spec.homepage      = 'http://github.com/gwoo/szoo'
  spec.summary       = %q{A fork of sunzi}
  spec.description   = %q{Server provisioning utility for minimalists}
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'thor'
  spec.add_runtime_dependency 'rainbow'
  spec.add_development_dependency 'rake'
end
