class CreateOpenPlaces < ActiveRecord::Migration
  def up
    ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS postgis;")
    create_table(:open_places) do |t|
      t.string :geotype
      t.string :subtype
      t.float :scalerank
      t.string :code
      t.string :name
      t.string :short_name
      t.string :long_name
      t.string :country_name
      t.string :country_code
      t.string :province_name
      t.string :province_code
      t.string :continent
      t.string :region_un
      t.string :subregion
      t.string :region_wb
      t.float :latitude, default: 0.0
      t.float :longitude, default: 0.0
      t.float :x_min, default: 0.0
      t.float :y_min, default: 0.0
      t.float :x_max, default: 0.0
      t.float :y_max, default: 0.0
      t.geometry :latlng, srid: 4326
      t.geometry :geom, srid: 4326
      t.geometry :bbox, srid: 4326
      t.column :tsvector, 'tsvector'
      t.float :area, default: 0.0
      t.string :slug
      t.string :path
    end
    ActiveRecord::Base.connection.execute("COPY open_places (#{(OpenPlaces::Geo.IMPORT_FIELDS).join(",")}) FROM '#{OpenPlaces::Engine.root}/db/seeds/open_places.csv' DELIMITER '\t' CSV HEADER;")
    ActiveRecord::Base.connection.execute("COPY open_places (#{(OpenPlaces::Geo.IMPORT_FIELDS).join(",")}) FROM '#{OpenPlaces::Engine.root}/db/seeds/open_places_towns.csv' DELIMITER '\t' CSV HEADER;")
    OpenPlaces::Engine.normalize_data

    add_index :open_places, :geotype, name: 'open_places_geotype'
    add_index :open_places, :slug, name: 'open_places_slug'
    add_index :open_places, :path, name: 'open_places_path'
    add_index :open_places, :latlng, name: 'open_places_latlng_gist', using: :gist
    add_index :open_places, :geom, name: 'open_places_geom_gist', using: :gist
    add_index :open_places, :bbox, name: 'open_places_bbox_gist', using: :gist
    add_index :open_places, :tsvector, name: 'open_places_tsvector_gin', using: :gin
  end
  
  def down
    remove_index :open_places, name: 'open_places_geotype'
    remove_index :open_places, name: 'open_places_slug'
    remove_index :open_places, name: 'open_places_path'
    remove_index :open_places, name: 'open_places_latlng_gist'
    remove_index :open_places, name: 'open_places_geom_gist'
    remove_index :open_places, name: 'open_places_bbox_gist'
    remove_index :open_places, name: 'open_places_tsvector_gin'
    drop_table :open_places
  end
end