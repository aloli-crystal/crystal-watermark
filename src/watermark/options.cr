module Watermark
  # Options de configuration du filigrane
  class Options
    property font_size : Int32 = 48
    property color : Tuple(Float64, Float64, Float64) = {0.5, 0.5, 0.5} # RGB entre 0.0 et 1.0
    property opacity : Float64 = 0.15
    property rotation : Float64 = 45.0
    property repeat : Bool = false
    property margin : Int32 = 50

    def initialize(
      @font_size : Int32 = 48,
      @color : Tuple(Float64, Float64, Float64) = {0.5, 0.5, 0.5},
      @opacity : Float64 = 0.15,
      @rotation : Float64 = 45.0,
      @repeat : Bool = false,
      @margin : Int32 = 50,
    )
    end
  end
end
