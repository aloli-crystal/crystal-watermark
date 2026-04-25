# Point d'entrée principal du shard crystal-watermark.
# Fournit une API simple pour filigraner des images et des PDF.
require "./crystal_watermark/version"
require "./crystal_watermark/styles"
require "./crystal_watermark/options"
require "./crystal_watermark/bitmap_font"
require "./crystal_watermark/text_renderer"
require "./crystal_watermark/image_watermarker"
require "./crystal_watermark/pdf_watermarker"

module CrystalWatermark
  # Filigraner un fichier (image ou PDF) avec un texte
  def self.apply(input : String, output : String, text : String,
                 style : Style = Style::Diagonal,
                 options : Options = Options.new) : Nil
    ext = File.extname(input).downcase
    case ext
    when ".png", ".jpg", ".jpeg"
      ImageWatermarker.new(text, style, options).apply(input, output)
    when ".pdf"
      PdfWatermarker.new(text, style, options).apply(input, output)
    else
      raise "Format non supporté : #{ext}"
    end
  end
end
