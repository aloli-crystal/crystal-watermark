# Rendu et positionnement du texte pour le filigrane.
# Calcule les positions des caractères selon le style choisi,
# et dessine les glyphes bitmap sur un canvas StumpyPNG.
require "stumpy_png"

module Watermark
  class TextRenderer
    # Facteur d'échelle : ratio entre font_size demandé et la hauteur de base du glyphe (16px)
    getter scale : Int32
    getter font_size : Int32

    def initialize(@font_size : Int32)
      @scale = Math.max(1, @font_size // BitmapFont::GLYPH_HEIGHT)
    end

    # Largeur d'un caractère mis à l'échelle
    def char_width : Int32
      BitmapFont::GLYPH_WIDTH * @scale
    end

    # Hauteur d'un caractère mis à l'échelle
    def char_height : Int32
      BitmapFont::GLYPH_HEIGHT * @scale
    end

    # Largeur totale d'une ligne de texte
    def text_width(text : String) : Int32
      text.size * char_width
    end

    # Hauteur totale du texte (multi-lignes)
    def text_height(text : String) : Int32
      lines = text.split('\n')
      lines.size * char_height + (lines.size - 1) * (@scale * 2)
    end

    # Calcule les positions de placement du filigrane selon le style
    def compute_positions(style : Style, image_width : Int32, image_height : Int32, text : String, options : Options) : Array(Tuple(Int32, Int32))
      positions = [] of Tuple(Int32, Int32)

      case style
      when Style::Diagonal
        # Un seul filigrane centré en diagonale
        cx = image_width // 2 - text_width(text) // 2
        cy = image_height // 2 - char_height // 2
        positions << {cx, cy}
      when Style::Header
        # Texte en haut, centré horizontalement
        cx = image_width // 2 - text_width(text) // 2
        positions << {cx, options.margin}
      when Style::Footer
        # Texte en bas, centré horizontalement
        cx = image_width // 2 - text_width(text) // 2
        positions << {cx, image_height - options.margin - char_height}
      when Style::Center
        # Texte centré sans rotation
        cx = image_width // 2 - text_width(text) // 2
        cy = image_height // 2 - char_height // 2
        positions << {cx, cy}
      when Style::Tiled
        # Mosaïque : répétition sur toute l'image
        spacing_x = text_width(text) + options.margin * 2
        spacing_y = char_height + options.margin * 2
        # Élargir la zone pour la rotation
        y = -image_height
        while y < image_height * 2
          x = -image_width
          while x < image_width * 2
            positions << {x, y}
            x += spacing_x
          end
          y += spacing_y
        end
      end

      positions
    end

    # Dessine le texte d'un filigrane sur un canvas StumpyPNG
    def render(canvas : StumpyPNG::Canvas, text : String, x : Int32, y : Int32,
               color : Tuple(Float64, Float64, Float64), opacity : Float64,
               rotation : Float64)
      # Séparer les lignes
      lines = text.split('\n')

      # Centre de rotation = centre du texte
      max_line_width = lines.max_of { |line| text_width(line) }
      total_height = lines.size * char_height + (lines.size - 1) * (@scale * 2)
      cx = x + max_line_width / 2.0
      cy = y + total_height / 2.0

      # Pré-calculer sin/cos pour la rotation
      rad = rotation * Math::PI / 180.0
      cos_r = Math.cos(rad)
      sin_r = Math.sin(rad)

      # Couleur du filigrane en valeurs 16 bits (StumpyPNG utilise UInt16)
      wr = (color[0] * 65535).to_u16
      wg = (color[1] * 65535).to_u16
      wb = (color[2] * 65535).to_u16

      lines.each_with_index do |line, line_idx|
        line_y = y + line_idx * (char_height + @scale * 2)

        line.each_char_with_index do |char, char_idx|
          glyph = BitmapFont.glyph(char)
          char_x = x + char_idx * char_width

          # Parcourir chaque pixel du glyphe mis à l'échelle
          BitmapFont::GLYPH_HEIGHT.times do |gy|
            row = glyph[gy]
            BitmapFont::GLYPH_WIDTH.times do |gx|
              # Vérifier si le pixel est allumé (bit de gauche = bit 7)
              next unless (row >> (7 - gx)) & 1 == 1

              # Dessiner le pixel mis à l'échelle
              @scale.times do |sy|
                @scale.times do |sx|
                  # Position du pixel avant rotation
                  px = char_x + gx * @scale + sx
                  py = line_y + gy * @scale + sy

                  # Appliquer la rotation autour du centre du texte
                  dx = px - cx
                  dy = py - cy
                  rpx = (cx + dx * cos_r - dy * sin_r).to_i
                  rpy = (cy + dx * sin_r + dy * cos_r).to_i

                  # Vérifier les limites du canvas
                  next if rpx < 0 || rpx >= canvas.width
                  next if rpy < 0 || rpy >= canvas.height

                  # Alpha blending avec le pixel existant
                  existing = canvas[rpx, rpy]
                  er = existing.r
                  eg = existing.g
                  eb = existing.b

                  nr = (wr.to_f64 * opacity + er.to_f64 * (1.0 - opacity)).to_u16
                  ng = (wg.to_f64 * opacity + eg.to_f64 * (1.0 - opacity)).to_u16
                  nb = (wb.to_f64 * opacity + eb.to_f64 * (1.0 - opacity)).to_u16

                  canvas[rpx, rpy] = StumpyPNG::RGBA.new(nr, ng, nb, 65535_u16)
                end
              end
            end
          end
        end
      end
    end
  end
end
