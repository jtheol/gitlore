# frozen_string_literal: true

require_relative "gitlore/version"
require "openai"
require "tty-prompt"
require "tty-markdown"
require "pastel"
require "faraday"
require "json"

# Gitlore: Summarize git commits with AI.
# A CLI tool that transforms git commits into natural summaries.
module Gitlore
  @prompt = TTY::Prompt.new
  @pastel = Pastel.new

  def self.client
    @client ||= OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"]) if ENV["OPENAI_API_KEY"]
  end

  def self.choose_openai_model
    return nil unless client && api_key_error

    begin
      model_names = client.models.list.data.map(&:id).sort.select do |model|
        model.include?("gpt")
      end
      @prompt.select("Choose an OpenAI model:", model_names, per_page: 10)
    rescue StandardError => e
      puts "#{@pastel.red("Error listing models:")} #{e.message}"
      nil
    end
  end

  def self.summarize_git
    count = @prompt.ask("How many recent commits do you want to summarize?", default: "10").to_i
    provider = @prompt.select("Choose model provider", %w[openai ollama])
    style = @prompt.select("Choose summary style:", %w[narrative technical])

    git_log = `git log -n #{count} --pretty=format:"%h %s (%an)"`
    puts "\n#{@pastel.cyan("🧾 Git Log:")}\n\n#{git_log}\n\n"

    system_prompts = {
      "narrative" => "You are a skilled storyteller. Given a list of git commits, your task is to craft a concise and
      engaging narrative that captures the essence of the changes, making them accessible and compelling for a
      non-technical audience.",
      "technical" => "You are a senior software engineer. Given a list of git commits, your task is
      to produce a precise, technically accurate summary of the changes, suitable for other developers and engineers."
    }

    case provider
    when "openai"
      summarize_with_openai(git_log, system_prompts[style])
    else
      summarize_with_ollama(git_log, system_prompts[style])
    end
  end

  def self.summarize_with_openai(git_log, system_prompt)
    selected_model = choose_openai_model
    response = client.chat.completions.create(
      model: selected_model,
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: "Summarize these commits:\n\n#{git_log}" }
      ],
      temperature: 0
    )
    summary = response.choices[0].message.content
    puts TTY::Markdown.parse(summary)
    summary
  end

  def self.summarize_with_ollama(git_log, system_prompt)
    conn = Faraday.new(url: "http://localhost:11434") do |f|
      f.request :json
      f.adapter Faraday.default_adapter
    end

    models_response = conn.get("/api/tags")
    if models_response.status != 200
      puts "#{@pastel.red("Error:")} Could not fetch models from Ollama server. Check if Ollama is running."
      return "Failed to connect to Ollama."
    end

    models = JSON.parse(models_response.body)["models"]
    model_names = models.map { |m| m["name"] }

    if model_names.empty?
      puts "#{@pastel.red("Error:")} No models found on Ollama server."
      return "No models available."
    end

    local_model = @prompt.select("Choose the local model to use", model_names)

    chat_response = conn.post("/api/chat") do |req|
      req.headers["Content-Type"] = "application/json"
      req.body = {
        model: local_model,
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: "Summarize these commits:\n\n#{git_log}" }
        ],
        stream: false
      }
    end

    if chat_response.status != 200
      puts "#{@pastel.red("Error:")} Failed to get response from Ollama."
      return "Failed to get Ollama response."
    end

    summary = JSON.parse(chat_response.body)["message"]["content"]
    puts TTY::Markdown.parse(summary)
    summary
  end

  def self.api_key_error
    return true if ENV["OPENAI_API_KEY"]

    puts "#{@pastel.red("Error:")} OPENAI_API_KEY environment variable is not set."
    false
  end
end
