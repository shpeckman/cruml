# This consists of obtaining information about a type alias.
class Cruml::Entities::AliasInfo
  # Alias name
  getter name : String

  # Aliased type.
  property target : String

  def initialize(@name : String, @target : String); end
end
