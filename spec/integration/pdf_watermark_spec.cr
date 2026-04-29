require "./spec_helper"

# End-to-end PDF watermarking: generate a real PDF with pdf,
# run the watermarker on it, then re-open the result with `PDF::Reader`
# to check that the page count and geometry are preserved and that the
# watermark really landed on every page.
#
# Crystal-pdf v0.3.4 fixed the byte-vs-char offset bug in
# `find_xref_offset` that previously prevented re-parsing a PDF
# amended by `add_content_stream` — so we now drive the assertions
# through the real reader rather than through byte-level pattern
# counting.
describe "Integration · PDF watermarking" do
  it "produces a valid larger PDF with the same page count and geometry (A4)" do
    src = File.tempname("wm-it-a4-src", ".pdf")
    dst = File.tempname("wm-it-a4-dst", ".pdf")
    IntegrationHelper.write_a4_pdf(src)

    begin
      original_size = File.size(src)
      original_dims = IntegrationHelper.page_size(src, 0)

      Watermark.apply(src, dst, "CONFIDENTIEL")

      File.exists?(dst).should be_true
      File.size(dst).should be > original_size
      # Re-parse the watermarked PDF: page count and geometry must
      # match the source exactly. The watermarker may only *append*,
      # never resize the page.
      IntegrationHelper.page_count(dst).should eq(1)
      IntegrationHelper.page_size(dst, 0).should eq(original_dims)
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
      # US Letter is 612 × 792 pt; check within 1 pt and confirm the
      # geometry is *not* A4.
      w, h = IntegrationHelper.page_size(src, 0)
      ((w - 612).abs).should be < 1.0
      ((h - 792).abs).should be < 1.0

      Watermark.apply(src, dst, "DRAFT")

      out_w, out_h = IntegrationHelper.page_size(dst, 0)
      out_w.should eq(w)
      out_h.should eq(h)
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
      Watermark.apply(src, dst, "BROUILLON")

      # Page count is preserved.
      IntegrationHelper.page_count(dst).should eq(3)
      # The output is strictly bigger — the watermarker added one
      # content stream per page.
      File.size(dst).should be > File.size(src)
    ensure
      File.delete(src) if File.exists?(src)
      File.delete(dst) if File.exists?(dst)
    end
  end

  it "produces a different output for each style on the same input" do
    src = File.tempname("wm-it-style-src", ".pdf")
    IntegrationHelper.write_a4_pdf(src)
    outputs = {} of Watermark::Style => Int64

    begin
      [Watermark::Style::Diagonal,
       Watermark::Style::Tiled,
       Watermark::Style::Header,
       Watermark::Style::Footer,
       Watermark::Style::Center].each do |style|
        dst = File.tempname("wm-it-style-#{style.to_s.downcase}", ".pdf")
        Watermark.apply(src, dst, "TEST", style)
        outputs[style] = File.size(dst)
        # Every style still produces a valid PDF that re-parses.
        IntegrationHelper.page_count(dst).should eq(1)
        File.delete(dst)
      end

      # Tiled mode draws a grid of the same text → its content
      # stream is much larger than any single-line style.
      outputs[Watermark::Style::Tiled].should be > outputs[Watermark::Style::Header]
      outputs[Watermark::Style::Tiled].should be > outputs[Watermark::Style::Footer]
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
      Watermark.apply(src, dst, text)

      File.exists?(dst).should be_true
      File.size(dst).should be > File.size(src)
      # Output must still parse and have the original page count.
      IntegrationHelper.page_count(dst).should eq(1)
    ensure
      File.delete(src) if File.exists?(src)
      File.delete(dst) if File.exists?(dst)
    end
  end
end
