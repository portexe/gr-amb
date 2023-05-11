# frozen_string_literal: true

require 'csv'
require 'openai'
require 'json'
require 'dotenv'

class ApiController < ApplicationController
  skip_before_action :verify_authenticity_token

  Dotenv.load

  def vector_similarity(x, y)
    x.zip(y).map { |xi, yi| xi * yi }.reduce(0, :+)
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

  def order_document_sections_by_query_similarity(question_text, embeddings_csv)
    query_embedding = get_embedding(question_text, 'text-embedding-ada-002')

    document_similarities = embeddings_csv.map do |doc_index, doc_embedding|
      [vector_similarity(query_embedding, doc_embedding), doc_index]
    end

    document_similarities.sort_by { |similarity, _| -similarity }
  end

  def build_prompt(question_text, embeddings_csv, pages_csv)
    most_relevant_document_sections = order_document_sections_by_query_similarity(question_text, embeddings_csv)

    chosen_sections = []
    chosen_sections_len = 0
    chosen_sections_indexes = []

    separator = "\n* "
    separator_len = 3
    max_section_len = 5000

    most_relevant_document_sections.each do |_, section_index|
      document_section = pages_csv.select { |row| row['title'] == section_index }.first

      chosen_sections_len += document_section['tokens'].to_i + separator_len

      if chosen_sections_len > max_section_len
        space_left = max_section_len - chosen_sections_len - separator.length
        chosen_sections.append(separator + document_section['content'][0...space_left])
        chosen_sections_indexes.append(section_index.to_s)
        break
      end

      chosen_sections.append(separator + document_section['content'])
      chosen_sections_indexes.append(section_index.to_s)
    end

    # rubocop:disable Layout/LineLength
    prompt_header = "Zack Wilson is a Senior Software Engineer who used to work for Shopify and is now applying to Gumroad. Please respond as if you were Zack. Please keep your answers to three sentences maximum, and speak in complete sentences. Stop speaking once your point is made. Here is some context from Zacks cover letter and resume: \n"
    # rubocop:enable Layout/LineLength

    "#{prompt_header} #{chosen_sections.join} \n\n\nQ: #{question_text} \n\nA: "
  end

  def load_embeddings(csv_embeddings_path)
    embeddings = {}

    CSV.foreach(csv_embeddings_path, headers: true) do |row|
      title = row['title']
      max_dim = row.headers.select { |header| header =~ /^\d+$/ }.map(&:to_i).max
      embedding_values = (0..max_dim).map { |i| row[i.to_s].to_f }
      embeddings[title] = embedding_values
    end

    embeddings
  end

  def retrieve_answer(question_text)
    csv_pages_path = Rails.root.join('app', 'assets', 'csv', 'resume.pages.csv')
    csv_embeddings_path = Rails.root.join('app', 'assets', 'csv', 'resume.embeddings.csv')

    pages_csv = CSV.read(csv_pages_path, headers: true)
    embeddings_csv = load_embeddings(csv_embeddings_path)

    prompt = build_prompt(question_text, embeddings_csv, pages_csv)

    openai_client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])

    response = openai_client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
        temperature: 0.0,
        max_tokens: 150,
        messages: [{ role: 'user', content: prompt }]
      }
    )

    response['choices'][0]['message']['content']
  end

  def index
    question_text = params[:question]

    question_text += '?' unless question_text.end_with?('?')

    previous_question = Question.find_by(question: question_text)

    if previous_question
      render json: {
        question: previous_question.question,
        answer: previous_question.answer
      }
    else
      answer = retrieve_answer(question_text)

      Question.create(
        question: question_text,
        answer:
      )

      render json: {
        answer:,
        question: question_text
      }
    end
  end
end
