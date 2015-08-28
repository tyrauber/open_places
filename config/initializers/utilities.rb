class String
  def toLngLat
    self.split(",").reverse.join(",")
  end
end