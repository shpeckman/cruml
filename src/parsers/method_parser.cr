# src/parsers/method_parser.cr

require "../entities/method_info"
require "../entities/arg_info"

module Cruml::Parsers::MethodParser
  extend self

  def add_arguments(node : Crystal::Def, method : Cruml::Entities::MethodInfo) : Nil
    node.args.each do |arg|
      restriction = arg.restriction
      next unless restriction

      arg_name = arg.name.to_s
      arg_type = type_name(restriction)

      if default_value = arg.default_value
        arg_type = "#{arg_type} = #{default_value}"
      end

      method.add_arg(Cruml::Entities::ArgInfo.new(arg_name, arg_type))
    end
  end

  def determine_visibility(method_name : String, modifier : Crystal::Visibility? = nil) : Symbol
    return visibility_from_modifier(modifier) if modifier

    method_name == "initialize" ? :protected : :public
  end

  def visibility_from_modifier(modifier : Crystal::Visibility) : Symbol
    case modifier
    when Crystal::Visibility::Protected then :protected
    when Crystal::Visibility::Private   then :private
    else                                     :public
    end
  end

  def format_method_name(node : Crystal::Def) : String
    node.receiver ? "self.#{node.name}" : node.name.to_s
  end

  def get_return_type(node : Crystal::Def) : String
    node.return_type.try { |return_type| type_name(return_type) } || "Nil"
  end

  # Returns the name of a type as written in the source, `String | ::Nil` being shortened to `String?`.
  def type_name(node : Crystal::ASTNode) : String
    if node.is_a?(Crystal::Union)
      types = node.types.reject { |type| type.is_a?(Crystal::Path) && type.names == ["Nil"] }
      return "#{type_name(types.first)}?" if types.size == 1 && node.types.size == 2
    end

    node.to_s.gsub(" ::", ' ')
  end
end
