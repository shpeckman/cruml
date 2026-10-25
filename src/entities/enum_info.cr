require "./members"

# This consists of obtaining information about an enum.
class Cruml::Entities::EnumInfo
  include Cruml::Entities::Members

  # Enum name
  getter name : String

  # Underlying integer type (e.g. `UInt8`), if specified.
  getter base_type : String?

  # Enum constants with their explicit value, if any.
  getter constants = [] of Tuple(String, String?)

  def initialize(@name : String, @base_type : String? = nil); end

  def kind_label : String
    "enum"
  end

  # Adds a constant to the enum.
  def add_constant(name : String, value : String? = nil) : Nil
    @constants.reject! { |constant| constant[0] == name }
    @constants << {name, value}

    if Cruml::Renders::Config.verbose?
      puts "VERBOSE : #{name.colorize(:magenta)} constant added to #{@name.colorize(:magenta)} enum."
    end
  end
end
