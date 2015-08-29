module OpenPlaces
  class Geo < ActiveRecord::Base

    self.table_name = 'open_places'
    self.primary_key = :id
    self.inheritance_column = 'geotype'

    include Concerns::ReadOnlyModel

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
        return where("#{table_name}.tsvector @@ to_tsquery(replace(quote_literal('#{string}'), '\s', '&')||':*')").order("to_tsquery(replace(quote_literal('#{string}'), '\s', '&')||':*') DESC")
      elsif op == 'starts'
        return where("#{table_name}.#{field} LIKE '#{string}%'")
      elsif op == 'ends'
        return where("#{table_name}.#{field} LIKE '%#{string}'")
      else
        return where("#{table_name}.#{field} LIKE '%#{string}%'")
      end
    }

    scope :near, -> (here=false, within='5', query=self.all){
      return query unless here
      select("*,round(cast((ST_Distance_Sphere(latlng, ST_SetSRID(ST_MakePoint(#{here.toLngLat}), 4326))*0.000621371) AS NUMERIC),2) AS distance").order("latlng <-> st_setsrid(st_makepoint(#{here.toLngLat}),4326) ASC")
    }

    scope :ordered, -> (query=self.all){
      order('scalerank ASC')
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
  end
end
