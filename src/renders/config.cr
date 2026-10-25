# src/renders/config.cr

require "yaml"

class Cruml::Renders::Config
  class_property theme = :light
  class_property? no_color = false
  class_property? verbose = false

  def self.config_path : String
    File.join(Dir.current, ".cruml.yml")
  end

  def self.default_yaml : String
    YAML.build do |yml|
      yml.mapping do
        yml.scalar "colors"
        yml.mapping do
          yml.scalar "light"
          yml.mapping do
            yml.scalar "classes"
            yml.scalar "#baa7e5"
            yml.scalar "abstract_classes"
            yml.scalar "#a7e5a7"
            yml.scalar "interfaces"
            yml.scalar "#e2c7a3"
            yml.scalar "modules"
            yml.scalar "#5ab3f4"
          end

          yml.scalar "dark"
          yml.mapping do
            yml.scalar "classes"
            yml.scalar "#2e1065"
            yml.scalar "abstract_classes"
            yml.scalar "#365314"
            yml.scalar "interfaces"
            yml.scalar "#af6300"
            yml.scalar "modules"
            yml.scalar "#0041cc"
          end
        end

        yml.scalar "paths"
        yml.sequence do
          yml.scalar "src/"
        end

        yml.scalar "namespaces"
        yml.mapping do
          yml.scalar "Namespace"
          yml.sequence do
            yml.scalar "ClassOne"
            yml.scalar "ClassTwo"
            yml.scalar "ClassThree"
          end
        end
      end
    end
  end

  def self.generate_config_file(path : String = config_path) : Nil
    File.write(path, default_yaml)
  end

  def self.ensure_config_file!(path : String = config_path) : String
    generate_config_file(path) unless File.exists?(path)
    path
  end

  def self.class_color : String
    customized_color = color_theme_from_yaml("classes")

    if !customized_color.nil?
      customized_color
    else
      (@@theme == :light) ? "#5016bb" : "#2e1065"
    end
  end

  def self.abstract_color : String
    customized_color = color_theme_from_yaml("abstract_classes")

    if !customized_color.nil?
      customized_color
    else
      (@@theme == :light) ? "#5ea012" : "#365314"
    end
  end

  def self.interface_color : String
    customized_color = color_theme_from_yaml("interfaces")

    if !customized_color.nil?
      customized_color
    else
      (@@theme == :light) ? "#e28b19" : "#af6300"
    end
  end

  def self.module_color : String
    customized_color = color_theme_from_yaml("modules")

    if !customized_color.nil?
      customized_color
    else
      (@@theme == :light) ? "#1158f3" : "#0041cc"
    end
  end

  def self.theme_color : String
    (@@theme == :light) ? "#dedede" : "#212121"
  end

  def self.text_color : String
    (@@theme == :light) ? "#000000" : "#ffffff"
  end

  def self.color_theme_from_yaml(type : String) : String?
    path = ensure_config_file!

    File.open(path) do |file|
      if colors = YAML.parse(file)["colors"]?
        if theme_colors = colors[@@theme.to_s]?
          if color = theme_colors[type]?
            return color.as_s
          end
        end
      end
    end

    nil
  end

  def self.class_def_colors : String
    String.build do |io|
      [
        {:default, self.class_color},
        {:abstract, self.abstract_color},
        {:interface, self.interface_color},
        {:module, self.module_color},
      ].each do |type, color|
        io << Cruml::Renders::UML::INDENT * 2
        io << "classDef " << type << " fill:"
        io << (@@no_color == true ? self.theme_color : color)
        io << ",color:" << self.text_color
        io << ",stroke:" << (@@theme == :dark ? "#fff" : "#000")
        io << "\n"
      end
    end
  end
end

