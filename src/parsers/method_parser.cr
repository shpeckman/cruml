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
      arg_type = restriction.to_s.gsub(" ::", ' ')

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
    node.return_type.to_s.presence || "Nil"
  end
end

