# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150825172133) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "postgis"

  create_table "open_places", force: :cascade do |t|
    t.string   "geotype"
    t.string   "subtype"
    t.float    "scalerank"
    t.string   "code"
    t.string   "name"
    t.string   "short_name"
    t.string   "long_name"
    t.string   "country_name"
    t.string   "country_code"
    t.string   "province_name"
    t.string   "province_code"
    t.string   "continent"
    t.string   "region_un"
    t.string   "subregion"
    t.string   "region_wb"
    t.float    "latitude",                                               default: 0.0
    t.float    "longitude",                                              default: 0.0
    t.float    "x_min",                                                  default: 0.0
    t.float    "y_min",                                                  default: 0.0
    t.float    "x_max",                                                  default: 0.0
    t.float    "y_max",                                                  default: 0.0
    t.geometry "latlng",        limit: {:srid=>4326, :type=>"geometry"}
    t.geometry "geom",          limit: {:srid=>4326, :type=>"geometry"}
    t.geometry "bbox",          limit: {:srid=>4326, :type=>"geometry"}
    t.tsvector "tsvector"
    t.float    "area",                                                   default: 0.0
    t.string   "slug"
    t.string   "path"
  end

  add_index "open_places", ["bbox"], name: "open_places_bbox_gist", using: :gist
  add_index "open_places", ["geom"], name: "open_places_geom_gist", using: :gist
  add_index "open_places", ["geotype"], name: "open_places_geotype", using: :btree
  add_index "open_places", ["latlng"], name: "open_places_latlng_gist", using: :gist
  add_index "open_places", ["path"], name: "open_places_path", using: :btree
  add_index "open_places", ["slug"], name: "open_places_slug", using: :btree
  add_index "open_places", ["tsvector"], name: "open_places_tsvector_gin", using: :gin

end
