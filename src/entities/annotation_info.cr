# This consists of obtaining information about an annotation.
class Cruml::Entities::AnnotationInfo
  # Annotation name
  getter name : String

  def initialize(@name : String); end
end
