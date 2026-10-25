# src/commands/console.cr

require "yaml"
require "tallboy"
require "option_parser"
require "./../transformer"
require "./../renders/diagram_render"
require "./../renders/config"
require "./runner"

files = [] of String
target_dir = "out/"

OptionParser.parse do |parser|
  parser.banner = "Usage : cruml [subcommand] [arguments] -- [options]"

  parser.on "config", "Configuration" do
    parser.on "--generate", "Generate a YML config" do
      begin
        Cruml::Renders::Config.generate_config_file
        puts "Config is successfully generated."
        exit 0
      rescue Exception
        puts "Impossble to generate the YML config file. Please retry."
      end
    end
  end

  parser.on "generate", "Generate the class diagram" do
    parser.banner = "Usage : cruml generate [arguments] -- [options]"

    parser.on "--verbose", "Enable verbose" do
      Cruml::Renders::Config.verbose = true
    end

    parser.on "--dark-mode", "Set to dark mode" do
      Cruml::Renders::Config.theme = :dark
    end

    parser.on "--no-color", "Disable color output" do
      Cruml::Renders::Config.no_color = true
    end

    parser.on "--path=PATH", "Path to specify" do |path|
      if File.file?(path) && path.ends_with?(".cr")
        files << path
      end

      if File.directory?(path)
        files |= Dir.glob("#{path}/**/*.cr")
      end
    end

    parser.on "--output-dir=DIR", "Directory path to save diagrams" do |dir|
      target_dir = dir
    end
  end

  parser.on "-v", "--version", "Show the version" do
    puts "Cruml (version #{Cruml::VERSION})"
    exit 0
  end

  parser.on "-h", "--help", "Show this help" do
    puts parser
    exit 0
  end

  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option.".colorize(:red)
    STDERR.puts parser
    exit 1
  end
end

config_file = Cruml::Renders::Config.ensure_config_file!

File.open(config_file) do |file|
  if paths = YAML.parse(file)["paths"]?
    paths.as_a.each do |path|
      if File.file?(path.as_s) && path.as_s.ends_with?(".cr")
        files << path.as_s
      end

      if File.directory?(path.as_s)
        files |= Dir.glob("#{path.as_s}/**/*.cr")
      end
    end
  end
end

if files.size == 0
  puts "No crystal files are present in the path, please retry.".colorize(:red)
  exit 1
end

Cruml::Runner.new(files, target_dir, Cruml::Renders::Config.verbose?).run

