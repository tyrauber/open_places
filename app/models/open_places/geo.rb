module OpenPlaces
  class Geo < ActiveRecord::Base

    self.table_name = 'open_places'
    self.primary_key = :id
    self.inheritance_column = 'geotype'

    validates :name, presence: { scope: [:latitude, :longitude]}
    validates :long_name, :slug, :path,  presence: true, uniqueness: true
    validates :name, presence: true, uniqueness: { scope: [:province_name, :country_name ]}

    before_validation :geocode_record
    before_validation :validate_country_name
    before_validation :validate_province_name
    before_validation :set_postgres_columns

    geocoded_by :long_name do |obj,results|
      if geo = results.first
        parse_geocode_results(obj, geo)
      end
    end

    reverse_geocoded_by :latitude, :longitude do |obj,results|
      if geo = results.first
        parse_geocode_results(obj, geo, false)
      end
    end

    def geocode_record
      if latitude_changed? && longitude_changed?
        reverse_geocode
      elsif long_name_changed?
        geocode
      end
    end 

    def self.FIELDS
      @fields ||= ["id","geotype", "subtype", "scalerank", "code", "name", "short_name", "long_name",
      "country_name", "country_code", "province_name", "province_code", "continent", "region_un", "subregion", "region_wb",
      "latitude", "longitude", "x_min", "y_min", "x_max", "y_max", "bbox","latlng", "geom", "tsvector","area", "slug", "path"]
    end

    def self.GEO_FIELDS
      @geofields ||= ['geom', 'latlng', 'bbox', 'x_min', 'y_min', 'x_max', 'y_max', 'tsvector']
    end

    def self.IMPORT_FIELDS
      @import_fields ||= self.FIELDS - ['geom', 'latlng', 'bbox', 'id', 'short_name', 'long_name', 'slug', 'path']
    end

    scope :autocomplete, -> (string='', op='q', field='name', query=self.all) {
      return [] unless string.present?
      if op == 'q'
        return where("#{table_name}.#{field} = '#{string}'")
      elsif op == 'like'
        string = string.gsub(/\'/, "''").gsub(/\,/, "")
        return where("#{table_name}.tsvector @@ to_tsquery(replace(quote_literal('#{string}'), '\s', '&')||':*') ").order("similarity(#{table_name}.name, '#{string}') DESC, ts_rank(tsvector, to_tsquery(replace(quote_literal('#{string}'), ' ', '&')||':*')) DESC")
      elsif op == 'starts'
        return where("#{table_name}.#{field} LIKE '#{string}%'")
      elsif op == 'ends'
        return where("#{table_name}.#{field} LIKE '%#{string}'")
      else
        return where("#{table_name}.#{field} LIKE '%#{string}%'")
      end
    }

    scope :near, -> (here=false, query=self.all){
      return query unless here
      select("*,round(cast((ST_Distance_Sphere(latlng, ST_SetSRID(ST_MakePoint(#{here.toLngLat}), 4326))*0.000621371) AS NUMERIC),2) AS distance").order("latlng <-> st_setsrid(st_makepoint(#{here.toLngLat}),4326) ASC")
    }

    scope :within, -> (here=false, within='5', query=self.all){
      return query unless here
      where("ST_DWithin(latlng, ST_SetSRID(ST_MakePoint(#{here.toLngLat}), 4326), #{within})")
    }

    scope :to_geojson, -> (field="geom", query=self.all) {
      properties = (self.FIELDS-["tsvector","geom","latlng", "bbox"]).join(",")
      connection.execute(
        %(SELECT row_to_json(fc) AS geojson
          FROM (
            SELECT 'FeatureCollection' As type, array_to_json(array_agg(f)) As features
            FROM (
              SELECT 'Feature' As type, lg.area, lg.scalerank, lg.tsvector, ST_AsGeoJSON(lg.#{field})::json As geometry, row_to_json(op) As properties
              FROM (#{query.to_sql}) AS lg INNER JOIN (SELECT #{properties} FROM open_places) AS op ON op.id = lg.id
            ) As f
        )  As fc;)
      )
    }

    protected

    def self.parse_geocode_results(obj, geo, latlng=true)
      ['latitude', 'longitude'].each do |k|
        obj[k] = geo.send(k) if geo.respond_to?(k)
      end if !!(latlng)
      obj['country_name'] = geo.send('country')
      obj['country_code'] = geo.send('country_code')
      obj['province_name'] = geo.send('state')
      obj['province_code'] = geo.send('state_code')
      city_components = [
        geo.address_components_of_type('point_of_interest'),
        geo.address_components_of_type('establishment'),
        geo.address_components_of_type('locality'),
        geo.address_components_of_type('political')
      ]
      city = city_components.try(:flatten).try(:first)["long_name"] rescue nil
      obj['name'] =  city || geo.send('city') || obj['province_name'] || obj['country_name']
      obj['short_name'] = obj['country_code'] == 'US' ? [obj['name'],obj['province_name']].join(", ") : [obj['name'],obj['country_name']].join(", ")
      obj['scalerank'] ||= 12
      obj['geotype'] ||= 'OpenPlaces::Place'
      obj['subtype'] ||= 'Town'
      return obj
    end

    def validate_country_name
      country = Country.autocomplete(country_name)
      if country.empty?
        raise "Country #{country_name} not found"
      else
        country = country.first
        self.country_name = country.name
        self.country_code = country.code
        self.continent  = country.continent
        self.region_un = country.region_un
        self.subregion = country.subregion
        self.region_wb = country.region_wb
      end
    end

    def validate_province_name
      province = Province.autocomplete(province_name)
      if province.empty?
        raise "Province #{province_name} not found"
      else
        province = province.first
        self.province_name = province.name
        self.province_code = province.code
      end
    end

    def set_postgres_columns
      results = ActiveRecord::Base.connection.execute(%(
        SELECT ST_SetSRID(ST_Point(#{latitude}, #{longitude}),4326) AS latlng, 
        ST_Expand(ST_SetSRID(ST_Point(#{longitude}, #{latitude}),4326), .1) AS geom,
        ST_Envelope(ST_Expand(ST_SetSRID(ST_Point(#{longitude}, #{latitude}),4326), .1)) AS bbox,
        ST_XMin(ST_Expand(ST_SetSRID(ST_Point(#{longitude}, #{latitude}),4326), .1)) AS x_min, 
        ST_YMin(ST_Expand(ST_SetSRID(ST_Point(#{longitude}, #{latitude}),4326), .1)) AS y_min,
        ST_XMax(ST_Expand(ST_SetSRID(ST_Point(#{longitude}, #{latitude}),4326), .1)) AS x_max,
        ST_YMax(ST_Expand(ST_SetSRID(ST_Point(#{longitude}, #{latitude}),4326), .1)) AS y_max,
        ST_Area(ST_Expand(ST_SetSRID(ST_Point(#{longitude}, #{latitude}),4326), .1)) AS area,
        concat_ws(' ', concat_ws(', ', '#{name}', '#{province_name}'), '#{country_name}') AS long_name,
        setweight(to_tsvector('#{name}'), 'A') || setweight(to_tsvector('#{province_name}'), 'B') || setweight(to_tsvector('#{country_name}'), 'C') AS tsvector,
        regexp_replace(trim(regexp_replace(lower(concat_ws('-', '#{name}', '#{province_name}', '#{country_name}')), '[^0-9a-z/]+', ' ', 'g')), '[ ]+', '-', 'g') AS slug,
        regexp_replace(trim(regexp_replace(lower(concat_ws('/', '#{country_name}', '#{province_name}', '#{name}')), '[^0-9a-z/]+', ' ', 'g')), '[ ]+', '-', 'g') AS path
      ))
      results.first.each do |k,v|
        self.send("#{k}=", v)
      end if results.try(:first)
    end
  end
end
