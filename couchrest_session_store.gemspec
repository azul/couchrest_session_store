# _*_ encoding: utf-8 -*-

Gem::Specification.new do |gem|

  gem.authors = ["Azul"]
  gem.email = ["azul@leap.se"]
  gem.summary = "A Rails Session Store based on CouchRest Model"
  gem.description = gem.summary
  gem.homepage = "http://github.com/azul/couchrest_session_store"

  gem.has_rdoc = true
#  gem.extra_rdoc_files = ["LICENSE"]

  gem.files = `git ls-files`.split("\n")
  gem.name = "couchrest_session_store"
  gem.require_paths = ["lib"]
  gem.version = '0.4.2'

  gem.cert_chain  = ['certs/azul.pem']
  gem.signing_key = File.expand_path("~/.ssh/gem-private_key.pem") if $0 =~ /gem\z/

  gem.add_dependency "couchrest", "~> 2.0.0.rc3"
  gem.add_dependency "couchrest_model", "~> 2.1.0.beta2"
  gem.add_dependency "actionpack", '~> 4.0'

  gem.add_development_dependency "minitest"
  gem.add_development_dependency "rake"
end