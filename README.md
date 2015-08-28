# OpenPlaces

OpenPlaces is a Location Autocomplete Rails 4 Engine. It imports NaturalEarthData.com and Geonames.org geospatial data and provides a mountable JSON/GeoJSON API endpoint.

## Requirements

### Requires Postgres and PostGIS.

OpenPlaces uses Postgres and the PostGIS adapter to do fast geo-spatial and full text search. A Rails 4 application with a Postgres database with the PostGIS extension is required to use OpenPlaces.

## Installation

1. Add 'open_places' to your Gemfile and bundle install
2. Run `rake open_places:install:migrations`
3. Run `rake db:migrate`
4. Mount the engine:
	mount OpenPlaces::Engine => "/api/geo" 
5. Restart your server

Visit: http://localhost:3000/api/geo?q=Seattle

## Usage

The api endpoint is able to do a couple different operational queries

 - q=  Exact Match
 - like= Fuzzy Match (using postgres ts_vector)
 - contains=  Contains (LIKE '%?%')
 - starts=  Starts with (LIKE '?%')
 - ends= Ends with (LIKE '%?')

Additionally, it will take a near param, a latitude,longitude string. With a near param, a distance attribute is added and the results are ordered by population, distance, and ts_rank if the operational query is like.

## Data Structure

OpenPlaces includes a rake task to build a single database table of normalized data. For convenience, a 12Mb CSV file is included for fast import.  The data includes the following fields:

  - geo_type
	- subtype
	- scalerank
  - code
  - name
  - long_name
  - country
  - country_code
  - province
  - province_code
	- continent
	- region_un
	- subregion
	- region_wb
  - latitude
  - longitude
	- x_min
	- y_min
	- x_max
	- area

## Data Sources

OpenPlaces imports [Countries](http://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-admin-0-countries/), [States/Provinces](http://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-admin-1-states-provinces/), [Cities](http://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-populated-places/), [National Parks](http://www.naturalearthdata.com/downloads/10m-cultural-vectors/parks-and-protected-lands/), [Lakes](http://www.naturalearthdata.com/downloads/10m-physical-vectors/10m-rivers-lake-centerlines/) and [Rivers](http://www.naturalearthdata.com/downloads/10m-physical-vectors/10m-lakes/) from [Natural EarthData.com](http://www.naturalearthdata.com) and [Geonames.org](http://geonames.org).

### Total Records

- 255 Countries
- 4516 States/Provinces
- 146474 Places (Metros/Cities/Towns)
- 61 US National Parks
- 743 Lakes
- 1454 Rivers
