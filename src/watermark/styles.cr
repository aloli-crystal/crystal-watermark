module Watermark
  # Styles de filigrane disponibles
  enum Style
    Diagonal # Texte en diagonale au centre (45°)
    Header   # Texte en haut, horizontal
    Footer   # Texte en bas, horizontal
    Center   # Texte centré, sans rotation
    Tiled    # Texte répété en mosaïque
  end
end
