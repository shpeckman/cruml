# src/services/registry_service.cr

require "../entities/*"

class Cruml::Services::RegistryService
  getter classes = [] of Cruml::Entities::ClassInfo
  getter modules = [] of Cruml::Entities::ModuleInfo
  getter enums = [] of Cruml::Entities::EnumInfo
  getter annotations = [] of Cruml::Entities::AnnotationInfo
  getter aliases = [] of Cruml::Entities::AliasInfo

  def add_class(class_info : Cruml::Entities::ClassInfo) : Nil
    return if find_class(class_info.name)
    @classes << class_info
  end

  def find_class(class_name : String) : Cruml::Entities::ClassInfo?
    @classes.find { |class_info| class_name == class_info.name }
  end

  def find_class!(class_name : String) : Cruml::Entities::ClassInfo
    @classes.find! { |class_info| class_name == class_info.name }
  end

  def add_module(module_info : Cruml::Entities::ModuleInfo) : Nil
    return if find_module(module_info.name)
    @modules << module_info
  end

  def find_module(module_name : String) : Cruml::Entities::ModuleInfo?
    @modules.find { |module_info| module_name == module_info.name }
  end

  def find_module!(module_name : String) : Cruml::Entities::ModuleInfo
    @modules.find! { |module_info| module_name == module_info.name }
  end

  def add_enum(enum_info : Cruml::Entities::EnumInfo) : Nil
    return if find_enum(enum_info.name)
    @enums << enum_info
  end

  def find_enum(enum_name : String) : Cruml::Entities::EnumInfo?
    @enums.find { |enum_info| enum_name == enum_info.name }
  end

  def add_annotation(annotation_info : Cruml::Entities::AnnotationInfo) : Nil
    return if find_annotation(annotation_info.name)
    @annotations << annotation_info
  end

  def find_annotation(annotation_name : String) : Cruml::Entities::AnnotationInfo?
    @annotations.find { |annotation_info| annotation_name == annotation_info.name }
  end

  def add_alias(alias_info : Cruml::Entities::AliasInfo) : Nil
    return if find_alias(alias_info.name)
    @aliases << alias_info
  end

  def find_alias(alias_name : String) : Cruml::Entities::AliasInfo?
    @aliases.find { |alias_info| alias_name == alias_info.name }
  end

  # Returns true if a type of any kind is registered under this name.
  def includes?(name : String) : Bool
    entity_names.includes?(name)
  end

  def clear : Nil
    @classes.clear
    @modules.clear
    @enums.clear
    @annotations.clear
    @aliases.clear
  end

  # Rewrites the superclass, mixin and alias references, as written in the source, into the
  # fully qualified names of the registered types. Must run once every file has been parsed,
  # since a reference can point to a type declared in another file.
  def resolve_references : Nil
    names_by_base = {} of String => String
    entity_names.each { |name| names_by_base[self.class.strip_generics(name)] ||= name }

    @classes.each do |klass|
      if superclass = klass.superclass
        klass.superclass = resolve(superclass, self.class.parent_scope(klass.name), names_by_base)
      end
      klass.resolve_modules { |mod| resolve(mod, klass.name, names_by_base) }
    end

    @modules.each { |mod| mod.resolve_modules { |name| resolve(name, mod.name, names_by_base) } }
    @enums.each { |enum_info| enum_info.resolve_modules { |name| resolve(name, enum_info.name, names_by_base) } }

    @aliases.each do |alias_info|
      alias_info.target = resolve(alias_info.target, self.class.parent_scope(alias_info.name), names_by_base)
    end
  end

  # Removes from each class the instance variables already declared by one of its ancestors.
  def remove_duplicate_instance_vars : Nil
    @classes.each do |klass|
      visited = Set{klass.name}
      parent = klass.superclass.try { |name| find_class(name) }

      while parent && visited.add?(parent.name)
        parent_ivars = parent.instance_vars
        klass.instance_vars.reject! { |ivar| parent_ivars.includes?(ivar) }
        parent = parent.superclass.try { |name| find_class(name) }
      end
    end
  end

  # Removes the generic type parameters from a type name (`A(T)::B(K, V)` becomes `A::B`).
  def self.strip_generics(name : String) : String
    depth = 0

    String.build do |io|
      name.each_char do |char|
        case char
        when '(' then depth += 1
        when ')' then depth -= 1
        else          io << char if depth == 0
        end
      end
    end
  end

  # Returns the namespace enclosing a type (`A::B(T)` gives `A`).
  def self.parent_scope(name : String) : String
    parts = strip_generics(name).split("::")
    parts[0...-1].join("::")
  end

  private def entity_names : Array(String)
    @classes.map(&.name) + @modules.map(&.name) + @enums.map(&.name) +
      @annotations.map(&.name) + @aliases.map(&.name)
  end

  # Looks the reference up from the innermost enclosing namespace outwards, like Crystal does
  # for constants, and falls back to the reference as written for types outside the project.
  private def resolve(reference : String, scope : String, names_by_base : Hash(String, String)) : String
    return reference.lchop("::") if reference.starts_with?("::")

    base = self.class.strip_generics(reference)
    scope_parts = self.class.strip_generics(scope).split("::").reject(&.empty?)

    scope_parts.size.downto(0) do |size|
      candidate = (scope_parts[0, size] + [base]).join("::")
      if name = names_by_base[candidate]?
        return name
      end
    end

    reference
  end
end
