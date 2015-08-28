module OpenPlaces
  class Province < Geo
    self.table_name = 'open_places'
    has_many :cities, -> { where(type: 'OpenPlaces::Province') }, foreign_key: :province_name, primary_key: :name
  end
end