require "./spec_helper"

describe CrystalWatermark::ImageWatermarker do
  # Chemins des fichiers de test
  test_png = File.join(SPEC_TMP_DIR, "test_document.png")
  test_gradient = File.join(SPEC_TMP_DIR, "test_gradient.png")
  output_png = File.join(SPEC_TMP_DIR, "output_watermarked.png")

  # Créer les images de test avant les specs
  before_each do
    Dir.mkdir_p(SPEC_TMP_DIR)
    create_test_document(test_png)
    create_test_gradient(test_gradient)
    File.delete(output_png) if File.exists?(output_png)
  end

  describe "#apply (chemin vers chemin)" do
    it "filigraner une image PNG avec le style diagonal" do
      watermarker = CrystalWatermark::ImageWatermarker.new("CONFIDENTIEL", CrystalWatermark::Style::Diagonal)
      watermarker.apply(test_png, output_png)

      File.exists?(output_png).should be_true
      # Vérifier que le fichier de sortie est un PNG valide et non vide
      File.size(output_png).should be > 0

      # Relire l'image et vérifier les dimensions
      result = StumpyPNG.read(output_png)
      result.width.should eq(400)
      result.height.should eq(300)
    end

    it "filigraner une image avec le style header" do
      watermarker = CrystalWatermark::ImageWatermarker.new("EN-TETE", CrystalWatermark::Style::Header)
      watermarker.apply(test_png, output_png)

      File.exists?(output_png).should be_true
      result = StumpyPNG.read(output_png)
      result.width.should eq(400)
      result.height.should eq(300)
    end

    it "filigraner une image avec le style footer" do
      watermarker = CrystalWatermark::ImageWatermarker.new("PIED DE PAGE", CrystalWatermark::Style::Footer)
      watermarker.apply(test_png, output_png)

      File.exists?(output_png).should be_true
    end

    it "filigraner une image avec le style center" do
      watermarker = CrystalWatermark::ImageWatermarker.new("CENTRE", CrystalWatermark::Style::Center)
      watermarker.apply(test_png, output_png)

      File.exists?(output_png).should be_true
    end

    it "filigraner une image avec le style tiled" do
      watermarker = CrystalWatermark::ImageWatermarker.new("COPIE", CrystalWatermark::Style::Tiled)
      watermarker.apply(test_png, output_png)

      File.exists?(output_png).should be_true
    end

    it "modifie effectivement les pixels de l'image" do
      # Lire l'image originale
      original = StumpyPNG.read(test_png)

      # Appliquer le filigrane avec une opacité forte pour être sûr que les pixels changent
      options = CrystalWatermark::Options.new(opacity: 0.5, font_size: 48)
      watermarker = CrystalWatermark::ImageWatermarker.new("TEST", CrystalWatermark::Style::Center, options)
      watermarker.apply(test_png, output_png)

      # Lire l'image filigranée
      result = StumpyPNG.read(output_png)

      # Compter les pixels différents
      changed = 0
      original.width.times do |x|
        original.height.times do |y|
          orig_pixel = original[x, y]
          res_pixel = result[x, y]
          if orig_pixel.r != res_pixel.r || orig_pixel.g != res_pixel.g || orig_pixel.b != res_pixel.b
            changed += 1
          end
        end
      end

      # Le filigrane doit avoir modifié au moins quelques pixels
      changed.should be > 0
    end

    it "applique les options de couleur et opacité" do
      options = CrystalWatermark::Options.new(
        color: {0.8, 0.1, 0.1},
        opacity: 0.30,
        font_size: 32
      )
      watermarker = CrystalWatermark::ImageWatermarker.new("ROUGE", CrystalWatermark::Style::Center, options)
      watermarker.apply(test_png, output_png)

      File.exists?(output_png).should be_true
    end

    it "fonctionne avec l'image dégradé" do
      watermarker = CrystalWatermark::ImageWatermarker.new("WATERMARK", CrystalWatermark::Style::Diagonal)
      output_gradient = File.join(SPEC_TMP_DIR, "gradient_watermarked.png")
      watermarker.apply(test_gradient, output_gradient)

      File.exists?(output_gradient).should be_true
      result = StumpyPNG.read(output_gradient)
      result.width.should eq(200)
      result.height.should eq(200)
    end

    it "supporte les caractères accentués français" do
      watermarker = CrystalWatermark::ImageWatermarker.new("Remis à Société — été 2026", CrystalWatermark::Style::Diagonal)
      watermarker.apply(test_png, output_png)

      File.exists?(output_png).should be_true
    end
  end

  describe "gestion des erreurs" do
    it "lève une erreur pour un fichier inexistant" do
      watermarker = CrystalWatermark::ImageWatermarker.new("TEST")
      expect_raises(Exception, "Fichier introuvable") do
        watermarker.apply("/chemin/inexistant.png", output_png)
      end
    end

    it "lève une erreur pour un texte vide" do
      watermarker = CrystalWatermark::ImageWatermarker.new("")
      expect_raises(Exception, "texte du filigrane ne peut pas être vide") do
        watermarker.apply(test_png, output_png)
      end
    end

    it "lève une erreur pour un format non supporté" do
      watermarker = CrystalWatermark::ImageWatermarker.new("TEST")
      # Créer un fichier avec une extension non supportée
      bad_file = File.join(SPEC_TMP_DIR, "test.bmp")
      File.write(bad_file, "fake")
      expect_raises(Exception, "Format image non supporté") do
        watermarker.apply(bad_file, output_png)
      end
    end
  end
end

describe CrystalWatermark do
  test_png = File.join(SPEC_TMP_DIR, "test_api.png")
  output_png = File.join(SPEC_TMP_DIR, "output_api.png")

  before_each do
    Dir.mkdir_p(SPEC_TMP_DIR)
    create_test_document(test_png)
    File.delete(output_png) if File.exists?(output_png)
  end

  describe ".apply" do
    it "filigraner via l'API simplifiée" do
      CrystalWatermark.apply(test_png, output_png, "FILIGRANE")
      File.exists?(output_png).should be_true
    end

    it "filigrane un fichier PDF" do
      # Créer un vrai PDF de test via pdf
      pdf = PDF::Document.new
      pdf.page(size: :a4) do |page|
        page.font("Helvetica", size: 12)
        page.text("Document de test", at: {72, 750})
      end
      pdf_file = File.join(SPEC_TMP_DIR, "test.pdf")
      pdf.save(pdf_file)

      output_pdf = File.join(SPEC_TMP_DIR, "test-watermarked.pdf")
      CrystalWatermark.apply(pdf_file, output_pdf, "FILIGRANE TEST")
      File.exists?(output_pdf).should be_true
      File.size(output_pdf).should be > File.size(pdf_file)
    end

    it "lève une erreur pour un format inconnu" do
      unknown_file = File.join(SPEC_TMP_DIR, "test.tiff")
      File.write(unknown_file, "fake")
      expect_raises(Exception, "Format non supporté") do
        CrystalWatermark.apply(unknown_file, "out.tiff", "TEST")
      end
    end
  end
end
