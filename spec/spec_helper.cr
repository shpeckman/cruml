require "spec"
require "./../src/renders/config"
require "./../src/entities/**"
require "./../src/visitor"
require "./../src/renders/diagram_render"

# Parses Crystal source code and returns the registry filled by the visitor.
def visit_source(*sources : String) : Cruml::Services::RegistryService
  registry = Cruml::Services::RegistryService.new
  visitor = Cruml::Visitor.new(registry)
  sources.each { |source| Crystal::Parser.parse(source).accept(visitor) }
  registry.resolve_references
  registry
end

# Renders the registry as d2 code.
def render_d2(registry : Cruml::Services::RegistryService, namespaces = {} of String => Array(String)) : String
  diagram = Cruml::Renders::DiagramRender.new("unused.d2", registry, namespaces)
  diagram.generate
  diagram.code.to_s
end
