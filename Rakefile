#!/usr/bin/env rake
require "bundler/gem_tasks"
require 'rake/testtask'
require 'rake/rdoctask'

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Run tests"
task :default => :test

Rake::RDocTask.new do |rd|
    rd.main = "README.rdoc"
    rd.rdoc_files.include("README.rdoc", "lib/**/*.rb")
end
desc "Generate documentation"
task :rdoc