require "compiler/crystal/syntax"
require "./method_parser"

# Parses variable declarations from the Crystal AST.
module Cruml::Parsers::VariableParser
  extend self

  # Accessor macros, which also exist with a `class_` prefix.
  ACCESSOR_MACROS = %w[getter getter? getter! property property? property! setter]

  # A variable declared through an accessor macro such as `property name : String`.
  record Accessor, macro_name : String, name : String, type : String?, class_level : Bool do
    # Variable name, with its `@` or `@@` sigil.
    def var_name : String
      (class_level ? "@@" : "@") + name
    end

    # Type of the underlying variable; `getter!` and `property!` make it nilable.
    def var_type : String?
      type.try { |var_type| nilable? ? "#{var_type}?" : var_type }
    end

    def getter? : Bool
      macro_name != "setter"
    end

    def setter? : Bool
      macro_name.starts_with?("property") || macro_name == "setter"
    end

    # `getter?` and `property?` define a `name?` method.
    def predicate? : Bool
      macro_name.ends_with?('?')
    end

    # `getter!` and `property!` define a raising `name` method and a nilable `name?` method.
    def nilable? : Bool
      macro_name.ends_with?('!')
    end
  end

  # Returns the accessors declared by a `getter`, `property` or `setter` macro call (or their
  # `class_` variants), or `nil` when the call is something else.
  def parse_accessors(call : Crystal::Call) : Array(Accessor)?
    return if call.obj

    class_level = call.name.starts_with?("class_")
    macro_name = call.name.lchop("class_")
    return unless ACCESSOR_MACROS.includes?(macro_name)

    call.args.compact_map do |arg|
      name, type = case arg
                   when Crystal::TypeDeclaration then {arg.var.to_s, Cruml::Parsers::MethodParser.type_name(arg.declared_type)}
                   when Crystal::Assign          then {arg.target.to_s, infer_type(arg.value)}
                   when Crystal::Var, Crystal::Call
                     {arg.name, nil}
                   when Crystal::SymbolLiteral, Crystal::StringLiteral
                     {arg.value, nil}
                   else
                     next
                   end

      Accessor.new(macro_name, name, type, class_level)
    end
  end

  # Infers the type of a literal value (`0_i64`, `"text"`, `[] of String`, `Foo.new`, ...),
  # or returns `nil` when it cannot be known without the compiler.
  def infer_type(node : Crystal::ASTNode) : String?
    case node
    when Crystal::StringLiteral, Crystal::StringInterpolation then "String"
    when Crystal::NumberLiteral                               then number_type(node.kind.to_s)
    when Crystal::BoolLiteral                                 then "Bool"
    when Crystal::CharLiteral                                 then "Char"
    when Crystal::SymbolLiteral                               then "Symbol"
    when Crystal::NilLiteral                                  then "Nil"
    when Crystal::ArrayLiteral
      node.of.try { |of| "Array(#{of})" }
    when Crystal::HashLiteral
      node.of.try { |of| "Hash(#{of.key}, #{of.value})" }
    when Crystal::Call
      node.obj.try(&.to_s) if node.name == "new"
    end
  end

  # Converts a number literal kind (`i32`, `u8`, `f64`, ...) into its type name.
  private def number_type(kind : String) : String
    case kind[0]
    when 'u' then "UInt#{kind[1..]}"
    when 'f' then "Float#{kind[1..]}"
    else          "Int#{kind[1..]}"
    end
  end
end
