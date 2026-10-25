require "./spec_helper"

describe Cruml::Visitor do
  it "qualifies nested types" do
    registry = visit_source <<-CR
      module App
        class Cruml::Nested; end
        module Inner
          class Foo; end
        end
        class App::Bar; end
      end
      class ::Global; end
      CR

    registry.classes.map(&.name).should eq(["App::Cruml::Nested", "App::Inner::Foo", "App::Bar", "Global"])
    registry.modules.map(&.name).should eq(["App", "App::Inner"])
  end

  it "records methods with their visibility" do
    registry = visit_source <<-CR
      class Person
        def initialize(@name : String, @age = 3); end
        def self.create : Person; end
        def greet(other : Person, loud : Bool = false) : String; end
        private def secret; end
        protected def internal : Int32; end
      end
      CR

    methods = registry.find_class!("Person").methods
    methods.map { |method| {method.visibility, method.name, method.return_type} }.should eq([
      {:protected, "initialize", "Nil"},
      {:public, "self\\.create", "Person"},
      {:public, "greet", "String"},
      {:private, "secret", "Nil"},
      {:protected, "internal", "Int32"},
    ])
    methods[2].generate_args.should eq("other \\: Person, loud \\: Bool = false")
  end

  it "records instance and class variables" do
    registry = visit_source <<-CR
      class Person
        @email : String
        @@count : Int32 = 0

        def initialize(@name : String, @age = 3, nickname : String? = nil)
          @nickname = nickname
          @tags = [] of String
          @email = "unknown"
        end
      end
      CR

    person = registry.find_class!("Person")
    person.instance_vars.should eq([
      {"@email", "String"},
      {"@name", "String"},
      {"@age", "Int32"},
      {"@nickname", "String?"},
      {"@tags", "Array(String)"},
    ])
    person.class_vars.should eq([{"@@count", "Int32"}])
  end

  it "keeps a declared type over an inferred one" do
    registry = visit_source <<-CR
      class Counter
        def initialize
          @value = 0
        end

        @value : Int64
      end
      CR

    registry.find_class!("Counter").instance_vars.should eq([{"@value", "Int64"}])
  end

  it "records accessor macros as variables and methods" do
    registry = visit_source <<-CR
      class Person
        getter name : String
        property? alive : Bool = true
        getter! nickname : String
        setter age : Int32
        class_property count = 0
        private getter secret : String
      end
      CR

    person = registry.find_class!("Person")
    person.instance_vars.should eq([
      {"@name", "String"}, {"@alive", "Bool"}, {"@nickname", "String?"}, {"@age", "Int32"}, {"@secret", "String"},
    ])
    person.class_vars.should eq([{"@@count", "Int32"}])
    person.methods.map { |method| {method.visibility, method.name, method.return_type} }.should eq([
      {:public, "name", "String"},
      {:public, "alive?", "Bool"},
      {:public, "alive=", "Bool"},
      {:public, "nickname", "String"},
      {:public, "nickname?", "String?"},
      {:public, "age=", "Int32"},
      {:public, "self\\.count", "Int32"},
      {:public, "self\\.count=", "Int32"},
      {:private, "secret", "String"},
    ])
    person.methods[2].generate_args.should eq("value \\: Bool")
  end

  it "does not treat calls inside methods as accessors" do
    registry = visit_source <<-CR
      class Person
        def build
          property name : String
        end
      end
      CR

    registry.find_class!("Person").instance_vars.should be_empty
  end

  it "records includes and extends of classes and modules" do
    registry = visit_source <<-CR
      module App
        module Greeter; end
        module Loggable
          include Greeter
          extend self
        end
        class Person
          include Greeter
          extend Loggable
        end
      end
      CR

    registry.find_class!("App::Person").included_modules.should eq(["App::Greeter"])
    registry.find_class!("App::Person").extended_modules.should eq(["App::Loggable"])
    registry.find_module!("App::Loggable").included_modules.should eq(["App::Greeter"])
    registry.find_module!("App::Loggable").extended_modules.should be_empty
  end

  it "resolves superclasses declared in another file" do
    registry = visit_source(<<-CR, <<-CR2)
      module App
        class Circle < Shape; end
      end
      CR
      abstract class App::Shape; end
      CR2

    registry.find_class!("App::Circle").superclass.should eq("App::Shape")
  end

  it "records structs" do
    registry = visit_source <<-CR
      struct Point; end
      abstract struct Base; end
      CR

    registry.find_class!("Point").struct?.should be_true
    registry.find_class!("Point").type.should eq(:class)
    registry.find_class!("Base").type.should eq(:abstract)
  end

  it "records enums with their constants and methods" do
    registry = visit_source <<-CR
      module App
        enum Color : UInt8
          Red
          Green = 5

          def warm? : Bool
            self == Red
          end
        end
      end
      CR

    color = registry.find_enum("App::Color").not_nil!
    color.base_type.should eq("UInt8")
    color.constants.should eq([{"Red", nil}, {"Green", "5"}])
    color.methods.map(&.name).should eq(["warm?"])
    registry.find_module!("App").methods.should be_empty
  end

  it "records annotations and aliases" do
    registry = visit_source <<-CR
      module App
        annotation Serializable; end
        class Point; end
        alias Pair = Tuple(Int32, Int32)
        alias Location = Point
      end
      CR

    registry.annotations.map(&.name).should eq(["App::Serializable"])
    registry.aliases.map { |alias_info| {alias_info.name, alias_info.target} }.should eq([
      {"App::Pair", "Tuple(Int32, Int32)"},
      {"App::Location", "App::Point"},
    ])
  end
end
