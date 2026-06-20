<h1 align="center">mq-ruby</h1>

[![Gem Version](https://badge.fury.io/rb/mq-ruby.svg)](https://badge.fury.io/rb/mq-ruby)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ruby bindings for [mq](https://mqlang.org/), a jq-like command-line tool for processing Markdown.

## Installation

Add to your Gemfile:

```ruby
gem 'mq-ruby'
```

## Basic Usage

```ruby
require 'mq'

markdown = <<~MD
  # Main Title

  ## Section 1

  Some content here.

  ## Section 2

  More content.
MD

# Run a raw mq query string
result = MQ.run('.h2', markdown)
result.values.each { |h| puts h }
# => ## Section 1
# => ## Section 2

# Access result as a single string
puts result.text
# => ## Section 1
# => ## Section 2

# Count matched nodes
puts result.length  # => 2

# Index into results (1-based)
puts result[1]  # => ## Section 1
```

## Query Builder

`MQ::Query` provides a Ruby DSL for building mq query strings programmatically.
Queries are built by chaining methods and can be passed directly to `MQ.run`.

```ruby
# Equivalent to MQ.run('.h2', markdown)
result = MQ.run(MQ::Query.h2, markdown)

# Chain with filters and transformations
query = MQ::Query.h2
  .select { contains("Installation") }
  .to_text

result = MQ.run(query, markdown)
```

### Selectors

#### Heading Selectors

```ruby
MQ::Query.h1        # .h1  — level-1 headings
MQ::Query.h2        # .h2  — level-2 headings
MQ::Query.h3        # .h3
MQ::Query.h4        # .h4
MQ::Query.h5        # .h5
MQ::Query.h6        # .h6
MQ::Query.heading   # .heading — any heading
```

#### Block Element Selectors

```ruby
MQ::Query.paragraph   # .p
MQ::Query.code        # .code       — fenced code blocks
MQ::Query.blockquote  # .blockquote
MQ::Query.hr          # .hr         — horizontal rules
MQ::Query.list        # .[]         — list items
MQ::Query.table       # .table
MQ::Query.table_align # .table_align
MQ::Query.math        # .math       — math blocks
MQ::Query.html        # .html       — raw HTML blocks
MQ::Query.definition  # .definition — link definitions
MQ::Query.footnote    # .footnote
MQ::Query.toml        # .toml       — TOML front matter
MQ::Query.yaml        # .yaml       — YAML front matter
```

#### Inline Element Selectors

```ruby
MQ::Query.text          # .text
MQ::Query.strong        # .strong    — bold
MQ::Query.emphasis      # .emphasis  — italic
MQ::Query.delete        # .delete    — strikethrough
MQ::Query.link          # .link
MQ::Query.image         # .image
MQ::Query.code_inline   # .code_inline
MQ::Query.math_inline   # .math_inline
MQ::Query.link_ref      # .link_ref
MQ::Query.image_ref     # .image_ref
MQ::Query.footnote_ref  # .footnote_ref
MQ::Query.line_break    # .break
```

#### Task List Selectors

```ruby
MQ::Query.task  # .task — any task list item
MQ::Query.todo  # .todo — unchecked task items
MQ::Query.done  # .done — checked task items
```

#### Indexed Selectors

```ruby
MQ::Query.list_at(0)         # .[0]     — first list item
MQ::Query.list_at(2)         # .[2]     — third list item
MQ::Query.table_row(0)       # .[0][]   — all cells in row 0
MQ::Query.table_col(1)       # .[][1]   — all cells in column 1
MQ::Query.table_cell(0, 1)   # .[0][1]  — cell at row 0, column 1
```

#### MDX Selectors

```ruby
MQ::Query.mdx_jsx_flow_element  # .mdx_jsx_flow_element
MQ::Query.mdx_text_expression   # .mdx_text_expression
MQ::Query.mdx_jsx_text_element  # .mdx_jsx_text_element
MQ::Query.mdx_flow_expression   # .mdx_flow_expression
MQ::Query.mdx_js_esm            # .mdx_js_esm
```

#### Attribute Selectors

Access specific attributes of nodes directly:

```ruby
MQ::Query.code.lang    # .code | .lang  — language of code blocks
MQ::Query.link.url     # .link | .url   — URL of links
MQ::Query.image.alt    # .image | .alt  — alt text of images
MQ::Query.link.title   # .link | .title — title of links

# All available attribute selectors (class-level)
MQ::Query.value    # .value
MQ::Query.lang     # .lang
MQ::Query.meta     # .meta
MQ::Query.fence    # .fence
MQ::Query.url      # .url
MQ::Query.alt      # .alt
MQ::Query.depth    # .depth   — heading depth
MQ::Query.level    # .level
MQ::Query.ordered  # .ordered — list ordered flag
MQ::Query.checked  # .checked — task item checked state
MQ::Query.column   # .column  — table cell column index
MQ::Query.row      # .row     — table cell row index
MQ::Query.align    # .align   — table alignment
```

#### Instance-level Attribute Access (for chaining)

```ruby
# After selecting a node, chain attribute selectors:
MQ::Query.code.lang        # .code | .lang
MQ::Query.link.url         # .link | .url
MQ::Query.heading.depth    # .heading | .depth
MQ::Query.task.checked     # .task | .checked
MQ::Query.list.item_index  # .[] | .index  (item_index avoids naming conflict)
MQ::Query.list.ordered     # .[] | .ordered
MQ::Query.table.column     # .table | .column
MQ::Query.table.row        # .table | .row
MQ::Query.table_align.align           # .table_align | .align
MQ::Query.mdx_jsx_flow_element.mdx_name  # .mdx_jsx_flow_element | .name
```

#### Recursive Selector

```ruby
MQ::Query.recursive  # .. — matches all nodes recursively
```

#### Dict Property Selector

```ruby
MQ::Query.property("title")  # ."title"
query.property("key")        # | ."key"
```

### Pipe Operator

Chain two queries with `|`:

```ruby
query = MQ::Query.h2 | MQ::Query.to_text
# => ".h2 | to_text()"

query = MQ::Query.h2 | MQ::Query.select { contains("API") } | MQ::Query.to_text
# => '.h2 | select(contains("API")) | to_text()'
```

### Filtering with `select`

```ruby
# Block form (recommended)
MQ::Query.h2.select { contains("Feature") }
# => '.h2 | select(contains("Feature"))'

# Combine conditions with & (and) and | (or)
MQ::Query.h2.select { contains("API") & starts_with("## ") }
# => '.h2 | select(contains("API") and starts_with("## "))'

MQ::Query.h2.select { contains("A") | contains("B") }
# => '.h2 | select(contains("A") or contains("B"))'

# Negation
MQ::Query.select { negate(contains("draft")) }
# => 'select(not(contains("draft")))'

# Class-level select (no leading selector)
MQ::Query.select { is_mdx }
# => "select(is_mdx())"

# String or Filter argument
MQ::Query.h2.select('contains("Feature")')
MQ::Query.h2.select(MQ::Filter.new('contains("Feature")'))
```

### Mapping with `map`

```ruby
MQ::Query.list.map { contains("important") }
# => '.[] | map(contains("important"))'
```

### Transformation Methods

#### Output

```ruby
.to_text           # to_text()          — plain text
.to_markdown       # to_markdown()      — markdown string
.to_mdx            # to_mdx()           — MDX string
.to_html           # to_html()          — HTML string
.to_string         # to_string()        — string coercion
.to_number         # to_number()        — numeric coercion
.to_array          # to_array()
.to_bytes          # to_bytes()
.to_markdown_string # to_markdown_string()
```

#### String Operations

```ruby
.trim              # trim()
.ltrim             # ltrim()
.rtrim             # rtrim()
.downcase          # downcase()
.upcase            # upcase()
.len               # len()
.utf8bytelen       # utf8bytelen()
.explode           # explode()          — string to codepoints
.implode           # implode()          — codepoints to string
.url_encode        # url_encode()
.intern            # intern()

.split(",")        # split(",")
.gsub("pat", "r")  # gsub("pat", "r")  — regex replace all
.replace("a", "b") # replace("a", "b") — literal replace
.test("\\d+")      # test("\\d+")      — regex test → bool
.capture("(\\w+)") # capture("(\\w+)") — regex capture
.slice(0, 5)       # slice(0, 5)
.index("sub")      # index("sub")      — position of substring
.rindex("sub")     # rindex("sub")     — last position
.repeat(3)         # repeat(3)
```

#### Collection Operations

```ruby
.length            # len()
.len               # len()
.add("x")          # add("x")
.first             # first
.last              # last
.empty             # is_empty()
.reverse           # reverse
.sort              # sort
.compact           # compact           — remove nils
.uniq              # uniq
.flatten           # flatten
.keys              # keys
.values            # values
.entries           # entries
.children          # .children
.join(", ")        # join(", ")
.nth(2)            # get(2)
.limit(5)          # take(5)
.range(3)          # range(3)
.del("key")        # del("key")
.insert(0, "val")  # insert(0, "val")
```

#### Math Operations

```ruby
.abs               # abs()
.ceil              # ceil()
.floor             # floor()
.round             # round()
.trunc             # trunc()
.sqrt              # sqrt()
.ln                # ln()
.log10             # log10()
.exp               # exp()
.pow(2)            # pow(2)
.min(0)            # min(0)
.max(100)          # max(100)
.negate_val        # negate()          — numeric negation
.is_nan            # is_nan()
```

#### Type / Logic

```ruby
.type              # type
.coalesce("default") # coalesce("default")
.debug             # debug
```

#### Encoding

```ruby
.base64            # base64()
.base64d           # base64d()
.base64url         # base64url()
.base64urld        # base64urld()
.md5               # md5()
.sha256            # sha256()
.sha512            # sha512()
.from_hex          # from_hex()
.to_hex            # to_hex()
```

#### Path Operations

```ruby
.basename          # basename()
.dirname           # dirname()
.extname           # extname()
.stem              # stem()
.path_join("sub")  # path_join("sub")
```

#### Dict Operations

```ruby
.get("key")            # get("key")
.set("key", "val")     # set("key", "val")
.property("key")       # ."key"
```

#### Markdown Attribute Operations

```ruby
.update("New content")          # update("New content")
.attr("lang")                   # attr("lang")
.set_attr("lang", "ruby")       # set_attr("lang", "ruby")
.get_title                      # get_title
.get_url                        # get_url
.set_check(true)                # set_check(true)
.set_ref("myref")               # set_ref("myref")
.set_code_block_lang("python")  # set_code_block_lang("python")
.set_list_ordered(true)         # set_list_ordered(true)
```

#### Markdown Construction

```ruby
.to_code("ruby")               # to_code("ruby")
.to_code                       # to_code(null)   — no language
.to_code_inline                # to_code_inline()
.to_h(2)                       # to_h(2)          — convert to heading level 2
.to_hr                         # to_hr()
.to_link("url", "text", "title")  # to_link(...)
.to_link("url", "text")           # to_link(...)   — empty title
.to_link("url")                   # to_link(...)   — current value as text
.to_image("url", "alt", "title")  # to_image(...)
.to_math                       # to_math()
.to_math_inline                # to_math_inline()
.to_strong                     # to_strong()
.to_em                         # to_em()
.to_md_text                    # to_md_text()
.to_md_list(0)                 # to_md_list(0)    — nesting level
.to_md_name("component")       # to_md_name("component")
.to_md_table_row("A", "B", "C")   # to_md_table_row(...)
.to_md_table_cell("val", 0, 1)    # to_md_table_cell(...)
```

### Filter DSL

All filter methods return a `MQ::Filter` that can be combined with `&` (and) and `|` (or).

#### String Matching

```ruby
contains("text")       # contains("text")
starts_with("## ")     # starts_with("## ")
ends_with(".")         # ends_with(".")
test("\\d+")           # test("\\d+")        — regex test
```

#### Regex

```ruby
is_regex_match("\\d+")      # is_regex_match("\\d+")
is_not_regex_match("\\d+")  # is_not_regex_match("\\d+")
```

#### Comparison Operators

These compare the current pipeline value against the argument:

```ruby
eq("value")   # eq("value")    — equal
ne("value")   # ne("value")    — not equal
gt(5)         # gt(5)          — greater than
gte(5)        # gte(5)         — greater than or equal
lt(5)         # lt(5)          — less than
lte(5)        # lte(5)         — less than or equal
```

#### Type Checks

```ruby
is_mdx   # is_mdx()
is_none  # is_none()
is_nan   # is_nan()
type     # type
```

#### Other

```ruby
negate(contains("draft"))  # not(contains("draft"))
length                     # length
empty                      # empty
add                        # add
```

### Combining Filters

```ruby
MQ::Query.h2.select { contains("API") & negate(contains("Internal")) }
# => '.h2 | select(contains("API") and not(contains("Internal")))'

MQ::Query.h2.select { starts_with("## ") | ends_with("!") }
# => '.h2 | select(starts_with("## ") or ends_with("!"))'

# Three-way AND
MQ::Query.h2.select {
  contains("API") & negate(contains("Internal")) & starts_with("## ")
}
```

## Options

```ruby
options = MQ::Options.new
options.input_format = MQ::InputFormat::MARKDOWN  # default
options.input_format = MQ::InputFormat::MDX
options.input_format = MQ::InputFormat::TEXT
options.input_format = MQ::InputFormat::HTML
options.input_format = MQ::InputFormat::RAW
options.input_format = MQ::InputFormat::NULL

result = MQ.run('.h1', content, options)
```

## HTML to Markdown

```ruby
html = '<h1>Title</h1><p>This is a <strong>test</strong>.</p>'
markdown = MQ.html_to_markdown(html)
# => "# Title\n\nThis is a **test**."

# With conversion options
options = MQ::ConversionOptions.new
options.use_title_as_h1 = true
options.extract_scripts_as_code_blocks = true
options.generate_front_matter = true

markdown = MQ.html_to_markdown(html, options)
```

## Examples

```ruby
require 'mq'

content = File.read('README.md')

# Extract all h2 headings containing "API"
MQ.run(MQ::Query.h2.select { contains("API") }, content).values

# Get all code block languages used
MQ.run(MQ::Query.code.lang, content).values

# Get all link URLs
MQ.run(MQ::Query.link.url, content).values

# Extract headings as plain text (no # prefix)
MQ.run(MQ::Query.h2.to_text, content).values

# Find unchecked task items
MQ.run(MQ::Query.todo, content).values

# Get the first list item
MQ.run(MQ::Query.list_at(0), content).values

# Count h2 headings
MQ.run(MQ::Query.h2.length, content).values

# Extract YAML front matter
MQ.run(MQ::Query.yaml, content).values
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Links

- [mq Website](https://mqlang.org/)
- [GitHub Repository](https://github.com/harehare/mq)
- [Command-line Tool](https://github.com/harehare/mq#installation)
