require "../spec_helper"

describe Cruml::Renders::DiagramRender do
  it "differentiates the kinds of relationships" do
    registry = visit_source <<-CR
      module DrawableInterface
        abstract def draw : Nil
      end
      module Greeter
        def greet; end
      end
      abstract class Shape
        include DrawableInterface
        include Greeter
        extend Greeter
      end
      class Circle < Shape; end
      CR

    d2 = render_d2(registry)
    d2.should contain(%("Circle" -> "Shape": #{Cruml::Renders::UML::GENERALIZATION}))
    d2.should contain(%("Shape" -> "DrawableInterface": #{Cruml::Renders::UML::REALIZATION}))
    d2.should contain(%("Shape" -> "Greeter": "«include»" #{Cruml::Renders::UML::DEPENDENCY}))
    d2.should contain(%("Shape" -> "Greeter": "«extend»" #{Cruml::Renders::UML::DEPENDENCY}))
  end

  it "uses namespaced paths for edge endpoints without consuming the registry" do
    registry = visit_source <<-CR
      class Shape; end
      class Circle < Shape; end
      CR

    d2 = render_d2(registry, {"Geometry" => ["Shape"]})
    d2.should contain(%("Geometry" {\n"Shape" {))
    d2.should contain(%("Circle" -> "Geometry"."Shape"))
    registry.classes.size.should eq(2)
  end

  it "renders structs, enums, annotations and aliases with stereotypes" do
    registry = visit_source <<-CR
      struct Point; end
      enum Kind : UInt8
        Red
        Label = 2
      end
      annotation Marker; end
      alias Location = Point
      CR

    d2 = render_d2(registry)
    d2.should contain(%(label: "«struct» Point"))
    d2.should contain(%(label: "«enum» Kind : UInt8"))
    d2.should contain(%(    Red\n    " Label": 2\n))
    d2.should contain(%(label: "«annotation» Marker"))
    d2.should contain(%(label: "«alias» Location"))
    d2.should contain(%("Location" -> "Point": "«alias»"))
  end

  it "skips modules without members" do
    registry = visit_source <<-CR
      module App
        class Foo; end
      end
      CR

    render_d2(registry).should_not contain(%("App" {))
  end
end
