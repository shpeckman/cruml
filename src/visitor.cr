# src/visitor.cr

require "compiler/crystal/syntax"
require "./services/registry_service"
require "./parsers/*"
require "./entities/*"

# Walks the AST of a Crystal file and records the types it declares into the registry.
#
# References to other types (superclasses, mixins, alias targets) are stored as written;
# `RegistryService#resolve_references` qualifies them once every file has been visited.
class Cruml::Visitor < Crystal::Visitor
  getter registry : Cruml::Services::RegistryService

  # Fully qualified names of the enclosing namespaces, innermost last.
  @scopes = [] of String

  # Type receiving the members being visited.
  @owner : Cruml::Entities::Members?

  # Method whose body is being visited.
  @current_def : Crystal::Def?

  def initialize(@registry : Cruml::Services::RegistryService); end

  def visit(node : Crystal::ASTNode) : Bool
    true
  end

  def visit(node : Crystal::ModuleDef) : Bool
    name = qualify_definition(node.name)

    module_info = @registry.find_module(name) || begin
      module_type = Cruml::Parsers::ClassParser.interface?(name) ? :interface : :normal
      Cruml::Entities::ModuleInfo.new(name, module_type).tap { |info| @registry.add_module(info) }
    end

    within(name, module_info) { node.body.accept(self) }
    false
  end

  def visit(node : Crystal::ClassDef) : Bool
    base_name = qualify_definition(node.name)
    name = base_name + (Cruml::Parsers::ClassParser.extract_generics(node) || "")

    class_info = @registry.find_class(name) || begin
      class_type = Cruml::Parsers::ClassParser.determine_class_type(name, node)
      kind = node.struct? ? :struct : :class
      Cruml::Entities::ClassInfo.new(name, class_type, kind).tap { |info| @registry.add_class(info) }
    end

    if superclass = node.superclass.try { |parent| Cruml::Parsers::ClassParser.reference_name(parent) }
      class_info.superclass = superclass unless class_info.superclass
    end

    within(base_name, class_info) { node.body.accept(self) }
    false
  end

  def visit(node : Crystal::EnumDef) : Bool
    name = qualify_definition(node.name)

    enum_info = @registry.find_enum(name) || begin
      Cruml::Entities::EnumInfo.new(name, node.base_type.try(&.to_s)).tap { |info| @registry.add_enum(info) }
    end

    within(name, enum_info) do
      node.members.each do |member|
        if member.is_a?(Crystal::Arg)
          enum_info.add_constant(member.name, member.default_value.try(&.to_s))
        else
          member.accept(self)
        end
      end
    end

    false
  end

  def visit(node : Crystal::AnnotationDef) : Bool
    @registry.add_annotation(Cruml::Entities::AnnotationInfo.new(qualify_definition(node.name)))
    false
  end

  def visit(node : Crystal::Alias) : Bool
    @registry.add_alias(Cruml::Entities::AliasInfo.new(qualify_definition(node.name), node.value.to_s))
    false
  end

  def visit(node : Crystal::Include) : Bool
    if name = Cruml::Parsers::ClassParser.reference_name(node.name)
      @owner.try &.add_included_module(name)
    end

    false
  end

  def visit(node : Crystal::Extend) : Bool
    if name = Cruml::Parsers::ClassParser.reference_name(node.name)
      @owner.try &.add_extended_module(name)
    end

    false
  end

  def visit(node : Crystal::VisibilityModifier) : Bool
    visibility = Cruml::Parsers::MethodParser.visibility_from_modifier(node.modifier)

    case exp = node.exp
    when Crystal::Def  then process_def(exp, visibility)
    when Crystal::Call then process_accessors(exp, visibility)
    else                    exp.accept(self)
    end

    false
  end

  def visit(node : Crystal::Def) : Bool
    process_def(node, Cruml::Parsers::MethodParser.determine_visibility(node.name))
    false
  end

  def visit(node : Crystal::Call) : Bool
    # Calls inside a method body may contain blocks assigning instance variables.
    return true if @current_def

    process_accessors(node, :public)
    false
  end

  def visit(node : Crystal::TypeDeclaration) : Bool
    return false unless owner = @owner

    case var = node.var
    when Crystal::InstanceVar then owner.add_instance_var(var.name, Cruml::Parsers::MethodParser.type_name(node.declared_type))
    when Crystal::ClassVar    then owner.add_class_var(var.name, Cruml::Parsers::MethodParser.type_name(node.declared_type))
    end

    false
  end

  def visit(node : Crystal::Assign) : Bool
    return true unless (owner = @owner) && (current_def = @current_def)
    return true unless (target = node.target).is_a?(Crystal::InstanceVar)
    return true if owner.instance_var?(target.name)

    if type = assigned_type(node.value, current_def)
      owner.add_instance_var(target.name, type)
    end

    true
  end

  def visit(node : Crystal::Macro | Crystal::LibDef) : Bool
    false
  end

  # Visits a type body with the given namespace and owner, then restores the previous ones.
  private def within(scope : String, owner : Cruml::Entities::Members, &) : Nil
    previous_owner = @owner
    @scopes << scope
    @owner = owner

    yield
  ensure
    @scopes.pop
    @owner = previous_owner
  end

  # Returns the fully qualified name of a type defined in the current namespace.
  #
  # A path starting with the name of an enclosing namespace (`Cruml::Foo` inside `module Cruml`)
  # is anchored on it instead of being nested once more.
  private def qualify_definition(path : Crystal::Path) : String
    names = path.names
    return names.join("::") if path.global?

    scope_parts = (@scopes.last? || "").split("::").reject(&.empty?)

    if names.size > 1 && (anchor = scope_parts.rindex(names.first))
      (scope_parts[0, anchor] + names).join("::")
    else
      (scope_parts + names).join("::")
    end
  end

  private def process_def(node : Crystal::Def, visibility : Symbol) : Nil
    return unless owner = @owner

    method_name = Cruml::Parsers::MethodParser.format_method_name(node)
    return_type = Cruml::Parsers::MethodParser.get_return_type(node)

    method_info = Cruml::Entities::MethodInfo.new(visibility, method_name, return_type)
    Cruml::Parsers::MethodParser.add_arguments(node, method_info)
    owner.add_method(method_info)

    @current_def = node
    node.body.accept(self)
  ensure
    @current_def = nil
  end

  private def process_accessors(node : Crystal::Call, visibility : Symbol) : Nil
    return unless owner = @owner
    return unless accessors = Cruml::Parsers::VariableParser.parse_accessors(node)

    accessors.each do |accessor|
      if var_type = accessor.var_type
        if accessor.class_level
          owner.add_class_var(accessor.var_name, var_type)
        else
          owner.add_instance_var(accessor.var_name, var_type)
        end
      end

      prefix = accessor.class_level ? "self." : ""
      type = accessor.type || ""

      if accessor.getter?
        getter_name = accessor.predicate? ? "#{accessor.name}?" : accessor.name
        owner.add_method(Cruml::Entities::MethodInfo.new(visibility, prefix + getter_name, type))

        if accessor.nilable?
          owner.add_method(Cruml::Entities::MethodInfo.new(visibility, "#{prefix}#{accessor.name}?", accessor.var_type || ""))
        end
      end

      if accessor.setter?
        setter = Cruml::Entities::MethodInfo.new(visibility, "#{prefix}#{accessor.name}=", type)
        setter.add_arg(Cruml::Entities::ArgInfo.new("value", type)) unless type.empty?
        owner.add_method(setter)
      end
    end
  end

  # Returns the type of a value assigned to an instance variable inside a method: the
  # restriction (or default value) of the method argument it comes from, or the literal type.
  private def assigned_type(value : Crystal::ASTNode, current_def : Crystal::Def) : String?
    if value.is_a?(Crystal::Var) && (arg = current_def.args.find { |def_arg| def_arg.name == value.name })
      if restriction = arg.restriction
        return Cruml::Parsers::MethodParser.type_name(restriction)
      end

      return arg.default_value.try { |default_value| Cruml::Parsers::VariableParser.infer_type(default_value) }
    end

    Cruml::Parsers::VariableParser.infer_type(value)
  end
end
