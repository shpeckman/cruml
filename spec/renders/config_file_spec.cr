require "../spec_helper"

describe Cruml::Renders::ConfigFile do
  it "parses the default configuration" do
    config = Cruml::Renders::ConfigFile.from_yaml(Cruml::Renders::Config.default_yaml)

    config.paths.should eq(["src/"])
    config.namespaces.should eq({"Namespace" => ["ClassOne", "ClassTwo", "ClassThree"]})
    config.theme_colors(:light).try(&.classes).should eq("#baa7e5")
    config.theme_colors(:dark).try(&.structs).should eq("#6b1a45")
  end

  it "accepts missing and empty sections" do
    config = Cruml::Renders::ConfigFile.from_yaml("paths:\nnamespaces:\n")

    config.paths.should be_empty
    config.namespaces.should be_empty
    config.theme_colors(:light).should be_nil
  end

  it "falls back to default colors" do
    Cruml::Renders::Config.file = Cruml::Renders::ConfigFile.from_yaml(%(colors: {light: {classes: "#123456"}}))

    Cruml::Renders::Config.class_color.should eq("#123456")
    Cruml::Renders::Config.module_color.should eq("#1158f3")
  ensure
    Cruml::Renders::Config.file = Cruml::Renders::ConfigFile.new
  end

  it "loads an empty file as the default configuration" do
    path = File.tempname("cruml", ".yml")
    File.write(path, "")

    Cruml::Renders::ConfigFile.load(path).paths.should be_empty
  ensure
    File.delete(path) if path && File.exists?(path)
  end
end
