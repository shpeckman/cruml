require "compiler/crystal/syntax"

# Parses class-specific information from Crystal AST
module Cruml::Parsers::ClassParser
  extend self

  # Determines the class type (interface, abstract, or normal class)
  def determine_class_type(class_name : String, node : Crystal::ClassDef) : Symbol
    if interface?(class_name)
      :interface
    else
      node.abstract? ? :abstract : :class
    end
  end

  # Extracts generic type parameters from a class definition
  def extract_generics(node : Crystal::ClassDef) : String?
    if type_vars = node.type_vars
      "(#{type_vars.join(", ")})"
    end
  end

  # Returns the name of a type referenced by an `include`, `extend` or superclass node,
  # or `nil` when it is not a type name (e.g. `extend self`).
  def reference_name(node : Crystal::ASTNode) : String?
    case node
    when Crystal::Path, Crystal::Generic then node.to_s
    end
  end

  # Determines if a class name represents an interface
  def interface?(name : String) : Bool
    name.downcase.ends_with?("interface")
  end
end
