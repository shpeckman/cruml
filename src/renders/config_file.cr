require "yaml"

# Typed content of the `.cruml.yml` configuration file.
class Cruml::Renders::ConfigFile
  include YAML::Serializable

  # Fill colors of a theme; a missing color falls back to the built-in default.
  class ThemeColors
    include YAML::Serializable

    getter classes : String?
    getter abstract_classes : String?
    getter interfaces : String?
    getter modules : String?
    getter structs : String?
    getter enums : String?
    getter annotations : String?
    getter aliases : String?

    def initialize; end
  end

  class Colors
    include YAML::Serializable

    getter light : ThemeColors?
    getter dark : ThemeColors?

    def initialize; end
  end

  @colors : Colors?
  @paths : Array(String)?
  @namespaces : Hash(String, Array(String))?

  def initialize; end

  # Loads the configuration file; an empty file gives the default configuration.
  def self.load(path : String) : self
    content = File.read(path)
    content.blank? ? new : from_yaml(content)
  end

  # Colors of the given theme (`:light` or `:dark`), if customized.
  def theme_colors(theme : Symbol) : ThemeColors?
    colors = @colors
    return unless colors

    theme == :dark ? colors.dark : colors.light
  end

  # Paths to analyze when none is given on the command line.
  def paths : Array(String)
    @paths || [] of String
  end

  # Type names grouped by namespace.
  def namespaces : Hash(String, Array(String))
    @namespaces || {} of String => Array(String)
  end
end
