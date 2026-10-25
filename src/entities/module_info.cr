require "./members"

# This consists of obtaining information about module.
class Cruml::Entities::ModuleInfo
  include Cruml::Entities::Members

  # Module name
  getter name : String

  # Module type (`:normal` or `:interface`).
  getter type : Symbol

  def initialize(@name : String, @type : Symbol = :normal); end

  def kind_label : String
    "module"
  end
end
