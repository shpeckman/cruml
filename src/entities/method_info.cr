# src/entities/method_info.cr

class Cruml::Entities::MethodInfo
  ESCAPE_PATTERNS = {
    '|' => "\\|",
    ':' => "\\:",
    '.' => "\\.",
    '{' => "\\{",
    '}' => "\\}",
    '<' => "\\<",
    '>' => "\\>",
    '[' => "\\[",
    ']' => "\\]",
    '"' => "\\\"",
    '\'' => "\\'",
  }

  getter visibility : Symbol
  getter name : String
  getter return_type : String
  getter args = [] of Cruml::Entities::ArgInfo

  def self.escape(input : String) : String
    input.gsub(ESCAPE_PATTERNS)
  end

  def initialize(@visibility : Symbol, @name : String, @return_type : String)
    @name = self.class.escape(@name)
  end

  def add_arg(arg : Cruml::Entities::ArgInfo) : Nil
    @args << arg

    if Cruml::Renders::Config.verbose?
      puts "VERBOSE : #{arg.name.colorize(:magenta)} arg of type #{arg.type.colorize(:magenta)} added to #{@name.colorize(:magenta)} method."
    end
  end

  def generate_args : String
    String.build do |str|
      @args.each_with_index do |arg, index|
        str << arg.name << " \\: " << self.class.escape(arg.type)
        str << ", " if index != @args.size - 1
      end
    end
  end
end

