---
layout: default
title: Rails Integration
parent: Guides
nav_order: 5
permalink: /guides/rails
---

# Rails Integration
{: .no_toc }

RubyLLM offers seamless integration with Ruby on Rails applications through helpers for ActiveRecord models. This allows you to easily persist chat conversations, including messages and tool interactions, directly in your database.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   How to set up ActiveRecord models for persisting chats and messages.
*   How to use `acts_as_chat` and `acts_as_message`.
*   How chat interactions automatically persist data.
*   A basic approach for integrating streaming responses with Hotwire/Turbo Streams.

## Setup


### Using the Generator (Recommended)

The easiest way to set up RubyLLM with Rails is to use the built-in generator:

```bash
rails generate ruby_llm:install
```

This will automatically:
1. Create the necessary migrations for chats, messages, and tool calls
2. Create model files with appropriate `acts_as_*` methods
3. Set up proper relationships between models

After running the generator, simply run the migrations:

```bash
rails db:migrate
```

### Manual Setup

If you prefer to set up manually or need to customize the implementation, follow these steps:

#### 1. Create Migrations

Create the necessary tables in your database:

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_chats.rb
class CreateChats < ActiveRecord::Migration[7.1]
  def change
    create_table :chats do |t|
      t.string :model_id
      t.references :user # Optional: Example association
      t.timestamps
    end
  end
end

# db/migrate/YYYYMMDDHHMMSS_create_messages.rb
class CreateMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :messages do |t|
      t.references :chat, null: false, foreign_key: true
      t.string :role
      t.text :content
      # Optional fields for tracking usage/metadata
      t.string :model_id
      t.integer :input_tokens
      t.integer :output_tokens
      t.references :tool_call # Links tool result message to the initiating call
      t.timestamps
    end
  end
end

# db/migrate/YYYYMMDDHHMMSS_create_tool_calls.rb
# (Only needed if using tools)
class CreateToolCalls < ActiveRecord::Migration[7.1]
  def change
    create_table :tool_calls do |t|
      t.references :message, null: false, foreign_key: true # Assistant message making the call
      t.string :tool_call_id, null: false, index: { unique: true } # Provider's ID for the call
      t.string :name, null: false
      t.jsonb :arguments, default: {} # Use jsonb for PostgreSQL
      t.timestamps
    end
  end
end
```

Run the migrations: `rails db:migrate`

### Set Up Models with `acts_as` Helpers

Include the RubyLLM helpers in your ActiveRecord models.

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  # Includes methods like ask, with_tool, with_instructions, etc.
  # Automatically persists associated messages and tool calls.
  acts_as_chat # Assumes Message and ToolCall model names

  # --- Add your standard Rails model logic below ---
  belongs_to :user, optional: true
  validates :model_id, presence: true
end

# app/models/message.rb
class Message < ApplicationRecord
  # Provides methods like tool_call?, tool_result?
  acts_as_message # Assumes Chat and ToolCall model names

  # --- Add your standard Rails model logic below ---
  # Optional: Use Rails enums for roles
  enum role: { system: 'system', user: 'user', assistant: 'assistant', tool: 'tool' }
end

# app/models/tool_call.rb (Only if using tools)
class ToolCall < ApplicationRecord
  # Sets up associations to the calling message and the result message.
  acts_as_tool_call # Assumes Message model name

  # --- Add your standard Rails model logic below ---
end
```

<<<<<<< HEAD
{: .note }
The `acts_as` helpers primarily handle loading history and saving messages/tool calls related to the chat interaction. Add your application-specific logic (associations, validations, scopes, callbacks) as usual.
=======
#### 2. Set Up Models
>>>>>>> 119df52 (feat: add Rails generator for RubyLLM models)

### Configure RubyLLM

Ensure your RubyLLM configuration (API keys, etc.) is set up, typically in `config/initializers/ruby_llm.rb`. See the [Installation Guide]({% link installation.md %}) for details.

## Basic Usage

The `acts_as_chat` helper delegates common `RubyLLM::Chat` methods to your `Chat` model. When you call these methods on an ActiveRecord `Chat` instance, RubyLLM automatically handles persistence.

```ruby
# Create a new chat record
chat_record = Chat.create!(model_id: 'gpt-4.1-nano', user: current_user)

# The `model_id` should typically be a valid identifier known to RubyLLM.
# See the [Working with Models Guide]({% link guides/models.md %}) for details.

# Ask a question. This automatically:
# 1. Saves the user message ("What is the capital...")
# 2. Makes the API call with history
# 3. Saves the assistant message (the response)
response = chat_record.ask "What is the capital of France?"

# `response` is the RubyLLM::Message object from the API call.
# The persisted record is associated with `chat_record`.
assistant_message_record = chat_record.messages.last
puts assistant_message_record.content # => "The capital of France is Paris."

# Continue the conversation
chat_record.ask "Tell me more about that city"

# Verify persistence
puts "Conversation length: #{chat_record.messages.count}" # => 4
```

## Persisting Instructions

Instructions (system prompts) set via `with_instructions` are also automatically persisted as `Message` records with the `system` role.

```ruby
chat_record = Chat.create!(model_id: 'gpt-4.1-nano')

# This creates and saves a Message record with role: :system
chat_record.with_instructions("You are a Ruby expert.")

# This replaces the previous system message in the database
chat_record.with_instructions("You are a concise Ruby expert.", replace: true)

system_message = chat_record.messages.find_by(role: :system)
puts system_message.content # => "You are a concise Ruby expert."
```

## Streaming Responses with Hotwire/Turbo

You can combine `acts_as_chat` with streaming and Turbo Streams for real-time UI updates. The persistence logic works seamlessly alongside the streaming block.

Here's a simplified approach using a background job:

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  acts_as_chat
  belongs_to :user, optional: true
  # Broadcast message creations to the chat channel
  broadcasts_to ->(chat) { [chat, "messages"] }
end

# app/models/message.rb
class Message < ApplicationRecord
  acts_as_message
  # Broadcast updates to self (for streaming into the message frame)
  broadcasts_to ->(message) { [message.chat, "messages"] }

  # Helper to broadcast chunks during streaming
  def broadcast_append_chunk(chunk_content)
    broadcast_append_to [ chat, "messages" ], # Target the stream
      target: dom_id(self, "content"), # Target the content div inside the message frame
      html: chunk_content # Append the raw chunk
  end
end

# app/jobs/chat_stream_job.rb
class ChatStreamJob < ApplicationJob
  queue_as :default

  def perform(chat_id, user_content)
    chat = Chat.find(chat_id)
    # The `ask` method automatically saves the user message first.
    # It then creates the assistant message record *before* streaming starts,
    # and updates it with the final content/tokens upon completion.
    chat.ask(user_content) do |chunk|
      # Get the latest (assistant) message record, which was created by `ask`
      assistant_message = chat.messages.last
      if chunk.content && assistant_message
        # Append the chunk content to the message's target div
        assistant_message.broadcast_append_chunk(chunk.content)
      end
    end
    # Final assistant message is now fully persisted by acts_as_chat
  end
end
```

```erb
<%# app/views/chats/show.html.erb %>
<%= turbo_stream_from [@chat, "messages"] %>
<h1>Chat <%= @chat.id %></h1>
<div id="messages">
  <%= render @chat.messages %>
</div>
<!-- Your form to submit new messages -->
<%= form_with(url: chat_messages_path(@chat), method: :post) do |f| %>
  <%= f.text_area :content %>
  <%= f.submit "Send" %>
<% end %>

<%# app/views/messages/_message.html.erb %>
<%= turbo_frame_tag message do %>
  <div class="message <%= message.role %>">
    <strong><%= message.role.capitalize %>:</strong>
    <%# Target div for streaming content %>
    <div id="<%= dom_id(message, "content") %>" style="display: inline;">
      <%# Render initial content if not streaming, otherwise job appends here %>
      <%= simple_format(message.content) %>
    </div>
  </div>
<% end %>
```

{: .note }
This example shows the core idea. You'll need to adapt the broadcasting, targets, and partials for your specific UI needs (e.g., handling Markdown rendering, adding styling, showing typing indicators). See the [Streaming Responses Guide]({% link guides/streaming.md %}) for more on streaming itself.

## Customizing Models

Your `Chat`, `Message`, and `ToolCall` models are standard ActiveRecord models. You can add any other associations, validations, scopes, callbacks, or methods as needed for your application logic. The `acts_as` helpers provide the core persistence bridge to RubyLLM without interfering with other model behavior.

## Next Steps

*   [Chatting with AI Models]({% link guides/chat.md %})
*   [Using Tools]({% link guides/tools.md %})
*   [Streaming Responses]({% link guides/streaming.md %})
*   [Working with Models]({% link guides/models.md %})
*   [Error Handling]({% link guides/error-handling.md %})