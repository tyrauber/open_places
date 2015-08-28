module OpenPlaces
  class River < Geo
    belongs_to :province
    belongs_to :country
  end
end