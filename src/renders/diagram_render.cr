require "file_utils"
require "./config"
require "./uml"

# Consists of generating a class diagram (see https://d2lang.com/tour/uml-classes)
class Cruml::Renders::DiagramRender
  include Cruml::Renders::UML

  getter code = String::Builder.new

  # Path of each type in the diagram, used as edge endpoints.
  @paths = {} of String => String

  def initialize(@path_dir : String, @registry : Cruml::Services::RegistryService,
                 @namespaces : Hash(String, Array(String)) = Cruml::Renders::Config.file.namespaces); end

  # Generates the UML class diagram.
  def generate : Nil
    # Children are drawn below their parents, as arrows point from child to parent.
    @code << "direction: up\n"
    generate_types
    generate_relations
  end

  # Saves the class diagram as a `.d2` file.
  def save : Nil
    dir = File.dirname(@path_dir)
    FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
    File.write(@path_dir, code.to_s)
  rescue error : File::AccessDeniedError
    puts "An error is occured when saving the diagram into #{@path_dir}. Please retry.".colorize(:red)
    puts ("Reason of this error : " + error.to_s).colorize(:red)
  end
end
