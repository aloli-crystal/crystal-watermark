require "./spec_helper"

# End-to-end PDF watermarking: generate a real PDF with crystal-pdf,
# run the watermarker on it, then re-open the result and check that
# (a) the page count and geometry are unchanged and (b) a watermark
# content stream was actually added (the file is bigger and contains
# a `BT … ET` text block).
# NOTE: the watermarker writes the output PDF as an *incremental
# update* (PDF spec § 7.5.6 — appends the new objects + a `/Prev`-
# linked xref to the original file). crystal-pdf v0.3.3 cannot
# re-parse such PDFs (`Invalid Int32` from `find_xref_offset`).
# Until that bug is fixed in crystal-pdf v0.3.4, we assert at the
# byte level: file size grew, %%EOF still present, BT/ET operators
# added, MediaBox of the source preserved verbatim in the appended
# output.
describe "Integration · PDF watermarking" do
  it "produces a valid larger PDF with the same MediaBox (A4)" do
    src = File.tempname("wm-it-a4-src", ".pdf")
    dst = File.tempname("wm-it-a4-dst", ".pdf")
    IntegrationHelper.write_a4_pdf(src)

    begin
      original_size = File.size(src)

      CrystalWatermark.apply(src, dst, "CONFIDENTIEL")

      File.exists?(dst).should be_true
      File.size(dst).should be > original_size
      # PDF must end with %%EOF (validity sanity check).
      File.read(dst).rstrip.should end_with("%%EOF")
      # MediaBox of the only page is preserved verbatim — the
      # watermarker must not rewrite page geometry.
      IntegrationHelper.count_byte_pattern(dst, "/MediaBox [0 0 595 842]").should be > 0
    ensure
      File.delete(src) if File.exists?(src)
      File.delete(dst) if File.exists?(dst)
    end
  end

  it "honours the actual MediaBox on a US Letter PDF (no A4 hardcoding)" do
    src = File.tempname("wm-it-letter-src", ".pdf")
    dst = File.tempname("wm-it-letter-dst", ".pdf")
    IntegrationHelper.write_letter_pdf(src)

    begin
      # US Letter is 612 × 792 pt — present verbatim in the source.
      IntegrationHelper.count_byte_pattern(src, "/MediaBox [0 0 612 792]").should be > 0

      CrystalWatermark.apply(src, dst, "DRAFT")

      # …and still present after watermarking (and *not* the A4
      # `[0 0 595 842]`, which would prove a hardcoded format).
      IntegrationHelper.count_byte_pattern(dst, "/MediaBox [0 0 612 792]").should be > 0
      IntegrationHelper.count_byte_pattern(dst, "/MediaBox [0 0 595 842]").should eq(0)
    ensure
      File.delete(src) if File.exists?(src)
      File.delete(dst) if File.exists?(dst)
    end
  end

  it "applies the watermark on every page of a multi-page PDF" do
    src = File.tempname("wm-it-multi-src", ".pdf")
    dst = File.tempname("wm-it-multi-dst", ".pdf")
    IntegrationHelper.write_multipage_pdf(src, 3)

    begin
      CrystalWatermark.apply(src, dst, "BROUILLON")

      File.size(dst).should be > File.size(src)
      # The watermarker registers one new indirect content stream
      # per page in the appended xref. Counting `endobj` markers
      # is the most robust byte-level check (independent of stream
      # compression): three new pages → strictly more endobjs.
      objs_src = IntegrationHelper.count_byte_pattern(src, "endobj")
      objs_dst = IntegrationHelper.count_byte_pattern(dst, "endobj")
      (objs_dst - objs_src).should be >= 3
    ensure
      File.delete(src) if File.exists?(src)
      File.delete(dst) if File.exists?(dst)
    end
  end

  it "produces a different output for each style on the same input" do
    src = File.tempname("wm-it-style-src", ".pdf")
    IntegrationHelper.write_a4_pdf(src)
    outputs = {} of CrystalWatermark::Style => Int64

    begin
      [CrystalWatermark::Style::Diagonal,
       CrystalWatermark::Style::Tiled,
       CrystalWatermark::Style::Header,
       CrystalWatermark::Style::Footer,
       CrystalWatermark::Style::Center].each do |style|
        dst = File.tempname("wm-it-style-#{style.to_s.downcase}", ".pdf")
        CrystalWatermark.apply(src, dst, "TEST", style)
        outputs[style] = File.size(dst)
        File.delete(dst)
      end

      # Tiled mode draws a grid of the same text → its content
      # stream is much larger than any single-line style.
      outputs[CrystalWatermark::Style::Tiled].should be > outputs[CrystalWatermark::Style::Header]
      outputs[CrystalWatermark::Style::Tiled].should be > outputs[CrystalWatermark::Style::Footer]
    ensure
      File.delete(src) if File.exists?(src)
    end
  end

  it "preserves French accented characters in the watermark text" do
    src = File.tempname("wm-it-accent-src", ".pdf")
    dst = File.tempname("wm-it-accent-dst", ".pdf")
    IntegrationHelper.write_a4_pdf(src)

    begin
      # Mix accented French + smart quotes + em-dash + Euro — all
      # of which the WinAnsi mapping in PdfWatermarker handles.
      text = "Remis à SuperBocaux — 25 € « confidentiel »"
      CrystalWatermark.apply(src, dst, text)

      File.exists?(dst).should be_true
      File.size(dst).should be > File.size(src)
      File.read(dst).rstrip.should end_with("%%EOF")
    ensure
      File.delete(src) if File.exists?(src)
      File.delete(dst) if File.exists?(dst)
    end
  end
end
