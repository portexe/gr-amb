# frozen_string_literal: true

require_relative '../scripts/pdf_to_embeddings'

namespace :csv do
  desc 'Parse PDF and save as CSV with embeddings'

  task :parse_pdf do
    parser = ParsePdf.new
    parser.run
  end
end
