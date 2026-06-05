require "./watermark/cli"

# Standalone `crystal-watermark` binary. All the logic lives in
# `Watermark::Cli.run` (in `src/watermark/cli.cr`) so it can also be
# called in-process from the unified `alolipdf` binary
# (aloli-crystal/pdf-tools).
exit Watermark::Cli.run(ARGV)
