# Filigranage d'images PNG et JPEG.
# Utilise StumpyPNG et StumpyJPEG pour la lecture,
# et StumpyPNG pour l'écriture (PNG uniquement en sortie).
require "stumpy_png"
require "stumpy_jpeg"

module CrystalWatermark
  class ImageWatermarker
    def initialize(@text : String, @style : Style = Style::Diagonal, @options : Options = Options.new)
    end

    # Filigraner un fichier image (chemin vers chemin)
    def apply(input_path : String, output_path : String) : Nil
      raise "Fichier introuvable : #{input_path}" unless File.exists?(input_path)
      raise "Le texte du filigrane ne peut pas être vide" if @text.empty?

      ext = File.extname(input_path).downcase
      canvas = case ext
               when ".png"
                 StumpyPNG.read(input_path)
               when ".jpg", ".jpeg"
                 StumpyJPEG.read(input_path)
               else
                 raise "Format image non supporté : #{ext}"
               end

      apply_watermark(canvas)
      StumpyPNG.write(canvas, output_path)
    end

    # Filigraner un flux IO (format doit être :png ou :jpeg)
    def apply(input_io : IO, output_io : IO, format : Symbol) : Nil
      raise "Le texte du filigrane ne peut pas être vide" if @text.empty?

      canvas = case format
               when :png
                 StumpyPNG.read(input_io)
               when :jpeg, :jpg
                 StumpyJPEG.read(input_io)
               else
                 raise "Format non supporté : #{format}"
               end

      apply_watermark(canvas)
      StumpyPNG.write(canvas, output_io)
    end

    # Appliquer le filigrane sur le canvas
    private def apply_watermark(canvas : StumpyPNG::Canvas) : Nil
      renderer = TextRenderer.new(@options.font_size)

      # Déterminer l'angle de rotation selon le style
      rotation = case @style
                 when Style::Diagonal then @options.rotation
                 when Style::Tiled    then @options.rotation
                 when Style::Header   then 0.0
                 when Style::Footer   then 0.0
                 when Style::Center   then 0.0
                 else                      @options.rotation
                 end

      # Calculer les positions de placement
      positions = renderer.compute_positions(@style, canvas.width, canvas.height, @text, @options)

      # Dessiner le filigrane à chaque position
      positions.each do |pos|
        renderer.render(canvas, @text, pos[0], pos[1], @options.color, @options.opacity, rotation)
      end
    end
  end
end
