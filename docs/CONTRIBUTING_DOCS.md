# Contributing to Documentation

Thank you for your interest in improving the AlgoKit Subscriber documentation!

## Documentation Structure

The documentation is organized as follows:

```
docs/
├── README.md              # Documentation index and navigation
├── GETTING_STARTED.md     # Beginner-friendly introduction (633 lines)
├── QUICK_REFERENCE.md     # Quick cheat sheet (421 lines)
├── API_REFERENCE.md       # Complete API documentation (913 lines)
├── ADVANCED_USAGE.md      # Advanced patterns & production (1188 lines)
├── ARCHITECTURE.md        # Internal architecture details (806 lines)
└── CONTRIBUTING_DOCS.md   # This file
```

**Total:** ~4,240 lines of documentation

## Documentation Principles

Our documentation follows these core principles:

1. **Progressive Disclosure** - Start simple, add complexity gradually
2. **Task-Oriented** - Focus on what users want to accomplish
3. **Complete Examples** - All code examples are runnable
4. **Cross-Referencing** - Link related concepts across documents
5. **Search-Friendly** - Use clear headings and keywords

## When to Update Documentation

Update documentation when:

- Adding new features or APIs
- Changing existing behavior
- Fixing bugs that affect documented behavior
- Improving clarity or fixing errors
- Adding new examples or use cases

## Types of Documentation Updates

### 1. Getting Started Guide

**Purpose:** Help new users get up and running quickly

**Update when:**
- Installation process changes
- Basic concepts change
- Common patterns emerge

**Style:**
- Conversational and friendly
- Step-by-step instructions
- Minimal jargon
- Lots of examples

### 2. Quick Reference

**Purpose:** Provide quick answers for experienced users

**Update when:**
- New common patterns emerge
- Configuration options change
- API shortcuts are added

**Style:**
- Concise code snippets
- Minimal explanation
- Organized by task
- Easy to scan

### 3. API Reference

**Purpose:** Document all public APIs comprehensively

**Update when:**
- New classes or methods added
- Method signatures change
- New configuration options added
- Return values change

**Style:**
- Complete and precise
- Include all parameters and types
- Document return values and exceptions
- Provide examples for each API

### 4. Advanced Usage Guide

**Purpose:** Help users optimize and deploy to production

**Update when:**
- New advanced features added
- Performance characteristics change
- New deployment patterns emerge
- Best practices evolve

**Style:**
- In-depth explanations
- Real-world scenarios
- Production-focused
- Performance considerations

### 5. Architecture Document

**Purpose:** Help contributors understand internals

**Update when:**
- Core algorithms change
- Threading model changes
- Major refactoring occurs
- Design decisions are made

**Style:**
- Technical and detailed
- Include diagrams (ASCII art)
- Explain rationale
- Document trade-offs

## Making Documentation Changes

### 1. Local Setup

```bash
# Clone the repository
git clone https://github.com/loedn/algokit-subscriber-rb.git
cd algokit-subscriber-rb

# Install dependencies
bundle install

# Edit documentation
vim docs/GETTING_STARTED.md
```

### 2. Writing Style

**Do:**
- Use active voice ("Create a subscriber" not "A subscriber can be created")
- Use present tense ("Returns a hash" not "Will return a hash")
- Be concise but complete
- Include working code examples
- Cross-reference related topics
- Use consistent terminology

**Don't:**
- Use jargon without explanation
- Make assumptions about user knowledge
- Use "we" or "I" (use "you")
- Include incomplete code examples
- Break existing links

### 3. Code Examples

All code examples should:

```ruby
# 1. Be complete and runnable
require 'algokit/subscriber'

algod = Algokit::Subscriber::Client::AlgodClient.new('https://testnet-api.algonode.cloud')
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [{ name: 'payments', filter: { type: 'pay' } }]
)
subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod)

# 2. Include comments for clarity
subscriber.on('payments') do |txn|
  # Handle payment transaction
  puts "Payment: #{txn['id']}"
end

# 3. Be realistic (not contrived)
subscriber.start
```

### 4. Cross-References

Link to related documentation:

```markdown
See [API Reference - SubscriptionConfig](API_REFERENCE.md#subscriptionconfig) for details.
```

Always use relative links within docs:
- ✓ `[Getting Started](GETTING_STARTED.md)`
- ✓ `[examples](../examples/)`
- ✗ Absolute GitHub URLs (they break in local viewing)

### 5. Testing Documentation

Before submitting:

1. **Verify all code examples run:**
   ```bash
   ruby -c examples/simple_payment_tracker.rb
   ```

2. **Check all links work:**
   ```bash
   # Test locally with a markdown viewer
   grip docs/README.md
   ```

3. **Verify formatting:**
   - Tables align properly
   - Code blocks have language tags
   - Headings use proper hierarchy

4. **Check for typos:**
   - Run a spell checker
   - Read through carefully

## Pull Request Process

### 1. Create a Branch

```bash
git checkout -b docs/improve-getting-started
```

### 2. Make Changes

Edit the relevant markdown files in `docs/`.

### 3. Commit Changes

```bash
git add docs/
git commit -m "docs: improve getting started guide clarity"
```

**Commit message format:**
- Prefix: `docs:` for documentation changes
- Be descriptive: "improve X" or "add Y example"
- Use lowercase

### 4. Push and Create PR

```bash
git push origin docs/improve-getting-started
```

Then create a pull request on GitHub with:

**Title:** Clear description of the change
```
docs: Add example for balance change tracking
```

**Description:**
```markdown
## What
Added a comprehensive example for tracking balance changes in the Advanced Usage guide.

## Why
Users were asking how to track multiple assets for a single address.

## Changes
- Added new section in ADVANCED_USAGE.md
- Added cross-reference from GETTING_STARTED.md
- Updated QUICK_REFERENCE.md with code snippet
```

## Documentation Standards

### Markdown Formatting

**Headings:**
```markdown
# H1 - Document Title (only one per file)
## H2 - Major Section
### H3 - Subsection
#### H4 - Sub-subsection (avoid deeper nesting)
```

**Code Blocks:**
```markdown
​```ruby
# Always specify language
code here
​```
```

**Tables:**
```markdown
| Header 1 | Header 2 |
|----------|----------|
| Value 1  | Value 2  |
```

**Lists:**
```markdown
- Unordered list
  - Nested item (2 spaces)
  
1. Ordered list
2. Second item
```

**Emphasis:**
```markdown
**Bold** for important terms
*Italic* for emphasis
`code` for inline code
```

### Section Organization

Each major section should have:

1. **Introduction** - What this section covers
2. **Prerequisites** - What you need to know first
3. **Content** - The actual information
4. **Examples** - Working code examples
5. **Next Steps** - Where to go from here

## Common Documentation Tasks

### Adding a New Feature

When adding a new feature, update:

1. **API_REFERENCE.md** - Document the new API
2. **ADVANCED_USAGE.md** - Add usage patterns (if advanced)
3. **GETTING_STARTED.md** - Add to common patterns (if basic)
4. **QUICK_REFERENCE.md** - Add quick snippet
5. **CHANGELOG.md** - Add to changelog (not in docs/)
6. **README.md** - Update if it's a major feature

### Fixing Documentation Errors

1. Identify the error
2. Fix it in all relevant files
3. Check for related errors
4. Verify links still work

### Improving Clarity

1. Identify confusing sections (from issues/feedback)
2. Add examples or explanations
3. Reorganize if needed
4. Add cross-references

### Adding Examples

1. Create working example in `examples/` directory
2. Document in `examples/README.md`
3. Reference from main docs
4. Add to QUICK_REFERENCE.md if applicable

## Review Criteria

Documentation PRs will be reviewed for:

- **Accuracy** - Is the information correct?
- **Clarity** - Is it easy to understand?
- **Completeness** - Are all aspects covered?
- **Consistency** - Does it match existing docs?
- **Examples** - Are code examples working?
- **Links** - Do all links work?
- **Grammar** - Is it well-written?

## Getting Help

If you're unsure about documentation changes:

1. **Open an issue first** - Discuss the proposed change
2. **Ask in PR** - Reviewers will provide guidance
3. **Check existing docs** - See how similar topics are handled
4. **Look at recent PRs** - See what others have done

## Documentation Tools

### Recommended Tools

- **Markdown Editor:** VS Code, Typora, or any text editor
- **Spell Checker:** Built-in or plugin
- **Markdown Preview:** `grip` or editor preview
- **Link Checker:** Manual or use markdown link check tools

### Useful Commands

```bash
# Preview markdown locally
gem install grip
grip docs/README.md

# Count lines
wc -l docs/*.md

# Find broken links (manual check)
grep -r "](.*)" docs/

# Find TODO items
grep -r "TODO" docs/
```

## Style Guide

### Terminology

Use consistent terminology:

- **subscriber** (not "subscription" or "monitor")
- **transaction** (not "txn" in prose, but ok in code)
- **filter** (not "matcher" or "selector")
- **watermark** (not "checkpoint" or "cursor")
- **algod/indexer** (lowercase, not "Algod/Indexer")

### Code Examples

```ruby
# Good: Complete and realistic
subscriber.on('payments') do |txn|
  amount = txn.dig('payment-transaction', 'amount')
  puts "Received #{amount / 1_000_000.0} ALGO"
end

# Bad: Incomplete
subscriber.on('payments') do |txn|
  # ...
end
```

### Voice and Tone

- **Friendly but professional**
- **Clear and direct**
- **Helpful and supportive**
- **Technical but accessible**

## Questions?

If you have questions about contributing to documentation:

1. Open an issue with the `documentation` label
2. Ask in your pull request
3. Reach out to maintainers

Thank you for helping improve AlgoKit Subscriber documentation! 🙏
