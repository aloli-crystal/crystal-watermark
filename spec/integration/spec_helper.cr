require "spec"
require "../../src/crystal_watermark"

# Integration-test helpers: spin up real PDFs through `pdf`,
# run the watermarker on them, then re-open the result with
# `PDF::Reader` to assert that the file is still a valid PDF and
# that a watermark content stream was actually added.
#
# Pure Crystal — no external `pdftotext`, `qpdf` or `pdfinfo`.
module IntegrationHelper
  # Generates a 1-page A4 PDF at `path` with a couple of lines of
  # text so the watermark has something to overlay on.
  def self.write_a4_pdf(path : String, *,
                        title : String = "Test A4 document",
                        body : String = "Some body text on a real A4 page.") : Nil
    pdf = PDF::Document.new
    pdf.page(size: :a4) do |page|
      page.font("Helvetica", size: 14)
      page.text(title, at: {72, 750})
      page.text(body, at: {72, 720})
    end
    pdf.save(path)
  end

  # Generates a multi-page A4 PDF (one numbered page per requested
  # entry) — used to assert that the watermark is applied to every
  # page, not just the first.
  def self.write_multipage_pdf(path : String, page_count : Int32) : Nil
    pdf = PDF::Document.new
    page_count.times do |i|
      pdf.page(size: :a4) do |page|
        page.font("Helvetica", size: 14)
        page.text("Page #{i + 1} of #{page_count}", at: {72, 750})
      end
    end
    pdf.save(path)
  end

  # Generates a Letter-format PDF, used to verify the watermarker
  # honours the actual MediaBox rather than hardcoding A4.
  def self.write_letter_pdf(path : String) : Nil
    pdf = PDF::Document.new
    pdf.page(size: :letter) do |page|
      page.font("Helvetica", size: 14)
      page.text("US Letter document", at: {72, 720})
    end
    pdf.save(path)
  end

  # Re-opens a PDF and returns the number of pages. Confirms the
  # output is parseable.
  def self.page_count(path : String) : Int32
    PDF::Reader.open(path).page_count
  end

  # Returns the `MediaBox` (left, bottom, right, top) of page index
  # `i` of the PDF at `path`. Used to check the watermarker did not
  # alter the page geometry.
  def self.page_size(path : String, i : Int32 = 0) : Tuple(Float64, Float64)
    page = PDF::Reader.open(path).pages[i]
    {page.width, page.height}
  end

  # Counts the number of byte-level occurrences of `pattern` in the
  # raw bytes of `pdf_path`. Avoids regex (would crash on non-UTF-8
  # bytes from compressed streams).
  def self.count_byte_pattern(pdf_path : String, pattern : String) : Int32
    bytes = File.read(pdf_path).to_slice
    needle = pattern.to_slice
    return 0 if needle.size == 0 || needle.size > bytes.size
    count = 0
    i = 0
    last = bytes.size - needle.size
    while i <= last
      match = true
      j = 0
      while j < needle.size
        if bytes[i + j] != needle[j]
          match = false
          break
        end
        j += 1
      end
      if match
        count += 1
        i += needle.size
      else
        i += 1
      end
    end
    count
  end
end
