# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module RubyLLM
  # Generator for RubyLLM Rails models and migrations
  class InstallGenerator < Rails::Generators::Base
    include Rails::Generators::Migration
    namespace "ruby_llm:install"

    source_root File.expand_path('install/templates', __dir__)

    class_option :chat_model_name, type: :string, default: 'Chat',
                desc: 'Name of the Chat model class'
    class_option :message_model_name, type: :string, default: 'Message',
                desc: 'Name of the Message model class'
    class_option :tool_call_model_name, type: :string, default: 'ToolCall',
                desc: 'Name of the ToolCall model class'

    desc 'Creates model files for Chat, Message, and ToolCall, and creates migrations for RubyLLM Rails integration'

    def self.next_migration_number(dirname)
      ::ActiveRecord::Generators::Base.next_migration_number(dirname)
    end

    def migration_version
      "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
    end

    def postgresql?
      ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
    rescue StandardError
      false
    end

    def acts_as_chat_declaration
      acts_as_chat_params = []
      if options[:message_model_name]
        acts_as_chat_params << "message_class: \"#{options[:message_model_name]}\""
      end
      if options[:tool_call_model_name]
        acts_as_chat_params << "tool_call_class: \"#{options[:tool_call_model_name]}\""
      end
      if acts_as_chat_params.any?
        "acts_as_chat #{acts_as_chat_params.join(', ')}"
      else
        "acts_as_chat"
      end
    end

    def acts_as_message_declaration
      acts_as_message_params = []
      if options[:chat_model_name]
        acts_as_message_params << "chat_class: \"#{options[:chat_model_name]}\""
      end
      if options[:tool_call_model_name]
        acts_as_message_params << "tool_call_class: \"#{options[:tool_call_model_name]}\""
      end
      if acts_as_message_params.any?
        "acts_as_message #{acts_as_message_params.join(', ')}"
      else
        "acts_as_message"
      end
    end

    def acts_as_tool_call_declaration
      acts_as_tool_call_params = []
      if options[:message_model_name]
        acts_as_tool_call_params << "message_class: \"#{options[:message_model_name]}\""
      end
      if acts_as_tool_call_params.any?
        "acts_as_tool_call #{acts_as_tool_call_params.join(', ')}"
      else
        "acts_as_tool_call"
      end
    end

    def create_migration_files
      # Use a fixed timestamp for testing and to ensure they're sequential
      # @migration_number = Time.now.utc.strftime('%Y%m%d%H%M%S')
      migration_template 'create_chats_migration.rb.tt', "db/migrate/create_#{options[:chat_model_name].tableize}.rb"

      # Increment timestamp for the next migration
      # @migration_number = (@migration_number.to_i + 1).to_s
      migration_template 'create_messages_migration.rb.tt', "db/migrate/create_#{options[:message_model_name].tableize}.rb"

      # Increment timestamp again for the final migration
      # @migration_number = (@migration_number.to_i + 2).to_s
      migration_template 'create_tool_calls_migration.rb.tt', "db/migrate/create_#{options[:tool_call_model_name].tableize}.rb"
    end

    def create_model_files
      template 'chat_model.rb.tt', "app/models/#{options[:chat_model_name].underscore}.rb"
      template 'message_model.rb.tt', "app/models/#{options[:message_model_name].underscore}.rb"
      template 'tool_call_model.rb.tt', "app/models/#{options[:tool_call_model_name].underscore}.rb"
    end

    def create_initializer
      template 'initializer.rb.tt', 'config/initializers/ruby_llm.rb'
    end

    def show_readme
      content = ERB.new(File.read(source_paths.first + '/README.md.tt')).result(binding)
      say content
    end
  end
end
