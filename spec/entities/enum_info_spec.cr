require "../spec_helper"

describe Cruml::Entities::EnumInfo do
  it "initializes with a name and a base type" do
    enum_info = Cruml::Entities::EnumInfo.new("Color", "UInt8")
    enum_info.name.should eq("Color")
    enum_info.base_type.should eq("UInt8")
    enum_info.constants.should be_empty
  end

  it "adds constants with optional values" do
    enum_info = Cruml::Entities::EnumInfo.new("Color")
    enum_info.add_constant("Red")
    enum_info.add_constant("Green", "5")
    enum_info.constants.should eq([{"Red", nil}, {"Green", "5"}])
  end

  it "holds methods" do
    enum_info = Cruml::Entities::EnumInfo.new("Color")
    method_info = Cruml::Entities::MethodInfo.new(:public, "warm?", "Bool")
    enum_info.add_method(method_info)
    enum_info.methods.should eq([method_info])
  end
end
