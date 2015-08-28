module OpenPlaces
  class Engine < ::Rails::Engine
    isolate_namespace OpenPlaces
    
    config.generators do |g|
      g.test_framework :rspec
    end

    def self.normalize_data
      ActiveRecord::Base.connection.execute("UPDATE open_places p SET code = 'NO' WHERE name='Norway';")
      ActiveRecord::Base.connection.execute("UPDATE open_places p SET country_code = 'FR' WHERE country_code IN ('GP', 'RE', 'GF', 'MQ', 'YT');")
      ActiveRecord::Base.connection.execute("UPDATE open_places p SET country_code = 'NO' WHERE country_code IN ('SJ', 'NOR');")

      # Set Province and Country
      matches = [
        "(p.province_code=p2.code OR p.province_name=p2.name) AND p.country_code=p2.country_code AND p2.geotype='OpenPlaces::Province'",
        "ST_Contains(p2.geom, p.latlng) AND p2.geotype='OpenPlaces::Province'",
        "p2.code= p.country_code",
        "ST_Contains(p2.geom, p.latlng)"
      ]
      matches.each do |match|
        ActiveRecord::Base.connection.execute("UPDATE open_places p SET country_name = p2.country_name, country_code = p2.country_code,
         province_name = p2.name, province_code = p2.code, continent = p2.continent, region_un = p2.region_un, subregion = p2.subregion, region_wb= p2.region_wb, 
         long_name = concat_ws(' ', concat_ws(', ', p.name, p2.name), p2.country_name),
         tsvector = setweight(to_tsvector(p.name), 'A') || setweight(to_tsvector(p2.name), 'B') || setweight(to_tsvector(p2.country_name), 'C'),
         slug = regexp_replace(trim(regexp_replace(lower(concat_ws('-', p.name, p2.name, p2.country_name)), '[^0-9a-z/]+', ' ', 'g')), '[ ]+', '-', 'g'),
         path = regexp_replace(trim(regexp_replace(lower(concat_ws('/', p2.country_name, p2.name, p.name)), '[^0-9a-z/]+', ' ', 'g')), '[ ]+', '-', 'g')
         FROM open_places p2 WHERE p.continent IS NULL AND p.geotype != 'OpenPlaces::Country'
         AND #{match}")
      end

      # Set GeoSpatial Fields
      ActiveRecord::Base.connection.execute("UPDATE open_places p SET latlng =  ST_SetSRID(ST_Point(longitude, latitude),4326) WHERE latlng IS NULL;")
      ActiveRecord::Base.connection.execute("UPDATE open_places p SET geom = ST_Expand(ST_SetSRID(ST_Point(longitude, latitude),4326), .1) WHERE geom IS NULL;")
      ActiveRecord::Base.connection.execute("UPDATE open_places p SET bbox = ST_Envelope(geom) WHERE bbox IS NULL;")
      ActiveRecord::Base.connection.execute("UPDATE open_places p SET latitude = ST_Y(latlng), longitude = ST_X(latlng) WHERE latitude = 0 OR longitude = 0;")
      ActiveRecord::Base.connection.execute("UPDATE open_places p SET area = ST_Area(geom) WHERE area = 0;")
      ActiveRecord::Base.connection.execute("UPDATE open_places p SET x_min = ST_XMin(geom), y_min = ST_YMin(geom), x_max = ST_XMax(geom), y_max = ST_YMax(geom) WHERE x_min = 0 OR y_min = 0 OR x_max = 0 OR y_max = 0;")

      # Update path, slug & tsvector
      ActiveRecord::Base.connection.execute("UPDATE open_places p SET long_name = concat_ws(' ', concat_ws(', ', name, province_name), country_name) WHERE p.long_name IS NULL;")
      ActiveRecord::Base.connection.execute("UPDATE open_places p SET
        slug = regexp_replace(trim(regexp_replace(lower(concat_ws('-', p.name, p.province_name, p.country_name)), '[^0-9a-z/]+', ' ', 'g')), '[ ]+', '-', 'g'),
        path = regexp_replace(trim(regexp_replace(lower(concat_ws('/', p.country_name, p.province_name, p.name)), '[^0-9a-z/]+', ' ', 'g')), '[ ]+', '-', 'g')
        WHERE (p.slug IS NULL OR p.path IS NULL);")
      ActiveRecord::Base.connection.execute("UPDATE open_places SET short_name = concat_ws(', ', name, province_name) WHERE geotype not IN ('OpenPlaces::Country', 'OpenPlaces::Province') AND country_code = 'US' AND short_name IS NULL;")
      ActiveRecord::Base.connection.execute("UPDATE open_places SET short_name = concat_ws(', ', name, country_name) WHERE country_code != 'US' AND short_name IS NULL AND short_name IS NULL;")
      ActiveRecord::Base.connection.execute("UPDATE open_places SET tsvector = setweight(to_tsvector(name), 'A') || setweight(to_tsvector(province_name), 'B') || setweight(to_tsvector(country_name), 'C') WHERE tsvector IS NULL AND province_name IS NOT NULL;")
      ActiveRecord::Base.connection.execute("UPDATE open_places SET tsvector = setweight(to_tsvector(name), 'A') || setweight(to_tsvector(country_name), 'C') WHERE tsvector IS NULL AND country_name IS NOT NULL;")
      ActiveRecord::Base.connection.execute("UPDATE open_places SET tsvector = setweight(to_tsvector(name), 'A') WHERE tsvector IS NULL;")
    end
  end
end
