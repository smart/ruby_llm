# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Capabilities do # rubocop:disable RSpec/SpecFilePathFormat
  describe '.normalize_temperature' do
    it 'forces temperature to 1.0 for O1 models' do
      o1_models = %w[o1 o1-mini o1-preview o3-mini]

      o1_models.each do |model|
        result = described_class.normalize_temperature(0.7, model)
        expect(result).to eq(1.0)
      end
    end

    it 'preserves temperature for non-O1 models' do
      non_o1_models = ['gpt-4', 'gpt-4.1', 'gpt-4o', 'claude-3-opus']

      non_o1_models.each do |model|
        result = described_class.normalize_temperature(0.7, model)
        expect(result).to eq(0.7)
      end
    end
  end
end
