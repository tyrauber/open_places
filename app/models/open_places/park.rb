module OpenPlaces
  class Park < Geo
    default_scope -> { where(type: 'OpenPlaces::Place')}
    belongs_to :province
    belongs_to :country
  end
end