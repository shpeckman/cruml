# Classifiers consists to add classes, structs, abstract classes, interfaces, modules, enums,
# annotations, aliases and namespaces into the class diagram.
module Cruml::Renders::Classifier
  # Adds an object into the class diagram, with an optional UML stereotype (`«struct»`, ...)
  # and text appended to its title.
  private def add_object(name : String, color : String, stereotype : String? = nil, suffix : String? = nil, &) : Nil
    @code << quote(name) << " {" << "\n"
    @code << Cruml::Renders::UML::INDENT << "shape: class" << "\n"

    if stereotype
      @code << Cruml::Renders::UML::INDENT << "label: " << quote("«#{stereotype}» #{name}#{suffix}") << "\n"
    end

    unless Cruml::Renders::Config.no_color?
      @code << Cruml::Renders::UML::INDENT << <<-STR
      style.fill: "#{color}"\n
      STR
    end

    yield
    @code << "}\n"
  end

  # Adds a normal class into the class diagram.
  private def add_normal_class(name : String, &) : Nil
    add_object(name, Cruml::Renders::Config.class_color) do
      yield
    end
  end

  # Adds an abstract class into the class diagram.
  private def add_abstract_class(name : String, &) : Nil
    add_object(name, Cruml::Renders::Config.abstract_color, "abstract") do
      yield
    end
  end

  # Adds a struct into the class diagram.
  private def add_struct(name : String, abstract : Bool = false, &) : Nil
    add_object(name, Cruml::Renders::Config.struct_color, abstract ? "abstract struct" : "struct") do
      yield
    end
  end

  # Adds an interface into the class diagram.
  private def add_interface(name : String, &) : Nil
    add_object(name, Cruml::Renders::Config.interface_color, "interface") do
      yield
    end
  end

  # Adds a namespace into the class diagram.
  private def add_namespace(name : String, &) : Nil
    @code << quote(name) << " {\n"
    yield
    @code << "}\n"
  end

  # Adds a module into the class diagram.
  private def add_module(name : String, &)
    add_object(name, Cruml::Renders::Config.module_color, "module") do
      yield
    end
  end

  # Adds an enum into the class diagram, with its base type (e.g. `UInt8`) if any.
  private def add_enum(name : String, base_type : String? = nil, &) : Nil
    add_object(name, Cruml::Renders::Config.enum_color, "enum", base_type.try { |type| " : #{type}" }) do
      yield
    end
  end

  # Adds an annotation into the class diagram.
  private def add_annotation(name : String) : Nil
    add_object(name, Cruml::Renders::Config.annotation_color, "annotation") { }
  end

  # Adds a type alias into the class diagram.
  private def add_alias(name : String, &) : Nil
    add_object(name, Cruml::Renders::Config.alias_color, "alias") do
      yield
    end
  end

  # Quotes a d2 key or label.
  private def quote(text : String) : String
    %("#{text.gsub('"', "\\\"")}")
  end
end
