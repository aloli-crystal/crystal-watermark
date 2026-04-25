require "spec"
require "stumpy_png"
require "../src/crystal_watermark"

# Répertoire pour les fichiers de test temporaires
SPEC_TMP_DIR = File.join(__DIR__, "tmp")

# Créer le répertoire temporaire s'il n'existe pas
Dir.mkdir_p(SPEC_TMP_DIR)

# Génère une image PNG blanche avec des rectangles colorés (simule un document)
def create_test_document(path : String, width : Int32 = 400, height : Int32 = 300) : Nil
  canvas = StumpyPNG::Canvas.new(width, height)

  # Fond blanc
  width.times do |x|
    height.times do |y|
      canvas[x, y] = StumpyPNG::RGBA.new(65535_u16, 65535_u16, 65535_u16, 65535_u16)
    end
  end

  # Rectangle bleu en haut à gauche (simule un en-tête)
  (20...180).each do |x|
    (20...60).each do |y|
      canvas[x, y] = StumpyPNG::RGBA.new(13107_u16, 26214_u16, 52428_u16, 65535_u16)
    end
  end

  # Rectangle vert au centre (simule du contenu)
  (50...350).each do |x|
    (100...120).each do |y|
      canvas[x, y] = StumpyPNG::RGBA.new(13107_u16, 52428_u16, 13107_u16, 65535_u16)
    end
  end

  # Rectangle rouge en bas (simule un pied de page)
  (100...300).each do |x|
    (250...270).each do |y|
      canvas[x, y] = StumpyPNG::RGBA.new(52428_u16, 13107_u16, 13107_u16, 65535_u16)
    end
  end

  StumpyPNG.write(canvas, path)
end

# Génère une image PNG avec un dégradé
def create_test_gradient(path : String, width : Int32 = 200, height : Int32 = 200) : Nil
  canvas = StumpyPNG::Canvas.new(width, height)

  width.times do |x|
    height.times do |y|
      r = ((x.to_f / width) * 65535).to_u16
      g = ((y.to_f / height) * 65535).to_u16
      b = (((x + y).to_f / (width + height)) * 65535).to_u16
      canvas[x, y] = StumpyPNG::RGBA.new(r, g, b, 65535_u16)
    end
  end

  StumpyPNG.write(canvas, path)
end

# Nettoyage des fichiers temporaires après les tests
at_exit do
  FileUtils.rm_rf(SPEC_TMP_DIR) if Dir.exists?(SPEC_TMP_DIR)
end

require "file_utils"
