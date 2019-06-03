lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "sheldon/version"

Gem::Specification.new do |spec|
  spec.name          = "sheldon"
  spec.version       = Sheldon::VERSION
  spec.authors       = ["Emiliano Heyns"]
  spec.email         = ["emiliano.heyns@iris-advies.com"]

  spec.summary       = %q{Provide feedback on CSL style/locale pull requests}
  spec.homepage      = "https://github.com/citation-style-language/Sheldon"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = %w{
    bin/sheldon
    lib/sheldon.rb
    lib/sheldon/version.rb
    sheldon.gemspec
  }
  spec.bindir        = 'bin'
  spec.executables   = ['sheldon']
  spec.require_paths = ["lib"]

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'bump'
  spec.add_development_dependency 'rack-test', '~>0.6'
  spec.add_development_dependency 'webmock', '~>2.1'

  # pin versions to old ones so tests run
  spec.add_development_dependency 'rake', '10.5.0'
  spec.add_development_dependency 'minitest', '5.10.1'
  spec.add_development_dependency 'byebug', '10.0.2'
  spec.add_dependency 'addressable', '2.5.2'
  spec.add_dependency 'backports', '3.11.4'
  spec.add_dependency 'bigdecimal', '1.3.0'
  #spec.add_dependency 'did_you_mean', '1.1.0'
  spec.add_dependency 'hashdiff', '0.3.7'
  spec.add_dependency 'multipart-post', '2.0.0'
  spec.add_dependency 'power_assert', '0.4.1'
  spec.add_dependency 'public_suffix', '3.0.3'
  spec.add_dependency 'rdoc', '5.0.0'
  spec.add_dependency 'xmlrpc', '0.2.1'
  spec.add_dependency 'json', '2.0.2'
  spec.add_dependency 'net-telnet', '0.1.1'
  spec.add_dependency 'openssl', '2.0.3'
  spec.add_dependency 'psych', '2.2.2'
  spec.add_dependency 'puma', '3.12.0'
  spec.add_dependency 'safe_yaml', '1.0.4'
  spec.add_dependency 'sawyer', '0.8.1'
  spec.add_dependency 'test-unit', '3.2.3'
  spec.add_dependency 'tilt', '2.0.8'

  spec.add_dependency 'citeproc-ruby'
  spec.add_dependency 'csl-styles'
  spec.add_dependency 'diffy'
  spec.add_dependency 'reverse_markdown'
  spec.add_dependency 'octokit', '4.13.0'
  spec.add_dependency 'dotenv'
  spec.add_dependency 'ostruct'
  spec.add_dependency 'sinatra', '~>1.4'
  spec.add_dependency 'sinatra-contrib', '~>1.4'
  spec.add_dependency 'erubis', '~>2.7'
  spec.add_dependency 'foreman', '~>0.78'
end
