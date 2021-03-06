# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
require './lib/spf/version.rb'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name        = 'spf'
  gem.version     = SPF::VERSION
  gem.homepage    = 'https://github.com/agaridata/spf-ruby'
  gem.authors     = ['Andrew Flury', 'Julian Mehnle', 'Jacob Rideout']
  gem.email       = ['code@agari.com', 'aflury@agari.com', 'jmehnle@agari.com', 'jrideout@agari.com']
  gem.license     = 'none (all rights reserved)'
  gem.summary     = 'Implementation of the Sender Policy Framework'
  gem.description = <<-DESCRIPTION
    An object-oriented Ruby implementation of the Sender Policy Framework (SPF)
    e-mail sender authentication system, fully compliant with RFC 4408.
  DESCRIPTION
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :default => :spec

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "spf-ruby #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

# vim:sw=2 sts=2
