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
Jeweler::Tasks.new do |gem|
  gem.name = "silver"
  gem.homepage = "http://github.com/tpm/silver"
  gem.license = "MIT"
  gem.summary = %Q{Makes your queries faster with the power of Redis.}
  gem.description = %Q{A lightweight, Redis-backed cacher and indexer for databases, REST API's, really anything you can query.}
  gem.email = "hinton.erik@gmail.com"
  gem.authors = ["Erik Hin-tone"]
  gem.add_runtime_dependency  "redis", "~>  2.1.1"
  gem.add_runtime_dependency  "yajl-ruby", ">=  0.7.7"
  gem.add_runtime_dependency  "text", "~>  0.2.0"
  gem.add_development_dependency "dm-core", "~> 1.0.0"
  gem.add_development_dependency "dm-sqlite-adapter", "~> 1.0.0"
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

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "silver #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
