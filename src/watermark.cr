# Point d'entrée principal du shard crystal-watermark.
# Fournit une API simple pour filigraner des images et des PDF.
require "./watermark/version"
require "./watermark/styles"
require "./watermark/options"
require "./watermark/bitmap_font"
require "./watermark/text_renderer"
require "./watermark/image_watermarker"
require "./watermark/pdf_watermarker"

module Watermark
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
