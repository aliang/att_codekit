# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "att_codekit"
  s.version = "0.1.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Richard Harrington"]
  s.date = "2013-09-12"
  s.description = "A simple interface for using the AT&T Platform APIs.  All you need is your client_id and client and a bit of code."
  s.email = "rh8730@att.com"
  s.extra_rdoc_files = [
    "README.rdoc"
  ]
  s.files = [
    ".ruby-version",
    "Gemfile",
    "Gemfile.lock",
    "README.rdoc",
    "lib/att_codekit.rb",
    "att_codekit.gemspec"
  ]
  s.homepage = "https://github.com/attdevsupport/"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "2.0.6"
  s.summary = "A wrapper class for the AT&T Platform APIs that hides all the technical details"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<htmlentities>, ["~> 4.3"])
    else
      s.add_dependency(%q<htmlentities>, ["~> 4.3"])
    end
  else
    s.add_dependency(%q<htmlentities>, ["~> 4.3"])
  end
end

