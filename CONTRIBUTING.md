# Contributing to RubyLLM

First off, thank you for considering contributing to RubyLLM! It's people like you that make RubyLLM such a great tool.

## Development Setup

Here's how to get started:

```bash
# Clone the repository
gh repo clone crmne/ruby_llm
cd ruby_llm

# Install dependencies
bundle install

# Set up git hooks
overcommit --install

# Run the tests (uses VCR cassettes)
bundle exec rspec
```

## Development Workflow

We recommend using GitHub CLI to simplify the workflow:

```bash
# Create a new branch for your feature
gh repo fork crmne/ruby_llm --clone
cd ruby_llm

# Find or make an issue for the feature on GitHub and then:
gh issue develop 123 --checkout  # Substitute 123 with the issue number

# Make your changes and test them
# ...

# Commit your changes
git commit

# Create a PR
gh pr create --web
```

## Model Naming Convention & Provider Strategy

When adding new providers to RubyLLM, please follow these guidelines:

### Normalized Model IDs

We use a consistent approach separating **what** (model) from **where** (provider):

```ruby
# Default way (from the native provider)
chat = RubyLLM.chat(model: "claude-3-5-sonnet")

# Same model via different provider
chat = RubyLLM.chat(model: "claude-3-5-sonnet", provider: :bedrock)
```

### Implementing a Provider

If you're adding a new provider:

1. **Use normalized model IDs** - Don't include provider prefixes in the model ID itself
2. **Add provider mapping** - Map the normalized IDs to your provider's specific format internally
3. **Preserve capabilities** - Ensure models accessed through your provider report the same capabilities as their native counterparts
4. **Update models.json** - Include your provider's models in models.json
5. **Update aliases.json** - Add entries to aliases.json for models accessible through your provider
6. **Implement refresh mechanism** - Ensure your provider supports the `list_models` method for refreshing

### Model Aliases

For providers that use complex model identifiers (like Bedrock's `anthropic.claude-3-5-sonnet-20241022-v2:0:200k`), add mappings to the global aliases.json file:

```json
{
  "claude-3-5-sonnet": {
    "anthropic": "claude-3-5-sonnet-20241022",
    "bedrock": "anthropic.claude-3-5-sonnet-20241022-v2:0:200k",
    "openrouter": "anthropic/claude-3.5-sonnet"
  },
  "gpt-4o": {
    "openai": "gpt-4o-2024-05-13",
    "bedrock": "anthropic.gpt-4o-2024-05-13",
    "openrouter": "openai/gpt-4o"
  }
}
```

If a model can't be found with the provided ID and provider, a `ModelNotFoundError` will be raised with an informative message. Your implementation should make this error helpful by suggesting available alternatives.

When the same model has multiple versions and context windows e.g.

```
anthropic.claude-3-5-sonnet-20240620-v1:0
anthropic.claude-3-5-sonnet-20240620-v1:0:18k
anthropic.claude-3-5-sonnet-20240620-v1:0:200k
anthropic.claude-3-5-sonnet-20240620-v1:0:51k
anthropic.claude-3-5-sonnet-20241022-v2:0
anthropic.claude-3-5-sonnet-20241022-v2:0:18k
anthropic.claude-3-5-sonnet-20241022-v2:0:200k
anthropic.claude-3-5-sonnet-20241022-v2:0:51k
```

We default all aliases to the biggest context window, and the main alias (without date) to the latest version:

```json
  "claude-3-5-sonnet": {
    "anthropic": "claude-3-5-sonnet-20241022",
    "bedrock": "anthropic.claude-3-5-sonnet-20241022-v2:0:200k",
    "openrouter": "anthropic/claude-3.5-sonnet"
  },
  "claude-3-5-sonnet-20241022": {
    "anthropic": "claude-3-5-sonnet-20241022",
    "bedrock": "anthropic.claude-3-5-sonnet-20241022-v2:0:200k",
    "openrouter": "anthropic/claude-3.5-sonnet"
  },
  "claude-3-5-sonnet-20240620": {
    "anthropic": "claude-3-5-sonnet-20240620",
    "bedrock": "anthropic.claude-3-5-sonnet-20240620-v1:0:200k"
  },
```

## Running Tests

Tests automatically use VCR to record and replay HTTP interactions, so you don't need real API keys for testing:

```bash
# Run all tests (using existing VCR cassettes)
bundle exec rspec

# Run a specific test file
bundle exec rspec spec/ruby_llm/chat_spec.rb

# Run generator template tests
bundle exec rspec spec/lib/generators/ruby_llm/template_files_spec.rb
```

### Recording VCR Cassettes

When you make changes that affect API interactions, you can record new VCR cassettes.

If you have keys for all providers:

```bash
# Re-record all cassettes
bundle exec rake vcr:record[all]
```

If you only have keys for specific providers (e.g., just OpenAI):

```bash
# Set the API keys you have
export OPENAI_API_KEY=your_openai_key

# Find and remove only cassettes for OpenAI, then run tests to re-record them
bundle exec rake vcr:record[openai]

# You can also specify multiple providers
bundle exec rake vcr:record[openai,anthropic]
```

Important: After recording new cassettes, please **manually check** them for any sensitive information that might have been missed by the automatic filters.

## Adding New Tests

Tests automatically create VCR cassettes based on their descriptions, so make sure your test descriptions are unique and descriptive.

## Coding Style

We follow the [Standard Ruby](https://github.com/testdouble/standard) style. Please ensure your contributions adhere to this style.

```bash
# Check your code style
bundle exec rubocop

# Auto-fix style issues where possible
bundle exec rubocop -A
```

## Documentation

When adding new features, please include documentation updates:

- Update relevant guides in the `docs/guides/` directory
- Add inline documentation using YARD comments
- Keep the README clean and focused on helping new users get started quickly

## Discussions and Issues

- For questions and discussions, please use [GitHub Discussions](https://github.com/crmne/ruby_llm/discussions)
- For bugs and feature requests, please use [GitHub Issues](https://github.com/crmne/ruby_llm/issues)

## Release Process

Gem versioning follows [Semantic Versioning](https://semver.org/):

1. MAJOR version for incompatible API changes
2. MINOR version for backwards-compatible functionality
3. PATCH version for backwards-compatible bug fixes

Releases are handled by the maintainers through the CI/CD pipeline.

Thanks for helping make RubyLLM better!