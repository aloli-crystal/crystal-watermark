require "./spec_helper"

describe CrystalWatermark::Options do
  describe "#initialize" do
    it "utilise les valeurs par défaut" do
      opts = CrystalWatermark::Options.new
      opts.font_size.should eq(48)
      opts.color.should eq({0.5, 0.5, 0.5})
      opts.opacity.should eq(0.15)
      opts.rotation.should eq(45.0)
      opts.repeat.should be_false
      opts.margin.should eq(50)
    end

    it "accepte des valeurs personnalisées" do
      opts = CrystalWatermark::Options.new(
        font_size: 72,
        color: {0.8, 0.1, 0.1},
        opacity: 0.30,
        rotation: 30.0,
        repeat: true,
        margin: 100
      )
      opts.font_size.should eq(72)
      opts.color.should eq({0.8, 0.1, 0.1})
      opts.opacity.should eq(0.30)
      opts.rotation.should eq(30.0)
      opts.repeat.should be_true
      opts.margin.should eq(100)
    end
  end

  describe "propriétés modifiables" do
    it "permet de modifier font_size après création" do
      opts = CrystalWatermark::Options.new
      opts.font_size = 96
      opts.font_size.should eq(96)
    end

    it "permet de modifier opacity après création" do
      opts = CrystalWatermark::Options.new
      opts.opacity = 0.5
      opts.opacity.should eq(0.5)
    end
  end
end
