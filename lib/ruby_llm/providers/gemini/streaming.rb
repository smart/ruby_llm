# frozen_string_literal: true

module RubyLLM
  module Providers
    module Gemini
      # Streaming methods for the Gemini API implementation
      module Streaming
        def stream_url
          "models/#{@model}:streamGenerateContent?alt=sse"
        end

        def build_chunk(data)
          Chunk.new(
            role: :assistant,
            model_id: extract_model_id(data),
            content: extract_content(data),
            input_tokens: extract_input_tokens(data),
            output_tokens: extract_output_tokens(data),
            tool_calls: extract_tool_calls(data)
          )
        end

        private

        def extract_model_id(data)
          data['modelVersion']
        end

        def extract_content(data)
          return "" unless data['candidates']&.any?

          candidate = data['candidates'][0]
          parts = candidate.dig('content', 'parts')
          return "" unless parts

          text_parts = parts.select { |p| p['text'] }
          text_parts.any? ? text_parts.map { |p| p['text'] }.join : ""
        end

        def extract_input_tokens(data)
          data.dig('usageMetadata', 'promptTokenCount')
        end

        def extract_output_tokens(data)
          data.dig('usageMetadata', 'candidatesTokenCount')
        end

        def parse_streaming_error(data)
          error_data = JSON.parse(data)
          [error_data['error']['code'], error_data['error']['message']]
        rescue JSON::ParserError => e
          RubyLLM.logger.debug "Failed to parse streaming error: #{e.message}"
          [500, "Failed to parse error: #{data}"]
        end
      end
    end
  end
end
