require "../spec_helper"

describe Cruml::Entities::ClassInfo do
  it "initializes with name and type" do
    class_info = Cruml::Entities::ClassInfo.new("Person", :class)
    class_info.name.should eq("Person")
    class_info.type.should eq(:class)
    class_info.instance_vars.should be_empty
    class_info.superclass.should be_nil
    class_info.struct?.should be_false
    class_info.methods.should be_empty
  end

  it "adds an instance variable" do
    class_info = Cruml::Entities::ClassInfo.new("Person", :class)
    class_info.add_instance_var("first_name", "String")
    class_info.instance_vars.should eq([{"first_name", "String"}])
  end

  it "replaces an existing instance variable with the same name" do
    class_info = Cruml::Entities::ClassInfo.new("Person", :class)
    class_info.add_instance_var("first_name", "String")
    class_info.add_instance_var("first_name", "Int32") # replace the ivar with different type.
    class_info.instance_vars.should eq([{"first_name", "Int32"}])
  end

  it "initializes a struct" do
    class_info = Cruml::Entities::ClassInfo.new("Point", :class, :struct)
    class_info.struct?.should be_true
    class_info.kind_label.should eq("struct")
  end

  it "sets the superclass" do
    class_info = Cruml::Entities::ClassInfo.new("Employee", :class)
    class_info.superclass = "Person"
    class_info.superclass.should eq("Person")
  end

  it "adds included and extended modules once" do
    class_info = Cruml::Entities::ClassInfo.new("Person", :class)
    class_info.add_included_module("Greeter")
    class_info.add_included_module("Greeter")
    class_info.add_extended_module("Loggable")
    class_info.included_modules.should eq(["Greeter"])
    class_info.extended_modules.should eq(["Loggable"])
  end

  it "adds a method" do
    class_info = Cruml::Entities::ClassInfo.new("Person", :class)
    method_info = Cruml::Entities::MethodInfo.new(:public, "major?", "Bool")

    class_info.add_method(method_info)
    class_info.methods.should eq([method_info])
  end

  it "adds the initialize method at the beginning" do
    class_info = Cruml::Entities::ClassInfo.new("Person", :class)
    initialize_method = Cruml::Entities::MethodInfo.new(:public, "initialize", "Nil")
    is_major_method = Cruml::Entities::MethodInfo.new(:public, "major?", "Bool")
    class_info.add_method(is_major_method)
    class_info.add_method(initialize_method)
    class_info.methods.should eq([initialize_method, is_major_method])
  end
end
