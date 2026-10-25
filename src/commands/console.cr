# src/commands/console.cr

require "tallboy"
require "option_parser"
require "./../renders/config"
require "./runner"

cli_paths = [] of String
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

    parser.on "--path=PATH", "Path to analyze (repeatable, overrides the paths of .cruml.yml)" do |path|
      cli_paths << path
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

begin
  Cruml::Renders::Config.load(config_file)
rescue error : YAML::ParseException
  STDERR.puts "Invalid configuration file #{config_file} : #{error.message}".colorize(:red)
  exit 1
end

# Paths given on the command line take precedence over the ones of the configuration file.
paths = cli_paths.empty? ? Cruml::Renders::Config.file.paths : cli_paths
files = [] of String

paths.each do |path|
  if File.file?(path) && path.ends_with?(".cr")
    files << path
  elsif File.directory?(path)
    files.concat(Dir.glob("#{path}/**/*.cr").sort!)
  else
    STDERR.puts "Ignoring #{path} : not a Crystal file or a directory.".colorize(:yellow)
  end
end

Cruml::Runner.new(files.uniq, target_dir, Cruml::Renders::Config.verbose?).run
