require 'csv'
namespace :open_places do

  namespace :natural_earth do

    def file_groups
      {
        physical: {
          rivers: 'rivers_lake_centerlines',
          lakes: 'lakes'
        },
        cultural: {
          countries: 'admin_0_countries',
          provinces: 'admin_1_states_provinces',
          parks: 'parks_and_protected_lands_area',
          places: 'populated_places'
        }
      }
    end

    task :download, [:scale] => :environment  do |t, args|
      args.with_defaults(:scale => 10)
      file_groups.each do |type, group|
        group.each do |key, value|
          ['shp','shx','dbf'].each do |filetype|
            `curl -o #{Rails.root}/tmp/natural_earth_vector/#{args[:scale]}m_#{type}/ne_#{args[:scale]}m_#{value}.#{filetype} --create-dirs -L https://github.com/nvkelso/natural-earth-vector/raw/master/#{args[:scale]}m_#{type}/ne_#{args[:scale]}m_#{value}.#{filetype}`
          end
        end
      end
    end

    task :import, [:scale] => :environment  do |t, args|
      args.with_defaults(:scale => 10)
      file_groups.each do |type, group|
        group.each do |key, value|
          ActiveRecord::Base.connection.execute(`shp2pgsql -W LATIN1 \
                    -s 4326 \
                    -I #{Rails.root}/tmp/natural_earth_vector/#{args[:scale]}m_#{type}/ne_#{args[:scale]}m_#{value}.shp \
                    natural_earth_#{key.to_s}`)
          # Add / Update latlng column to speed up Materialized View sql in OpenPlaces::Geo
          ActiveRecord::Base.connection.execute("ALTER TABLE natural_earth_#{key.to_s} ADD COLUMN latlng geometry;")
          ActiveRecord::Base.connection.execute("UPDATE natural_earth_#{key.to_s} SET latlng = g.latlng FROM (SELECT DISTINCT ON (a.gid) a.gid, (a.p_geom).path[1] As path, ST_Area(geom(a.p_geom)) AS area, ST_PointOnSurface(geom(a.p_geom)) AS latlng FROM (SELECT gid, ST_Dump(geom) as p_geom FROM natural_earth_#{key.to_s}) AS a order by gid, ST_Area(geom(a.p_geom)) DESC) g WHERE g.gid = natural_earth_#{key.to_s}.gid")
        end
      end
    end

    task :countries => :environment  do |t, args|
      ActiveRecord::Base.connection.execute("UPDATE natural_earth_countries SET name = 'Curacao', name_long = 'Curacao', geounit ='Curacao' WHERE name='CuraÃ§ao';")      
      ActiveRecord::Base.connection.execute(%(
        INSERT INTO open_places (geotype, subtype, scalerank, code, name, continent, region_un, subregion, region_wb, geom, latlng) (
          SELECT 'OpenPlaces::Country'::varchar, c.featurecla, c.scalerank,
          (CASE WHEN c.iso_a2 != '-99' THEN c.iso_a2 WHEN fips_10_ != '-99' THEN fips_10_ ELSE sov_a3 END),
          c.ascii_name, c.continent, c.region_un, c.subregion, c.region_wb, c.geom, c.latlng
          FROM (SELECT *, (CASE WHEN name ~ '^[0-9A-Za-z\s''\.]+$' THEN name ELSE geounit END) AS ascii_name FROM natural_earth_countries) c
        );
      ))
    end

    task :provinces => :environment  do |t, args|
      ActiveRecord::Base.connection.execute(%(
        INSERT INTO open_places (geotype, subtype, scalerank, code, name, country_name, country_code, continent, region_un, subregion, region_wb, geom, latlng) (
          SELECT 'OpenPlaces::Province'::varchar, coalesce(type_en, p.featurecla), p.scalerank, p.postal, p.ascii_name,
          c.name, c.code, c.continent, c.region_un, c.subregion, c.region_wb,
          p.geom, p.latlng
          FROM (SELECT *, regexp_replace(coalesce(gn_name, name), '[^0-9A-Za-z\s'']+', '', 'g') AS ascii_name FROM natural_earth_provinces WHERE (gn_name IS NOT NULL OR name IS NOT NULL)) p
          LEFT OUTER JOIN open_places c ON (c.code = p.iso_a2 OR c.name = p.admin) AND c.geotype='OpenPlaces::Country'
        );
      ))
    end

    task :places => :environment  do |t, args|
      ActiveRecord::Base.connection.execute(%(
        INSERT INTO open_places (geotype, subtype, scalerank, name, country_name,country_code, province_name, geom, latlng) (
          SELECT 'OpenPlaces::Place'::varchar, pl.featurecla, pl.scalerank, pl.ascii_name, pl.adm0name, pl.iso_a2, pl.adm1name, 
          ST_Expand(pl.latlng, .1), pl.latlng
          FROM (SELECT *, regexp_replace(name, '[^0-9A-Za-z\s'']+', '', 'g') AS ascii_name FROM natural_earth_places) pl
        );
      ))
    end

    task :parks => :environment  do |t, args|
      ActiveRecord::Base.connection.execute(%(
        INSERT INTO open_places (geotype, subtype, scalerank, name, geom, latlng) (
          SELECT 'OpenPlaces::Park'::varchar, pl.unit_type,  pl.scalerank, pl.name, pl.geom, pl.latlng
          FROM natural_earth_parks pl
        );
      ))
    end

    task :rivers => :environment  do |t, args|
      ['River', 'Lake'].each do |type|
        ActiveRecord::Base.connection.execute(%(
          INSERT INTO open_places (geotype, subtype, scalerank, name, geom, latlng) (
            SELECT 'OpenPlaces::#{type}'::varchar, pl.featurecla,  pl.scalerank, pl.ascii_name, pl.geom, pl.latlng
            FROM (SELECT *, CASE WHEN name ~ 'Canal|River|Lake|Marina|Reservoir' THEN name ELSE name || ' #{type}' END AS ascii_name  FROM natural_earth_#{type.downcase}s WHERE name IS NOT NULL AND featurecla != 'Lake Centerline') pl
          );
        ))
      end
    end

    task :cleanup => :environment  do |t, args|
      file_groups.each do |type, group|
        group.each do |key, value|
          ActiveRecord::Base.connection.execute("DROP TABLE natural_earth_#{key.to_s};")
        end
      end
    end

    task :consolidate => [:countries, :provinces, :places, :parks, :rivers]
    task :all => [:download, :import, :consolidate, :cleanup]
  end

  namespace :geonames do
    task :import, [:population] => :environment  do |t, args|
      args.with_defaults(:population => '1000')
      raise "Population variable must be either 1000 or 5000, see: http://download.geonames.org/export/dump" unless ['1000','5000'].include?(args[:population])
      url = "http://download.geonames.org/export/dump/cities#{args[:population]}.zip"
      path =  "#{Rails.root}/tmp/geonames/cities#{args[:population]}"
      `curl #{url} --create-dirs -o  #{path}.zip`
      `unzip #{path}.zip`
      # Remove illformed csv characters
      `sed -i '.bak' 's/[”|"]//g' #{path}.txt`
      ActiveRecord::Base.connection.execute(%(
        DROP TABLE IF EXISTS geoname_cities; 
        CREATE TABLE geoname_cities (
          geonameid integer,
          name varchar(200),
          asciiname  varchar(200),
          alternatenames text,
          latitude decimal,
          longitude decimal,
          feature_class char(1),
          feature_code varchar(10),
          country_code char(2),
          cc2 char(200),
          admin1_code varchar(20),
          admin2_code varchar(80),
          admin3_code varchar(20),
          admin4_code varchar(20),
          population bigint,
          elevation integer,
          dem integer,
          timezone varchar(40),
          modification_date date
        );
      ))
      ActiveRecord::Base.connection.execute("COPY geoname_cities (geonameid,name, asciiname, alternatenames,latitude, longitude,feature_class,feature_code, country_code,cc2, admin1_code, admin2_code, admin3_code,admin4_code, population,elevation, dem,timezone,modification_date) FROM '#{path}.txt' DELIMITER '\t' CSV;")
    end

    task :consolidate=> :environment  do |t, args|
      ActiveRecord::Base.connection.execute(%(
        INSERT INTO open_places (geotype, subtype, scalerank, code, name, country_code, province_code, geom, latlng, latitude, longitude) (
        SELECT 'OpenPlaces::Place'::varchar AS geotype,
        'Town' AS subtype,
        12 AS scalerank,
        NULL AS code,
        g.ascii_name AS name,
        g.country_code,
        g.admin1_code,
        ST_Expand(ST_SetSRID(ST_Point(g.longitude, g.latitude),4326), .1) AS geom,
        ST_SetSRID(ST_Point(g.longitude, g.latitude),4326) AS latlng,
        g.latitude,
        g.longitude
        FROM (SELECT *, regexp_replace(name, '[^0-9A-Za-z\s'']+', '', 'g') AS ascii_name FROM geoname_cities) g
        WHERE NOT EXISTS (SELECT name, province_code, country_code FROM open_places p2 WHERE g.name = p2.name AND g.admin1_code = p2.province_code AND g.country_code = p2.country_code AND p2.geotype='OpenPlaces::Place')
      )))
    end

    task :cleanup => :environment  do |t, args|
      ActiveRecord::Base.connection.execute("DROP TABLE geoname_cities;")
    end

    task :all => [:download, :import, :consolidate, :cleanup]
  end

  namespace :csv do
    task :export => :environment  do |t, args|
      ActiveRecord::Base.connection.execute("COPY (SELECT #{(OpenPlaces::Geo.IMPORT_FIELDS).join(",")} FROM open_places WHERE subtype != 'Town') TO '#{OpenPlaces::Engine.root}/db/seeds/open_places.csv' DELIMITER '\t' NULL AS '' CSV HEADER;")
      ActiveRecord::Base.connection.execute("COPY (SELECT #{(OpenPlaces::Geo.IMPORT_FIELDS).join(",")} FROM open_places WHERE subtype = 'Town') TO '#{OpenPlaces::Engine.root}/db/seeds/open_places_towns.csv' DELIMITER '\t' NULL AS '' CSV HEADER;")
    end
  end

  task :normalize => :environment  do |t, args|
    OpenPlaces::Engine.normalize_data
    # DELETE Duplicates
    ActiveRecord::Base.connection.execute("SELECT DISTINCT ON (slug) id, slug, dups.row from (SELECT *, ROW_NUMBER() OVER(PARTITION BY slug ORDER BY slug desc) AS row FROM open_places) dups where dups.row > 1;").each do |dup|
      ActiveRecord::Base.connection.execute("DELETE from open_places WHERE slug = \'#{dup['slug']}\' AND id != #{dup['id']}")
    end
  end

  task :import => ['open_places:natural_earth:all', 'open_places:normalize', 'open_places:geonames:all', 'open_places:normalize']
  
  task :drop => :environment  do |t, args|
    ActiveRecord::Base.connection.execute("DROP INDEX open_places_id_idx, open_places_tsvector_gin, open_places_geom_gist, open_places_latlng_gist;")
    ActiveRecord::Base.connection.execute("DROP table open_places;")
  end
end