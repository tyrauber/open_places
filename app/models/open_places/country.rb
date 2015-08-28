module OpenPlaces
  class Country < Geo
    has_many :cities, -> { where(type: 'OpenPlaces::City') }, foreign_key: :country_code, primary_key: :country_code
    has_many :provinces, -> { where(type: 'OpenPlaces::Province') }, foreign_key: :name, primary_key: :province_name
  end
end