# frozen_string_literal: true

require 'dotenv'
require 'open-uri'
require 'openai'
require 'pdf-reader'
require 'csv'
require 'tiktoken_ruby'

DOC_EMBEDDINGS_MODEL = 'text-embedding-ada-002'

class ParsePdf
  Dotenv.load

  def count_tokens(text)
    enc = Tiktoken.get_encoding('cl100k_base')
    enc.encode(text).length
  end

  def extract_pages(page_text, index)
    content = page_text.gsub(/\s+/, ' ').strip
    puts "Page text: #{content}"
    [["Page #{index}", content, count_tokens(content) + 4]]
  end

  def get_embedding(text, model)
    openai_client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])

    result = openai_client.embeddings(
      parameters: {
        model:,
        input: text
      }
    )

    result['data'][0]['embedding']
  end

  def get_doc_embedding(text)
    get_embedding(text, DOC_EMBEDDINGS_MODEL)
  end

  def compute_doc_embeddings(rows)
    rows.map { |row| get_doc_embedding(row[1]) }
  end

  def run
    pdf_path = Rails.root.join('app', 'assets', 'pdf', 'resume.pdf')
    reader = PDF::Reader.new(pdf_path)

    res = []
    i = 1
    reader.pages.each do |page|
      res += extract_pages(page.text, i)
      i += 1
    end

    csv_pages_path = Rails.root.join('storage', 'csv', 'resume.pages.csv')

    CSV.open(csv_pages_path, 'wb') do |csv|
      csv << %w[title content tokens]
      res.each { |row| csv << row }
    end

    doc_embeddings = compute_doc_embeddings(res)

    csv_embeddings_path = Rails.root.join('storage', 'csv', 'resume.embeddings.csv')

    CSV.open(csv_embeddings_path, 'wb') do |csv|
      csv << ['title'] + (0...4096).to_a
      doc_embeddings.each_with_index do |embedding, i|
        csv << ["Page #{i + 1}"] + embedding
      end
    end
  end
end
