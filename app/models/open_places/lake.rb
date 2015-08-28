module OpenPlaces
  class Lake < Geo
    belongs_to :province
    belongs_to :country
  end
end