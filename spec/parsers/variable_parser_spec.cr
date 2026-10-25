require "../spec_helper"

private def accessors(code : String)
  Cruml::Parsers::VariableParser.parse_accessors(Crystal::Parser.parse(code).as(Crystal::Call))
end

private def infer(code : String)
  Cruml::Parsers::VariableParser.infer_type(Crystal::Parser.parse(code))
end

describe Cruml::Parsers::VariableParser do
  it "parses a typed property" do
    result = accessors("property name : String").not_nil!

    result.size.should eq(1)
    result[0].name.should eq("name")
    result[0].type.should eq("String")
    result[0].var_name.should eq("@name")
    result[0].getter?.should be_true
    result[0].setter?.should be_true
  end

  it "parses several getters in one call" do
    result = accessors("getter x : Int32, y : Int32").not_nil!

    result.map(&.name).should eq(["x", "y"])
    result.map(&.setter?).should eq([false, false])
  end

  it "infers the type from the default value" do
    result = accessors("getter? alive = true").not_nil!

    result[0].type.should eq("Bool")
    result[0].predicate?.should be_true
  end

  it "keeps untyped accessors without a type" do
    result = accessors("setter name").not_nil!

    result[0].type.should be_nil
    result[0].getter?.should be_false
  end

  it "makes the variable of a `getter!` nilable" do
    result = accessors("getter! area : Float64").not_nil!

    result[0].nilable?.should be_true
    result[0].var_type.should eq("Float64?")
  end

  it "parses class-level accessors" do
    result = accessors("class_getter count : Int32").not_nil!

    result[0].class_level.should be_true
    result[0].var_name.should eq("@@count")
  end

  it "returns nil for other calls" do
    accessors("puts name").should be_nil
    accessors("foo.getter name : String").should be_nil
  end

  it "infers literal types" do
    infer(%("text")).should eq("String")
    infer("1").should eq("Int32")
    infer("1_u8").should eq("UInt8")
    infer("1.5").should eq("Float64")
    infer("[] of String").should eq("Array(String)")
    infer("{} of String => Int32").should eq("Hash(String, Int32)")
    infer("Foo::Bar.new(1)").should eq("Foo::Bar")
    infer("compute").should be_nil
  end
end
