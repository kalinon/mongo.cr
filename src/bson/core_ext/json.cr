struct JSON::Any
  def to_bson
    case raw = self.raw
    when Nil
      raw
    when Bool
      raw
    when Int64
      raw
    when Float64
      raw
    when String
      raw
    else
      BSON.from_json self.to_json
    end
  end

  def self.from_bson(bson : BSON::Field) : self
    case bson
    when Nil
      self.new bson
    when Bool
      self.new bson
    when Int64
      self.new bson
    when Float64
      self.new bson
    when String
      self.new bson
    when BSON
      JSON.parse(bson.to_json).dup
    else
      raise "invalid bson"
    end
  end
end
