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
    lib/sheldon/travis.rb
    lib/sheldon/version.rb
    sheldon.gemspec
  }
  spec.bindir        = 'bin'
  spec.executables   = ['sheldon']
  spec.require_paths = ["lib"]

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'bump'

  spec.add_dependency 'citeproc-ruby'
  spec.add_dependency 'csl-styles'
  spec.add_dependency 'diffy'
  spec.add_dependency 'reverse_markdown'
  spec.add_dependency 'dotenv'
  spec.add_dependency 'ostruct'
end
