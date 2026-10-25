require "../spec_helper"

describe Cruml::Parsers::ClassParser do
  it "identifies interface by name" do
    node = Crystal::Parser.parse("class MyInterface; end").as(Crystal::ClassDef)

    class_type = Cruml::Parsers::ClassParser.determine_class_type("MyInterface", node)
    class_type.should eq(:interface)
  end

  it "identifies abstract class" do
    node = Crystal::Parser.parse("abstract class MyClass; end").as(Crystal::ClassDef)

    class_type = Cruml::Parsers::ClassParser.determine_class_type("MyClass", node)
    class_type.should eq(:abstract)
  end

  it "identifies normal class" do
    node = Crystal::Parser.parse("class MyClass; end").as(Crystal::ClassDef)

    class_type = Cruml::Parsers::ClassParser.determine_class_type("MyClass", node)
    class_type.should eq(:class)
  end

  it "extracts generic type parameters" do
    node = Crystal::Parser.parse("class Container(T); end").as(Crystal::ClassDef)

    generics = Cruml::Parsers::ClassParser.extract_generics(node)
    generics.should eq("(T)")
  end

  it "extracts multiple generic parameters" do
    node = Crystal::Parser.parse("class Pair(K, V); end").as(Crystal::ClassDef)

    generics = Cruml::Parsers::ClassParser.extract_generics(node)
    generics.should eq("(K, V)")
  end

  it "returns nil for non-generic class" do
    node = Crystal::Parser.parse("class MyClass; end").as(Crystal::ClassDef)

    generics = Cruml::Parsers::ClassParser.extract_generics(node)
    generics.should be_nil
  end

  it "returns the name of a referenced type" do
    include_node = Crystal::Parser.parse("include MyNamespace::MyModule").as(Crystal::Include)
    Cruml::Parsers::ClassParser.reference_name(include_node.name).should eq("MyNamespace::MyModule")

    generic_node = Crystal::Parser.parse("include Comparable(Point)").as(Crystal::Include)
    Cruml::Parsers::ClassParser.reference_name(generic_node.name).should eq("Comparable(Point)")
  end

  it "returns nil for `extend self`" do
    node = Crystal::Parser.parse("extend self").as(Crystal::Extend)
    Cruml::Parsers::ClassParser.reference_name(node.name).should be_nil
  end

  it "returns true for interface names" do
    result = Cruml::Parsers::ClassParser.interface?("MyInterface")
    result.should be_true
  end

  it "returns true for interface names in any case" do
    result = Cruml::Parsers::ClassParser.interface?("Myinterface")
    result.should be_true
  end

  it "returns false for non-interface names" do
    result = Cruml::Parsers::ClassParser.interface?("MyClass")
    result.should be_false
  end
end
