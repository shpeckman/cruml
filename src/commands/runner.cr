require "file_utils"
require "tallboy"
require "process"
require "time"

require "./../visitor"
require "./../services/registry_service"
require "./../renders/diagram_render"

# Runner encapsulates the business logic of analyzing sources and rendering diagrams.
class Cruml::Runner
  def initialize(@files : Array(String), @output_dir : String = "out/", @verbose : Bool = false); end

  def run : Nil
    if @files.size == 0
      puts "No crystal files are present in the path, please retry.".colorize(:red)
      exit 1
    end

    processed_files = 0
    registry = Cruml::Services::RegistryService.new

    measured_time_to_process = Time.measure do
      visitor = Cruml::Visitor.new(registry)

      @files.each do |file|
        begin
          Crystal::Parser.parse(File.read(file)).accept(visitor)
          processed_files += 1
        rescue error : Crystal::SyntaxException
          STDERR.puts "Skipping #{file} : #{error.message} (line #{error.line_number})".colorize(:yellow)
        end
      end

      registry.resolve_references
    end

    measured_time_to_verify = Time.measure do
      registry.remove_duplicate_instance_vars
    end

    measured_time_to_render = Time.measure do
      FileUtils.mkdir_p(@output_dir) unless Dir.exists?(@output_dir)

      diagram = Cruml::Renders::DiagramRender.new("#{@output_dir}/diagram.d2", registry)
      diagram.generate
      diagram.save

      render_svg("#{@output_dir}/diagram.d2", "#{@output_dir}/diagram.svg")
    end

    if @verbose
      table = Tallboy.table do
        header "Statistics"
        rows [
          ["Processed files", processed_files],
          ["Time to process", measured_time_to_process],
          ["Time to verify (ivars, cvars)", measured_time_to_verify],
          ["Time to render", measured_time_to_render],
          ["Global time", measured_time_to_process + measured_time_to_verify + measured_time_to_render],
        ]
      end

      puts table
    else
      total_time = measured_time_to_process + measured_time_to_verify + measured_time_to_render
      if total_time.total_seconds >= 1
        puts "Diagram successfully generated in #{total_time.total_seconds.round(2)} seconds.".colorize(:green)
      else
        puts "Diagram successfully generated in #{total_time.total_milliseconds.round(2)} milliseconds.".colorize(:green)
      end
    end
  end

  # Renders the d2 file as SVG, showing the errors reported by d2 if it fails.
  private def render_svg(d2_path : String, svg_path : String) : Nil
    error = IO::Memory.new
    status = Process.run("d2", [d2_path, svg_path, "-c"], error: error)

    unless status.success?
      STDERR.puts "Cannot render the class diagram with d2 (exit code #{status.exit_code}):".colorize(:red)
      STDERR.puts error.to_s.strip unless error.empty?
      exit 1
    end
  rescue File::NotFoundError
    STDERR.puts "d2 is not installed. Please go to https://github.com/terrastruct/d2 to install it.".colorize(:red)
    exit 1
  end
end
