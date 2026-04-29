require "option_parser"
require "./watermark"

# CLI entry point for crystal-watermark.
#
# Built into a native binary by `shards build --release`, which writes
# to `bin/crystal-watermark`. The previous layout shipped this script
# directly under `bin/`; moving it to `src/cli.cr` lets the build step
# overwrite the binary safely without ever touching a tracked source
# file.

# Default values
text = ""
output = ""
style_name = "diagonal"
opacity = 0.15
color_str = "0.5,0.5,0.5"
font_size = 48
rotation : Float64? = nil

parser = OptionParser.new do |p|
  p.banner = "Usage: crystal-watermark FICHIER [options]"
  p.separator ""
  p.separator "Options :"

  p.on("-t TEXTE", "--text TEXTE", "Texte du filigrane (obligatoire)") { |t| text = t }
  p.on("-o FICHIER", "--output FICHIER", "Fichier de sortie") { |o| output = o }
  p.on("-s STYLE", "--style STYLE", "Style : diagonal, header, footer, center, tiled") { |s| style_name = s }
  p.on("--opacity OPACITE", "Opacité (0.0 à 1.0, défaut : 0.15)") { |o| opacity = o.to_f }
  p.on("--color R,G,B", "Couleur RGB (défaut : 0.5,0.5,0.5)") { |c| color_str = c }
  p.on("--font-size TAILLE", "Taille du texte (défaut : 48)") { |s| font_size = s.to_i }
  p.on("--rotation ANGLE", "Angle de rotation en degrés") { |r| rotation = r.to_f }
  p.on("-v", "--version", "Afficher la version") do
    puts "crystal-watermark #{Watermark::VERSION}"
    exit 0
  end
  p.on("-h", "--help", "Afficher l'aide") do
    puts p
    exit 0
  end

  p.invalid_option do |flag|
    STDERR.puts "Option inconnue : #{flag}"
    STDERR.puts p
    exit 1
  end
end

# Collect the positional arguments (the input file path). `OptionParser`
# in Crystal exposes them through `unknown_args` rather than as a return
# value; ARGV is consumed in place.
positional = [] of String
parser.unknown_args { |args| positional = args }
parser.parse(ARGV)

if positional.empty?
  STDERR.puts "Erreur : aucun fichier spécifié"
  STDERR.puts parser
  exit 1
end

input = positional.first

if text.empty?
  STDERR.puts "Erreur : le texte du filigrane est obligatoire (-t)"
  STDERR.puts parser
  exit 1
end

# Default output path: alongside the input, with `-watermarked` appended
# to the stem. Image inputs always come out as PNG (the engine doesn't
# write back JPEG), PDF inputs stay PDF.
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
  exit 1
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
          exit 1
        end

# Default rotation depends on the style (45° for diagonal/tiled, 0°
# otherwise). Wrap in `as(Float64)` so the literal-vs-nilable union
# resolves to a non-nilable Float64 the Options constructor will accept.
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
rescue ex
  STDERR.puts "Erreur : #{ex.message}"
  exit 1
end
