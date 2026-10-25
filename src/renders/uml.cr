# src/renders/uml.cr

require "./classifier"

module Cruml::Renders::UML
  include Cruml::Renders::Classifier

  INDENT = " " * 4

  private def method_visibility(visibility : Symbol) : Char
    case visibility
    when :public    then '+'
    when :protected then '#'
    when :private   then '-'
    else                 '?'
    end
  end

  private def generate_diagrams_by_namespace
    module_namespaces = @registry.group_modules_by_namespaces
    class_namespaces = @registry.group_classes_by_namespaces

    all_namespaces = (module_namespaces.keys + class_namespaces.keys).uniq

    all_namespaces.each do |namespace|
      modules = module_namespaces[namespace]? || [] of Cruml::Entities::ModuleInfo
      classes = class_namespaces[namespace]? || [] of Cruml::Entities::ClassInfo

      add_namespace(namespace) do
        modules.each do |the_module|
          next if the_module.methods.empty?

          ivars_and_methods = -> do
            add_instance_vars(the_module.instance_vars)
            add_methods(the_module.methods)
          end

          case the_module.type
          when :normal    then add_module(the_module.name, &ivars_and_methods)
          when :interface then add_interface(the_module.name, &ivars_and_methods)
          end
        end

        classes.each do |klass|
          add_class(klass)
          add_parent_class(klass.parent_classes)
          add_included_modules(klass)
          add_extended_modules(klass)
        end
      end
    end
  end

  private def generate_standalone_modules
    @registry.modules.each do |the_module|
      next if the_module.methods.empty?

      ivars_and_methods = -> do
        add_instance_vars(the_module.instance_vars)
        add_methods(the_module.methods)
      end

      case the_module.type
      when :normal    then add_module(the_module.name, &ivars_and_methods)
      when :interface then add_interface(the_module.name, &ivars_and_methods)
      end
    end
  end

  private def generate_standalone_classes
    @registry.classes.each do |klass|
      add_class(klass)
      add_parent_class(klass.parent_classes)
      add_included_modules(klass)
      add_extended_modules(klass)
    end
  end

  private def generate_class_diagrams
    my_proc = ->(klass : Cruml::Entities::ClassInfo) do
      add_class(klass)
      add_parent_class(klass.parent_classes)
      add_included_modules(klass)
      add_extended_modules(klass)
    end

    @registry.group_classes_by_namespaces.each do |namespace, classes|
      add_namespace(namespace) { classes.each(&my_proc) }
    end

    @registry.classes.each(&my_proc)
  end

  private def add_instance_vars(instance_vars : Array(Tuple(String, String))) : Nil
    instance_vars.each do |name, type|
      @code << INDENT << '-' << name << " : " << Cruml::Entities::MethodInfo.escape(type) << "\n"
    end
  end

  private def add_class_vars(class_vars : Array(Tuple(String, String))) : Nil
    class_vars.each do |name, type|
      @code << INDENT << '-' << name << " : " << Cruml::Entities::MethodInfo.escape(type) << "\n"
    end
  end

  private def add_class(class_info : Cruml::Entities::ClassInfo) : Nil
    short_class_name = class_info.name

    ivars_and_methods = -> do
      add_class_vars(class_info.class_vars)
      add_instance_vars(class_info.instance_vars)
      add_methods(class_info.methods)
    end

    case class_info.type
    when :abstract  then add_abstract_class(short_class_name, &ivars_and_methods)
    when :interface then add_interface(short_class_name, &ivars_and_methods)
    when :class     then add_normal_class(short_class_name, &ivars_and_methods)
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

  private def add_parent_class(inherit_classes : Array(Tuple(String, String, Symbol))) : Nil
    inherit_classes.each do |class_name, subclass_name, class_type|
      if class_type == :interface
        @code << class_name.dump << " -> " << subclass_name.dump << ": {style.stroke-dash: 3}\n"
      else
        @code << class_name.dump << " -> " << subclass_name.dump << "\n"
      end
    end
  end

  private def add_included_modules(class_info : Cruml::Entities::ClassInfo) : Nil
    class_info.included_modules.each do |module_name|
      @code << module_name.dump << " -> " << class_info.name.dump << ": {style.stroke-dash: 3}\n"
    end
  end

  private def add_extended_modules(class_info : Cruml::Entities::ClassInfo) : Nil
    class_info.extended_modules.each do |module_name|
      @code << module_name.dump << " -> " << class_info.name.dump << ": {style.stroke-dash: 3}\n"
    end
  end

  private def set_diagram_colors : Nil
    @code << Cruml::Renders::Config.class_def_colors
  end
end

