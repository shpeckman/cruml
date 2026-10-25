# src/renders/uml.cr

require "./classifier"

module Cruml::Renders::UML
  include Cruml::Renders::Classifier

  INDENT = " " * 4

  # Solid line with a hollow triangle pointing to the parent class.
  GENERALIZATION = "{target-arrowhead.shape: triangle; target-arrowhead.style.filled: false}"

  # Dashed line with a hollow triangle pointing to the interface.
  REALIZATION = "{style.stroke-dash: 3; target-arrowhead.shape: triangle; target-arrowhead.style.filled: false}"

  # Dashed line with an open arrow, labelled with the kind of dependency.
  DEPENDENCY = "{style.stroke-dash: 3}"

  # Field names d2 interprets as keywords, even when quoted.
  D2_RESERVED_KEYWORDS = %w[
    label shape style icon near width height top left direction tooltip link
    constraint class classes vars grid-rows grid-columns grid-gap vertical-gap horizontal-gap
  ]

  private def method_visibility(visibility : Symbol) : Char
    case visibility
    when :public    then '+'
    when :protected then '#'
    when :private   then '-'
    else                 '?'
    end
  end

  # Adds the types grouped in the configured namespaces, then the other ones.
  private def generate_types : Nil
    namespace_of = {} of String => String
    @namespaces.each do |namespace, names|
      names.each { |name| namespace_of[name] ||= namespace }
    end

    types = @registry.modules.select(&.members?) + @registry.classes + @registry.enums +
            @registry.annotations + @registry.aliases
    types_by_namespace = types.group_by { |type| namespace_of[type.name]? }

    @namespaces.each_key do |namespace|
      next unless namespace_types = types_by_namespace[namespace]?

      add_namespace(namespace) do
        namespace_types.each { |type| add_type(type, namespace) }
      end
    end

    types_by_namespace[nil]?.try &.each { |type| add_type(type, nil) }
  end

  # Adds the relationships, once every type has its path in the diagram.
  private def generate_relations : Nil
    @registry.classes.each do |klass|
      next unless from = @paths[klass.name]?

      if superclass = klass.superclass
        add_relation(from, superclass, interface?(superclass) ? REALIZATION : GENERALIZATION)
      end

      add_mixins(from, klass)
    end

    @registry.modules.each do |the_module|
      @paths[the_module.name]?.try { |from| add_mixins(from, the_module) }
    end

    @registry.enums.each do |enum_info|
      @paths[enum_info.name]?.try { |from| add_mixins(from, enum_info) }
    end

    @registry.aliases.each do |alias_info|
      next unless (from = @paths[alias_info.name]?) && @registry.includes?(alias_info.target)
      add_relation(from, alias_info.target, DEPENDENCY, "alias")
    end
  end

  private def add_type(type, namespace : String?) : Nil
    @paths[type.name] = namespace ? "#{quote(namespace)}.#{quote(type.name)}" : quote(type.name)
    add_type(type)
  end

  private def add_type(module_info : Cruml::Entities::ModuleInfo) : Nil
    if module_info.type == :interface
      add_interface(module_info.name) { add_members(module_info) }
    else
      add_module(module_info.name) { add_members(module_info) }
    end
  end

  private def add_type(class_info : Cruml::Entities::ClassInfo) : Nil
    name = class_info.name

    case class_info.type
    when :interface then add_interface(name) { add_members(class_info) }
    when :abstract
      if class_info.struct?
        add_struct(name, abstract: true) { add_members(class_info) }
      else
        add_abstract_class(name) { add_members(class_info) }
      end
    else
      if class_info.struct?
        add_struct(name) { add_members(class_info) }
      else
        add_normal_class(name) { add_members(class_info) }
      end
    end
  end

  private def add_type(enum_info : Cruml::Entities::EnumInfo) : Nil
    add_enum(enum_info.name) do
      if base_type = enum_info.base_type
        @code << INDENT << "\\: " << Cruml::Entities::MethodInfo.escape(base_type) << "\n"
      end

      enum_info.constants.each do |name, value|
        key = D2_RESERVED_KEYWORDS.includes?(name.downcase) ? quote(" #{name}") : name
        @code << INDENT << key
        @code << ": " << Cruml::Entities::MethodInfo.escape(value) if value
        @code << "\n"
      end

      add_members(enum_info)
    end
  end

  private def add_type(annotation_info : Cruml::Entities::AnnotationInfo) : Nil
    add_annotation(annotation_info.name)
  end

  private def add_type(alias_info : Cruml::Entities::AliasInfo) : Nil
    add_alias(alias_info.name) do
      @code << INDENT << "\\=: " << Cruml::Entities::MethodInfo.escape(alias_info.target) << "\n"
    end
  end

  private def add_members(type : Cruml::Entities::Members) : Nil
    add_vars(type.class_vars)
    add_vars(type.instance_vars)
    add_methods(type.methods)
  end

  private def add_vars(vars : Array(Tuple(String, String))) : Nil
    vars.each do |name, type|
      @code << INDENT << '-' << name << " : " << Cruml::Entities::MethodInfo.escape(type) << "\n"
    end
  end

  private def add_methods(methods : Array(Cruml::Entities::MethodInfo)) : Nil
    methods.each do |method|
      visibility = method_visibility(method.visibility)
      visibility = "\\#" if visibility == '#'

      @code << INDENT << visibility << method.name << '(' << method.generate_args << ')'

      unless method.return_type.empty?
        @code << ": " << Cruml::Entities::MethodInfo.escape(method.return_type)
      end

      @code << "\n"
    end
  end

  private def add_mixins(from : String, type : Cruml::Entities::Members) : Nil
    type.included_modules.each do |module_name|
      if interface?(module_name)
        add_relation(from, module_name, REALIZATION)
      else
        add_relation(from, module_name, DEPENDENCY, "include")
      end
    end

    type.extended_modules.each do |module_name|
      add_relation(from, module_name, DEPENDENCY, "extend")
    end
  end

  # Adds an edge from a type to another one, which may not be part of the diagram.
  private def add_relation(from : String, target : String, style : String, stereotype : String? = nil) : Nil
    @code << from << " -> " << (@paths[target]? || quote(target)) << ": "
    @code << quote("«#{stereotype}»") << ' ' if stereotype
    @code << style << "\n"
  end

  private def interface?(name : String) : Bool
    type = @registry.find_class(name) || @registry.find_module(name)
    !type.nil? && type.type == :interface
  end
end
