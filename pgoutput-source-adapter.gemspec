# frozen_string_literal: true

require_relative 'lib/pgoutput/source_adapter/version'

Gem::Specification.new do |spec|
  spec.name = 'pgoutput-source-adapter'
  spec.version = Pgoutput::SourceAdapter::VERSION
  spec.authors = ['Ken C. Demanawa']
  spec.email = ['kenneth.c.demanawa@gmail.com']

  spec.summary = 'Source adapters for pgoutput decoded events.'
  spec.description = 'Normalizes pgoutput decoded events into downstream change-event platform primitives, including CDC::Core.'
  spec.homepage = 'https://github.com/kanutocd/pgoutput-source-adapter'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.4.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['documentation_uri'] = 'https://kanutocd.github.io/pgoutput-source-adapter/'
  spec.metadata['rubygems_mfa_required'] = 'true'

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    files = ls.readlines("\x0", chomp: true)
    files = Dir.glob('{lib,sig}/**/*') + %w[README.md CHANGELOG.md LICENSE.txt] if files.empty?

    files.reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .rubocop.yml])
    end
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'cdc-core', '~> 0.1'
  spec.add_dependency 'pgoutput-decoder', '~> 0.1'
end
