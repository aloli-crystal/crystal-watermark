# Filigranage de fichiers PDF via pdf Reader.
# Injecte un content stream avec le filigrane sur chaque page.
require "pdf/src/pdf"

module Watermark
  class PdfWatermarker
    def initialize(@text : String, @style : Style = Style::Diagonal, @options : Options = Options.new)
    end

    # Filigrane un PDF et l'enregistre dans output_path
    def apply(input_path : String, output_path : String) : Nil
      reader = PDF::Reader.open(input_path)

      reader.pages.each do |page|
        stream = build_watermark_stream(page.width, page.height)
        page.add_content_stream(stream)
      end

      reader.save(output_path)
    end

    # Construit le content stream PDF pour le filigrane
    private def build_watermark_stream(page_width : Float64, page_height : Float64) : String
      case @style
      when Style::Diagonal
        build_diagonal_stream(page_width, page_height)
      when Style::Tiled
        build_tiled_stream(page_width, page_height)
      when Style::Header
        build_header_stream(page_width, page_height)
      when Style::Footer
        build_footer_stream(page_width, page_height)
      when Style::Center
        build_center_stream(page_width, page_height)
      else
        build_diagonal_stream(page_width, page_height)
      end
    end

    # Filigrane en diagonale au centre de la page
    private def build_diagonal_stream(w : Float64, h : Float64) : String
      r, g, b = @options.color
      opacity = @options.opacity

      # Utiliser l'angle de la diagonale de la page (pas 45° fixe)
      angle = Math.atan2(h, w)
      cos_a = Math.cos(angle)
      sin_a = Math.sin(angle)

      cx = w / 2.0
      cy = h / 2.0

      lines = @text.split('\n')

      # Longueur de la diagonale disponible (avec marge)
      diagonal = Math.sqrt(w * w + h * h) - @options.margin * 2

      # Trouver la ligne la plus longue
      max_chars = lines.max_of(&.size)

      # Auto-ajuster la taille pour que le texte tienne dans la diagonale
      # Helvetica ≈ 0.52 * font_size par caractère
      max_size = (diagonal / (max_chars * 0.52)).to_i
      size = Math.min(@options.font_size, max_size)

      # Couleur avec opacité simulée (mélange avec le blanc du fond)
      adjusted_r = 1.0 - (1.0 - r) * opacity
      adjusted_g = 1.0 - (1.0 - g) * opacity
      adjusted_b = 1.0 - (1.0 - b) * opacity

      String.build do |io|
        io << "q\n"
        io << format_number(adjusted_r) << " "
        io << format_number(adjusted_g) << " "
        io << format_number(adjusted_b) << " rg\n"

        io << "BT\n"
        io << "/Helvetica " << size << " Tf\n"

        lines.each_with_index do |line, i|
          char_width = size * 0.52
          text_width = line.size * char_width

          # Décalage vertical pour chaque ligne (perpendiculaire à la diagonale)
          line_offset = ((lines.size - 1) / 2.0 - i) * (size * 1.4)

          # Point de départ du texte : centré sur la diagonale
          # Le texte commence à mi-diagonale moins demi-largeur du texte
          start_along = (diagonal - text_width) / 2.0 + @options.margin

          # Convertir en coordonnées page
          tx = start_along * cos_a - line_offset * sin_a
          ty = start_along * sin_a + line_offset * cos_a

          io << format_number(cos_a) << " " << format_number(sin_a) << " "
          io << format_number(-sin_a) << " " << format_number(cos_a) << " "
          io << format_number(tx) << " " << format_number(ty) << " Tm\n"
          io << "(" << escape_pdf_string(line) << ") Tj\n"
        end

        io << "ET\n"
        io << "Q\n"
      end
    end

    # Filigrane en mosaïque (répété sur toute la page)
    private def build_tiled_stream(w : Float64, h : Float64) : String
      r, g, b = @options.color
      size = (@options.font_size * 0.6).to_i # Plus petit pour la mosaïque
      angle = @options.rotation * Math::PI / 180.0

      # Couleur avec opacité simulée
      adjusted_r = 1.0 - (1.0 - r) * @options.opacity
      adjusted_g = 1.0 - (1.0 - g) * @options.opacity
      adjusted_b = 1.0 - (1.0 - b) * @options.opacity

      lines = @text.split('\n')
      first_line = lines.first

      # Espacement entre les répétitions
      text_width = first_line.size * size * 0.5
      spacing_x = text_width + 80
      spacing_y = size * lines.size * 1.5 + 80

      cos_a = Math.cos(angle)
      sin_a = Math.sin(angle)

      String.build do |io|
        io << "q\n"
        io << format_number(adjusted_r) << " "
        io << format_number(adjusted_g) << " "
        io << format_number(adjusted_b) << " rg\n"
        io << "BT\n"
        io << "/Helvetica " << size << " Tf\n"

        # Grille de filigranes
        y = -h * 0.5
        while y < h * 1.5
          x = -w * 0.5
          while x < w * 1.5
            lines.each_with_index do |line, i|
              # Position avec rotation
              rx = x * cos_a - (y + i * size * 1.2) * sin_a
              ry = x * sin_a + (y + i * size * 1.2) * cos_a

              if rx > -200 && rx < w + 200 && ry > -200 && ry < h + 200
                io << format_number(cos_a) << " " << format_number(sin_a) << " "
                io << format_number(-sin_a) << " " << format_number(cos_a) << " "
                io << format_number(rx) << " " << format_number(ry) << " Tm\n"
                io << "(" << escape_pdf_string(line) << ") Tj\n"
              end
            end
            x += spacing_x
          end
          y += spacing_y
        end

        io << "ET\n"
        io << "Q\n"
      end
    end

    # Filigrane en en-tête
    private def build_header_stream(w : Float64, h : Float64) : String
      build_horizontal_stream(w, h, h - @options.margin)
    end

    # Filigrane en pied de page
    private def build_footer_stream(w : Float64, h : Float64) : String
      build_horizontal_stream(w, h, @options.margin.to_f64)
    end

    # Filigrane centré horizontalement
    private def build_center_stream(w : Float64, h : Float64) : String
      build_horizontal_stream(w, h, h / 2.0)
    end

    # Construction d'un filigrane horizontal à une position Y donnée
    private def build_horizontal_stream(w : Float64, h : Float64, y_pos : Float64) : String
      r, g, b = @options.color
      size = @options.font_size

      adjusted_r = 1.0 - (1.0 - r) * @options.opacity
      adjusted_g = 1.0 - (1.0 - g) * @options.opacity
      adjusted_b = 1.0 - (1.0 - b) * @options.opacity

      lines = @text.split('\n')

      String.build do |io|
        io << "q\n"
        io << format_number(adjusted_r) << " "
        io << format_number(adjusted_g) << " "
        io << format_number(adjusted_b) << " rg\n"
        io << "BT\n"
        io << "/Helvetica " << size << " Tf\n"

        lines.each_with_index do |line, i|
          text_width = line.size * size * 0.5
          text_x = (w - text_width) / 2.0
          text_y = y_pos - i * size * 1.2

          io << format_number(text_x) << " " << format_number(text_y) << " Td\n"
          io << "(" << escape_pdf_string(line) << ") Tj\n"
          io << format_number(-text_x) << " " << format_number(-text_y) << " Td\n"
        end

        io << "ET\n"
        io << "Q\n"
      end
    end

    # Convertit une chaîne UTF-8 en WinAnsiEncoding (Windows-1252)
    # et échappe les caractères spéciaux pour une chaîne PDF
    private def escape_pdf_string(text : String) : String
      result = String.build do |io|
        text.each_char do |char|
          case char
          when '\\' then io << "\\\\"
          when '('  then io << "\\("
          when ')'  then io << "\\)"
          else
            code = char.ord
            if code < 128
              # ASCII direct
              io << char
            else
              # Convertir en WinAnsiEncoding (octal escape)
              win_code = utf8_to_winansi(code)
              if win_code > 0
                io << "\\" << win_code.to_s(8).rjust(3, '0')
              else
                io << '?' # Caractère non supporté
              end
            end
          end
        end
      end
      result
    end

    # Table de conversion Unicode → WinAnsiEncoding pour les caractères courants
    private def utf8_to_winansi(code : Int32) : Int32
      case code
      # Caractères Latin-1 Supplement (0x80-0xFF) — même position en WinAnsi
      when 0xC0..0xFF then code # À-ÿ (accents français, allemands, espagnols, etc.)
      # Caractères spéciaux Windows-1252 (zone 0x80-0x9F)
      when 0x2013 then 0x96 # – (en-dash)
      when 0x2014 then 0x97 # — (em-dash)
      when 0x2018 then 0x91 # ' (left single quote)
      when 0x2019 then 0x92 # ' (right single quote / apostrophe)
      when 0x201C then 0x93 # " (left double quote)
      when 0x201D then 0x94 # " (right double quote)
      when 0x2022 then 0x95 # • (bullet)
      when 0x2026 then 0x85 # … (ellipsis)
      when 0x20AC then 0x80 # € (euro sign)
      when 0x0152 then 0x8C # Œ
      when 0x0153 then 0x9C # œ
      when 0x0160 then 0x8A # Š
      when 0x0161 then 0x9A # š
      when 0x0178 then 0x9F # Ÿ
      when 0x017D then 0x8E # Ž
      when 0x017E then 0x9E # ž
      when 0x2020 then 0x86 # † (dagger)
      when 0x2021 then 0x87 # ‡ (double dagger)
      when 0x2030 then 0x89 # ‰ (per mille)
      when 0x2039 then 0x8B # ‹
      when 0x203A then 0x9B # ›
      when 0x0192 then 0x83 # ƒ
      when 0x02C6 then 0x88 # ˆ
      when 0x02DC then 0x98 # ˜
      else             0    # Non supporté
      end
    end

    # Formate un nombre pour le PDF (6 décimales max, pas de zéros inutiles)
    private def format_number(n : Float64) : String
      if n == n.to_i64.to_f64
        n.to_i64.to_s
      else
        sprintf("%.4f", n).gsub(/0+$/, "").gsub(/\.$/, ".0")
      end
    end
  end
end
