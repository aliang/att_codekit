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
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "ruby_wrapper"
  gem.homepage = "https://github.com/attdevsupport/"
  gem.license = "MIT"
  gem.summary = %Q{A wrapper class for the AT&T Platform APIs that hides all the technical details}
  gem.description = %Q{A simple interface for using the AT&T Platform APIs.  All you need is your client_id and client and a bit of code.}
  gem.email = "rh8730@att.com"
  gem.authors = ["Richard Harrington"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new
