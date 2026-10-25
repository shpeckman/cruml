# src/services/registry_service.cr

require "yaml"
require "../entities/class_info"
require "../entities/module_info"

class Cruml::Services::RegistryService
  getter classes = [] of Cruml::Entities::ClassInfo
  getter modules = [] of Cruml::Entities::ModuleInfo

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

  def clear : Nil
    @classes.clear
    @modules.clear
  end

  def group_classes_by_namespaces(test_mode : Bool = false) : Hash(String, Array(Cruml::Entities::ClassInfo))
    output = {} of String => Array(Cruml::Entities::ClassInfo)

    config_path = if test_mode
                    Dir.current + "/.cruml.test.yml"
                  else
                    Dir.current + "/.cruml.yml"
                  end

    unless File.exists?(config_path)
      return output
    end

    File.open(config_path) do |file|
      if namespaces = YAML.parse(file)["namespaces"]?
        namespaces.as_h.each do |key, classes|
          classes_info = [] of Cruml::Entities::ClassInfo

          classes.as_a.each do |klass|
            if found_class = find_class(klass.as_s)
              classes_info << found_class
              @classes.reject! { |kls| kls.name == klass.as_s }
            end
          end

          unless classes_info.empty?
            output[key.as_s] = classes_info
          end
        end
      end
    end

    output
  end

  def group_modules_by_namespaces(test_mode : Bool = false) : Hash(String, Array(Cruml::Entities::ModuleInfo))
    output = {} of String => Array(Cruml::Entities::ModuleInfo)

    config_path = if test_mode
                    Dir.current + "/.cruml.test.yml"
                  else
                    Dir.current + "/.cruml.yml"
                  end

    unless File.exists?(config_path)
      return output
    end

    File.open(config_path) do |file|
      if namespaces = YAML.parse(file)["namespaces"]?
        namespaces.as_h.each do |key, items|
          modules_info = [] of Cruml::Entities::ModuleInfo

          items.as_a.each do |item|
            if found_module = find_module(item.as_s)
              modules_info << found_module
              @modules.reject! { |mod| mod.name == item.as_s }
            end
          end

          output[key.as_s] = modules_info unless modules_info.empty?
        end
      end
    end

    output
  end

  def remove_duplicate_instance_vars : Nil
    classes_with_parents = @classes.select { |klass| !klass.parent_classes.empty? }
      .sort_by!(&.parent_classes.size)

    classes_with_parents.reverse_each do |klass|
      klass.parent_classes.each do |parent_name, _, _|
        if parent = find_class(parent_name)
          parent_ivars = parent.instance_vars
          klass.instance_vars.reject! { |ivar| parent_ivars.includes?(ivar) }
        end
      end
    end
  end
end

