$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "open_places/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "open_places"
  s.version     = OpenPlaces::VERSION
  s.authors     = ["Ty Rauber"]
  s.email       = ["tyrauber@mac.com"]
  s.homepage    = "http://github.com/tyrauber/open_places"
  s.summary     = "A Location Autocomplete Rails 4 Engine"
  s.description = "Imports Natural Earth geospatial data and provides a mountable JSON/GeoJSON API endpoint."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]

  s.add_dependency "rails", "~> 4.0"
  s.add_development_dependency "rspec-rails", "~> 3.0"
  s.add_dependency "pg", "~> 0.18"
  s.add_dependency "activerecord-postgis-adapter"
  s.add_dependency "geocoder"
end
