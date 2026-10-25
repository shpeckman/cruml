require "./members"

# This consists of obtaining information about a class or a struct.
class Cruml::Entities::ClassInfo
  include Cruml::Entities::Members

  # Class name
  getter name : String

  # Class type (`:class`, `:abstract` or `:interface`).
  getter type : Symbol

  # Whether this is a `class` or a `struct`.
  getter kind : Symbol

  # Parent class name.
  getter superclass : String?

  def initialize(@name : String, @type : Symbol, @kind : Symbol = :class); end

  def struct? : Bool
    @kind == :struct
  end

  def kind_label : String
    @kind.to_s
  end

  # Links the class to its parent class.
  def superclass=(parent_class_name : String) : String
    @superclass = parent_class_name

    if Cruml::Renders::Config.verbose?
      puts "VERBOSE : #{@name.colorize(:magenta)} child #{kind_label} linked to #{parent_class_name.colorize(:magenta)} parent class."
    end

    parent_class_name
  end
end
