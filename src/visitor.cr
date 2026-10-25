# src/transformer.cr

require "compiler/crystal/syntax"
require "./services/registry_service"
require "./parsers/*"
require "./entities/*"

class Cruml::Transformer < Crystal::Transformer
  include Cruml::Parsers::RegexPatterns

  getter registry : Cruml::Services::RegistryService

  @current_class_name : String
  @current_module_name : String
  @variables : Array(Crystal::TypeDeclaration)
  @protected_and_private_methods : Array(Crystal::Def)
  @module_stack : Array(String)

  def initialize(@registry : Cruml::Services::RegistryService)
    @current_class_name = ""
    @current_module_name = ""
    @module_stack = [] of String
    @variables = [] of Crystal::TypeDeclaration
    @protected_and_private_methods = [] of Crystal::Def
  end

  def transform(node : Crystal::ModuleDef) : Crystal::ASTNode
    module_name = node.name.to_s
    previous_class_name = @current_class_name
    previous_variables = @variables
    previous_methods = @protected_and_private_methods

    @module_stack << module_name
    @current_module_name = @module_stack.join("::")
    @current_class_name = ""
    @variables = [] of Crystal::TypeDeclaration
    @protected_and_private_methods = [] of Crystal::Def

    process_module(node)
    result = super(node)

    @module_stack.pop
    @current_module_name = @module_stack.join("::")
    @current_class_name = previous_class_name
    @variables = previous_variables
    @protected_and_private_methods = previous_methods

    result
  end

  def transform(node : Crystal::ClassDef) : Crystal::ASTNode
    class_name = node.name.to_s
    previous_class_name = @current_class_name
    previous_module_name = @current_module_name
    previous_variables = @variables
    previous_methods = @protected_and_private_methods

    if !@module_stack.empty?
      if class_name.includes?("::")
        name_parts = class_name.split("::")
        non_overlapping_start = 0
        @module_stack.reverse_each do |mod_part|
          if name_parts[non_overlapping_start]? == mod_part.split("::").last
            non_overlapping_start += 1
          else
            break
          end
        end
        remaining_parts = name_parts[non_overlapping_start..]
        @current_class_name = (@module_stack + remaining_parts).join("::")
      else
        @current_class_name = (@module_stack + [class_name]).join("::")
      end
    else
      @current_class_name = class_name
    end

    @current_module_name = ""
    @variables = [] of Crystal::TypeDeclaration
    @protected_and_private_methods = [] of Crystal::Def

    @module_stack << class_name
    process_class(node)
    result = super(node)
    @module_stack.pop

    @current_class_name = previous_class_name
    @current_module_name = previous_module_name
    @variables = previous_variables
    @protected_and_private_methods = previous_methods

    result
  end

  def transform(node : Crystal::VisibilityModifier) : Crystal::ASTNode
    if method = node.exp.as?(Crystal::Def)
      @protected_and_private_methods << method
      add_method_with_visibility(node.modifier, method)
    end

    super(node)
  end

  def transform(node : Crystal::Expressions) : Crystal::ASTNode
    node.expressions.each do |exp|
      process_instance_attribute(exp)
    end

    super(node)
  end

  def transform(node : Crystal::InstanceVar) : Crystal::ASTNode
    process_instance_var_node(node)
    super(node)
  end

  def transform(node : Crystal::Assign) : Crystal::ASTNode
    process_assign_node(node)
    super(node)
  end

  def transform(node : Crystal::TypeDeclaration) : Crystal::ASTNode
    if node.var.is_a?(Crystal::InstanceVar) || node.var.is_a?(Crystal::ClassVar)
      @variables |= [node]
    end

    if node.var.is_a?(Crystal::ClassVar)
      process_class_var_declaration(node)
    end

    super(node)
  end

  def transform(node : Crystal::Def) : Crystal::ASTNode
    process_def_node(node)
    super(node)
  end

  private def process_module(node : Crystal::ModuleDef) : Nil
    return if @registry.find_module(@current_module_name)

    module_type = Cruml::Parsers::ClassParser.interface?(@current_module_name) ? :interface : :normal
    module_info = Cruml::Entities::ModuleInfo.new(@current_module_name, module_type)
    @registry.add_module(module_info)
  end

  private def process_class(node : Crystal::ClassDef) : Nil
    if generics = Cruml::Parsers::ClassParser.extract_generics(node)
      @current_class_name += generics
    end

    class_type = Cruml::Parsers::ClassParser.determine_class_type(@current_class_name, node)
    class_info = @registry.find_class(@current_class_name)

    unless class_info
      class_info = Cruml::Entities::ClassInfo.new(@current_class_name, class_type)
      @registry.add_class(class_info)
    end

    if node.superclass
      parent_name = node.superclass.to_s
      qualified_parent_name = qualify_name(parent_name)

      parent_class = @registry.find_class(qualified_parent_name) || @registry.find_class(parent_name)
      parent_type = parent_class ? parent_class.type : :class
      final_parent_name = parent_class ? parent_class.name : qualified_parent_name

      unless class_info.parent_classes.any? { |parent, _, _| parent == final_parent_name }
        class_info.add_parent_class(final_parent_name, parent_type)
      end
    end

    process_includes(node)
    process_extends(node)
    process_class_vars(node)
  end

  private def process_includes(node : Crystal::ClassDef) : Nil
    includes = Cruml::Parsers::ClassParser.parse_includes(node.body.to_s)

    if found_class = @registry.find_class(@current_class_name)
      includes.each do |mod|
        qualified_mod = qualify_name(mod)

        target_mod = if @registry.find_module(qualified_mod) || @registry.find_module(mod)
                       qualified_mod
                     else
                       mod
                     end

        found_class.add_included_module(target_mod) unless found_class.included_modules.includes?(target_mod)
      end
    end
  end

  private def process_extends(node : Crystal::ClassDef) : Nil
    extends = Cruml::Parsers::ClassParser.parse_extends(node.body.to_s)

    if found_class = @registry.find_class(@current_class_name)
      extends.each do |mod|
        qualified_mod = qualify_name(mod)

        target_mod = if @registry.find_module(qualified_mod) || @registry.find_module(mod)
                       qualified_mod
                     else
                       mod
                     end

        found_class.add_extended_module(target_mod) unless found_class.extended_modules.includes?(target_mod)
      end
    end
  end

  private def process_class_vars(node : Crystal::ClassDef) : Nil
    return unless class_var = Cruml::Parsers::VariableParser.parse_class_attribute(node.body.to_s)

    found_class = @registry.find_class(@current_class_name)
    return unless found_class

    found_class.add_class_var("@@#{class_var[:name]}", class_var[:type])

    if VisibilityHelpers.has_class_getter?(class_var[:visibility])
      method = Cruml::Entities::MethodInfo.new(:public, class_var[:name], class_var[:type])
      found_class.add_method(method)
    end

    if VisibilityHelpers.has_class_setter?(class_var[:visibility])
      method = Cruml::Entities::MethodInfo.new(:public, "#{class_var[:name]}=", class_var[:type])
      found_class.add_method(method)
    end
  end

  private def process_class_var_declaration(node : Crystal::TypeDeclaration) : Nil
    return unless node.var.is_a?(Crystal::ClassVar)

    var_name = node.var.as(Crystal::ClassVar).name
    var_type = node.declared_type.to_s

    if found_class = @registry.find_class(@current_class_name)
      found_class.add_class_var(var_name, var_type)
    end
  end

  private def add_method_with_visibility(modifier : Crystal::Visibility, method : Crystal::Def) : Nil
    visibility = Cruml::Parsers::MethodParser.visibility_from_modifier(modifier)
    method_name = Cruml::Parsers::MethodParser.format_method_name(method)
    return_type = Cruml::Parsers::MethodParser.get_return_type(method)

    method_info = Cruml::Entities::MethodInfo.new(visibility, method_name, return_type)
    Cruml::Parsers::MethodParser.add_arguments(method, method_info)

    if @current_module_name.empty?
      if found_class = @registry.find_class(@current_class_name)
        found_class.add_method(method_info)
      end
    else
      if found_module = @registry.find_module(@current_module_name)
        found_module.add_method(method_info)
      end
    end
  end

  private def process_instance_attribute(exp) : Nil
    return unless attr = Cruml::Parsers::VariableParser.parse_instance_attribute(exp.to_s)

    found_class = @registry.find_class(@current_class_name)
    return unless found_class

    found_class.add_instance_var("@#{attr[:name]}", attr[:type])

    if VisibilityHelpers.has_getter?(attr[:visibility])
      found_class.add_method(Cruml::Entities::MethodInfo.new(:public, attr[:name], attr[:type]))
    end

    if VisibilityHelpers.has_setter?(attr[:visibility])
      found_class.add_method(Cruml::Entities::MethodInfo.new(:public, "#{attr[:name]}=", attr[:type]))
    end
  end

  private def process_instance_var_node(node : Crystal::InstanceVar) : Nil
    ivar_name = node.name.to_s

    @variables.each do |variable|
      var_name = variable.var.to_s
      var_type = variable.declared_type.to_s

      next unless var_name == ivar_name

      if @current_module_name.empty?
        if found_class = @registry.find_class(@current_class_name)
          found_class.add_instance_var(var_name, var_type)
        end
      else
        if found_module = @registry.find_module(@current_module_name)
          found_module.add_instance_var(var_name, var_type)
        end
      end
    end
  end

  private def process_assign_node(node : Crystal::Assign) : Nil
    return unless node.target.is_a?(Crystal::InstanceVar)

    target_name = node.target.to_s

    @variables.each do |var|
      if target_name == var.var.to_s
        clean_type = var.declared_type.to_s.gsub(" ::", ' ')

        if found_class = @registry.find_class(@current_class_name)
          found_class.add_instance_var(target_name, clean_type)
        end
      end
    end
  end

  private def process_def_node(node : Crystal::Def) : Nil
    return if method_already_processed?(node)

    process_constructor_assignments(node)
    process_method_body_vars(node)
    add_public_method(node)
  end

  private def method_already_processed?(node : Crystal::Def) : Bool
    @protected_and_private_methods.any?(&.same?(node))
  end

  private def process_constructor_assignments(node : Crystal::Def) : Nil
    node.args.each do |arg|
      next unless restriction = arg.restriction
      arg_name = arg.name.to_s

      node.body.to_s.each_line do |line|
        if ivar_name = Cruml::Parsers::VariableParser.parse_instance_var_assignment(line, arg_name)
          if found_class = @registry.find_class(@current_class_name)
            found_class.add_instance_var("@#{ivar_name}", restriction.to_s)
          end
        end
      end
    end
  end

  private def process_method_body_vars(node : Crystal::Def) : Nil
    return unless var_decl = Cruml::Parsers::VariableParser.parse_instance_var_declaration(node.body.to_s)

    if found_class = @registry.find_class(@current_class_name)
      found_class.add_instance_var("@#{var_decl[:name]}", var_decl[:type])
    end
  end

  private def add_public_method(node : Crystal::Def) : Nil
    visibility = Cruml::Parsers::MethodParser.determine_visibility(node.name.to_s)
    method_name = Cruml::Parsers::MethodParser.format_method_name(node)
    return_type = Cruml::Parsers::MethodParser.get_return_type(node)

    method_info = Cruml::Entities::MethodInfo.new(visibility, method_name, return_type)
    Cruml::Parsers::MethodParser.add_arguments(node, method_info)

    if @current_module_name.empty?
      if found_class = @registry.find_class(@current_class_name)
        found_class.add_method(method_info)
      end
    else
      if found_module = @registry.find_module(@current_module_name)
        found_module.add_method(method_info)
      end
    end
  end

  private def qualify_name(name : String) : String
    return name if @module_stack.empty?
    return name if name.empty?

    stack_parts = @module_stack.flat_map(&.split("::"))
    name_parts = name.split("::")

    if name.starts_with?(stack_parts.join("::"))
      return name
    end

    overlap = 0

    stack_parts.reverse_each do |stack_part|
      if name_parts[overlap]? == stack_part
        overlap += 1
      else
        break if overlap > 0
      end
    end

    if overlap > 0
      remaining_name_parts = name_parts[overlap..]
      (stack_parts + remaining_name_parts).join("::")
    else
      (stack_parts + name_parts).join("::")
    end
  end
end

