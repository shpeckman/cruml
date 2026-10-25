require "./method_info"

# Members shared by every type that can hold variables, methods and mixins
# (classes, structs, modules and enums).
module Cruml::Entities::Members
  # All instance variables.
  getter instance_vars = [] of Tuple(String, String)

  # All class variables.
  getter class_vars = [] of Tuple(String, String)

  # All methods.
  getter methods = [] of Cruml::Entities::MethodInfo

  # Included modules (instance methods).
  getter included_modules = [] of String

  # Extended modules (class methods).
  getter extended_modules = [] of String

  abstract def name : String

  # Word describing the kind of type, used in verbose messages.
  abstract def kind_label : String

  # Adds the name and the type of an instance variable, replacing any previous one with the same name.
  def add_instance_var(name : String, type : String) : Nil
    @instance_vars.reject! { |ivar| ivar[0] == name }
    @instance_vars << {name, type}

    if Cruml::Renders::Config.verbose?
      puts "VERBOSE : #{name.colorize(:magenta)} instance var added to #{self.name.colorize(:magenta)} #{kind_label}."
    end
  end

  # Returns true if an instance variable with this name is already known.
  def instance_var?(name : String) : Bool
    @instance_vars.any? { |ivar| ivar[0] == name }
  end

  # Adds the name and the type of a class variable, replacing any previous one with the same name.
  def add_class_var(name : String, type : String) : Nil
    @class_vars.reject! { |cvar| cvar[0] == name }
    @class_vars << {name, type}

    if Cruml::Renders::Config.verbose?
      puts "VERBOSE : #{name.colorize(:magenta)} class var added to #{self.name.colorize(:magenta)} #{kind_label}."
    end
  end

  # Adds a method; `initialize` is always kept first.
  def add_method(method : Cruml::Entities::MethodInfo) : Nil
    if method.name == "initialize"
      @methods.unshift(method)
    else
      @methods << method
    end

    if Cruml::Renders::Config.verbose?
      puts "VERBOSE : #{method.name.colorize(:magenta)}() method added to #{name.colorize(:magenta)} #{kind_label}."
    end
  end

  # Adds a module name to the list of included modules.
  def add_included_module(module_name : String) : Nil
    return if @included_modules.includes?(module_name)
    @included_modules << module_name

    if Cruml::Renders::Config.verbose?
      puts "VERBOSE : #{module_name.colorize(:magenta)} module included in #{name.colorize(:magenta)} #{kind_label}."
    end
  end

  # Adds a module name to the list of extended modules.
  def add_extended_module(module_name : String) : Nil
    return if @extended_modules.includes?(module_name)
    @extended_modules << module_name

    if Cruml::Renders::Config.verbose?
      puts "VERBOSE : #{module_name.colorize(:magenta)} module extended in #{name.colorize(:magenta)} #{kind_label}."
    end
  end

  # Replaces the mixin names by the ones returned by the block (used to resolve references).
  def resolve_modules(& : String -> String) : Nil
    @included_modules.map! { |module_name| yield module_name }.uniq!
    @extended_modules.map! { |module_name| yield module_name }.uniq!
  end

  # Returns true if there is at least one variable or method to display.
  def members? : Bool
    !(@instance_vars.empty? && @class_vars.empty? && @methods.empty?)
  end
end
