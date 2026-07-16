require "option_parser"
require "../watermark"

module Watermark
  # Callable CLI entry point. Exposing the command as a method (rather
  # than top-level code in `src/cli.cr`) lets it run both as the
  # standalone `watermark` binary AND in-process from the unified
  # `alolipdf` binary (aloli-crystal/pdf-tools). Returns the exit code
  # instead of calling `exit`.
  module Cli
    # Carries an early-exit code out of OptionParser's *captured* blocks
    # (Crystal forbids `return` from those). Caught in `.run`.
    private class Halt < Exception
      getter code : Int32

      def initialize(@code : Int32)
        super()
      end
    end

    def self.run(argv : Array(String)) : Int32
      text = ""
      output = ""
      style_name = "diagonal"
      opacity = 0.15
      color_str = "0.5,0.5,0.5"
      font_size = 48
      rotation : Float64? = nil
      rasterize = false
      rasterize_dpi = 200
      rasterize_quality = 85

      parser = OptionParser.new do |p|
        p.banner = "Usage: watermark FICHIER [options]"
        p.separator ""
        p.separator "Options :"

        p.on("-t TEXTE", "--text TEXTE", "Texte du filigrane (obligatoire)") { |t| text = t }
        p.on("-o FICHIER", "--output FICHIER", "Fichier de sortie") { |o| output = o }
        p.on("-s STYLE", "--style STYLE", "Style : diagonal, header, footer, center, tiled") { |s| style_name = s }
        p.on("--opacity OPACITE", "Opacité (0.0 à 1.0, défaut : 0.15)") { |o| opacity = o.to_f }
        p.on("--color R,G,B", "Couleur RGB (défaut : 0.5,0.5,0.5)") { |c| color_str = c }
        p.on("--font-size TAILLE", "Taille du texte (défaut : 48)") { |s| font_size = s.to_i }
        p.on("--rotation ANGLE", "Angle de rotation en degrés") { |r| rotation = r.to_f }
        p.on("-R", "--rasterize",
          "Rastérise le PDF de sortie (chaque page devient une image JPEG plein page). " \
          "Rend le filigrane indissociable du contenu — pattern anti-falsification de DossierFacile. " \
          "Délègue à `crystal-combine-pdf rasterize` (qui doit être installé + Ghostscript).") do
          rasterize = true
        end
        p.on("--rasterize-dpi N", "DPI de rastérisation (défaut : 200)") { |v| rasterize_dpi = v.to_i }
        p.on("--rasterize-quality Q", "Qualité JPEG 0-100 (défaut : 85)") { |v| rasterize_quality = v.to_i }
        p.on("-v", "--version", "Afficher la version") do
          puts "watermark #{Watermark::VERSION}"
          raise Halt.new(0)
        end
        p.on("-h", "--help", "Afficher l'aide") do
          puts p
          raise Halt.new(0)
        end

        p.invalid_option do |flag|
          STDERR.puts "Option inconnue : #{flag}"
          STDERR.puts p
          raise Halt.new(1)
        end
      end

      positional = [] of String
      parser.unknown_args { |args| positional = args }
      parser.parse(argv)

      if positional.empty?
        STDERR.puts "Erreur : aucun fichier spécifié"
        STDERR.puts parser
        return 1
      end

      input = positional.first

      if text.empty?
        STDERR.puts "Erreur : le texte du filigrane est obligatoire (-t)"
        STDERR.puts parser
        return 1
      end

      if output.empty?
        ext = File.extname(input)
        base = File.basename(input, ext)
        dir = File.dirname(input)
        out_ext = ext.downcase == ".pdf" ? ".pdf" : ".png"
        output = File.join(dir, "#{base}-watermarked#{out_ext}")
      end

      color_parts = color_str.split(',').map(&.to_f)
      if color_parts.size != 3
        STDERR.puts "Erreur : la couleur doit être au format R,G,B (ex : 0.5,0.5,0.5)"
        return 1
      end
      color = {color_parts[0], color_parts[1], color_parts[2]}

      style = case style_name.downcase
              when "diagonal" then Watermark::Style::Diagonal
              when "header"   then Watermark::Style::Header
              when "footer"   then Watermark::Style::Footer
              when "center"   then Watermark::Style::Center
              when "tiled"    then Watermark::Style::Tiled
              else
                STDERR.puts "Erreur : style inconnu « #{style_name} »"
                return 1
              end

      rot = (rotation || (style == Watermark::Style::Diagonal || style == Watermark::Style::Tiled ? 45.0 : 0.0)).as(Float64)
      options = Watermark::Options.new(
        font_size: font_size,
        color: color,
        opacity: opacity,
        rotation: rot,
        margin: 50,
      )

      begin
        Watermark.apply(input, output, text, style, options)
        puts "Filigrane appliqué : #{output}"

        # Post-traitement rastérisation : rend le filigrane
        # indissociable du contenu en convertissant chaque page en
        # JPEG plein page. Délègue à `crystal-combine-pdf rasterize`
        # qui sait orchestrer gs (Ghostscript) + reconstruction PDF.
        # Pattern observé chez DossierFacile pour les RIB protégés.
        if rasterize
          ccp = Process.find_executable("crystal-combine-pdf")
          if ccp.nil?
            STDERR.puts "Erreur : --rasterize nécessite `crystal-combine-pdf` dans le PATH."
            STDERR.puts "Installation : voir aloli-crystal/crystal-combine-pdf."
            return 1
          end
          err_buf = IO::Memory.new
          status = Process.run(
            ccp,
            ["rasterize", output, "-i",
             "--dpi", rasterize_dpi.to_s,
             "--quality", rasterize_quality.to_s],
            output: Process::Redirect::Close,
            error: err_buf,
          )
          unless status.success?
            STDERR.puts "Erreur : crystal-combine-pdf rasterize a échoué (exit #{status.exit_code})."
            STDERR.puts err_buf.to_s.lines.first?.try(&.strip) || ""
            return 1
          end
          puts "✓ Rastérisé (#{rasterize_dpi} dpi, qualité #{rasterize_quality}) — filigrane indissociable."
        end
        0
      rescue ex
        STDERR.puts "Erreur : #{ex.message}"
        1
      end
    rescue ex : Halt
      ex.code
    end
  end
end
