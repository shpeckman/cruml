# src/renders/config.cr

require "yaml"
require "./config_file"

class Cruml::Renders::Config
  class_property theme = :light
  class_property? no_color = false
  class_property? verbose = false

  # Loaded configuration file (see `.load`).
  class_property file = Cruml::Renders::ConfigFile.new

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
            yml.scalar "structs"
            yml.scalar "#e5a7c9"
            yml.scalar "enums"
            yml.scalar "#a7e0e5"
            yml.scalar "annotations"
            yml.scalar "#e5e0a7"
            yml.scalar "aliases"
            yml.scalar "#d4d4d4"
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
            yml.scalar "structs"
            yml.scalar "#6b1a45"
            yml.scalar "enums"
            yml.scalar "#0f5a54"
            yml.scalar "annotations"
            yml.scalar "#5c5410"
            yml.scalar "aliases"
            yml.scalar "#4a4a4a"
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

  # Parses the configuration file once; raises `YAML::ParseException` if it is invalid.
  def self.load(path : String = config_path) : Cruml::Renders::ConfigFile
    @@file = Cruml::Renders::ConfigFile.load(path)
  end

  def self.class_color : String
    theme_colors.try(&.classes) || themed("#5016bb", "#2e1065")
  end

  def self.abstract_color : String
    theme_colors.try(&.abstract_classes) || themed("#5ea012", "#365314")
  end

  def self.interface_color : String
    theme_colors.try(&.interfaces) || themed("#e28b19", "#af6300")
  end

  def self.module_color : String
    theme_colors.try(&.modules) || themed("#1158f3", "#0041cc")
  end

  def self.struct_color : String
    theme_colors.try(&.structs) || themed("#e5a7c9", "#6b1a45")
  end

  def self.enum_color : String
    theme_colors.try(&.enums) || themed("#a7e0e5", "#0f5a54")
  end

  def self.annotation_color : String
    theme_colors.try(&.annotations) || themed("#e5e0a7", "#5c5410")
  end

  def self.alias_color : String
    theme_colors.try(&.aliases) || themed("#d4d4d4", "#4a4a4a")
  end

  private def self.theme_colors : Cruml::Renders::ConfigFile::ThemeColors?
    @@file.theme_colors(@@theme)
  end

  private def self.themed(light : String, dark : String) : String
    @@theme == :light ? light : dark
  end
end
