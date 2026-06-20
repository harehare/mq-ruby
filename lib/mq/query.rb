# frozen_string_literal: true

module MQ
  # Programmatic query builder for constructing mq queries in Ruby.
  #
  # @example Basic selector
  #   MQ::Query.h2
  #   # => ".h2"
  #
  # @example Selector with filter
  #   MQ::Query.h2.select { contains("Feature") }
  #   # => '.h2 | select(contains("Feature"))'
  #
  # @example Pipe operator
  #   MQ::Query.h2 | MQ::Query.to_text
  #   # => ".h2 | to_text()"
  #
  # @example Attribute access
  #   MQ::Query.link.url
  #   # => ".link | .url"
  #
  # @example Complex chain
  #   MQ::Query.h2
  #     .select { contains("Section") & starts_with("##") }
  #     .to_text
  #   # => '.h2 | select(contains("Section") and starts_with("##")) | to_text()'
  #
  # @example Using with MQ.run
  #   result = MQ.run(MQ::Query.h2.select { contains("Feature") }, content)
  class Query
    def initialize(expr = "")
      @expr = expr.to_s
    end

    # Pipe two queries together using the | operator.
    #
    # @param other [Query, #to_query] the query to pipe into
    # @return [Query]
    def |(other)
      self.class.new("#{@expr} | #{other.to_query}")
    end

    # Append a select() filter.
    #
    # @param filter [Filter, String, nil] filter expression (or use block)
    # @yield block evaluated in {FilterDSL} context
    # @return [Query]
    def select(filter = nil, &block)
      filter_str = resolve_filter(filter, &block)
      pipe_with("select(#{filter_str})")
    end

    # Append a map() transformation.
    #
    # @param filter [Filter, String, nil] filter expression (or use block)
    # @yield block evaluated in {FilterDSL} context
    # @return [Query]
    def map(filter = nil, &block)
      filter_str = resolve_filter(filter, &block)
      pipe_with("map(#{filter_str})")
    end

    def to_text        = pipe_with("to_text()")
    def to_markdown    = pipe_with("to_markdown()")
    def to_mdx         = pipe_with("to_mdx()")
    def to_html        = pipe_with("to_html()")
    def to_string      = pipe_with("to_string()")
    def to_number      = pipe_with("to_number()")
    def to_array       = pipe_with("to_array()")
    def to_bytes       = pipe_with("to_bytes()")
    def to_markdown_string = pipe_with("to_markdown_string()")

    def length         = pipe_with("len()")
    def len            = pipe_with("len()")
    def utf8bytelen    = pipe_with("utf8bytelen()")

    def add(other)
      pipe_with("add(#{other.inspect})")
    end

    def first          = pipe_with("first")
    def last           = pipe_with("last")
    def empty          = pipe_with("is_empty()")
    def reverse        = pipe_with("reverse")
    def sort           = pipe_with("sort")
    def compact        = pipe_with("compact")
    def uniq           = pipe_with("uniq")
    def flatten        = pipe_with("flatten")
    def keys           = pipe_with("keys")
    def values         = pipe_with("values")
    def entries        = pipe_with("entries")
    def children       = pipe_with(".children")

    def split(separator)
      pipe_with("split(#{separator.inspect})")
    end

    def join(separator)
      pipe_with("join(#{separator.inspect})")
    end

    def nth(n)
      pipe_with("get(#{n})")
    end

    def limit(n)
      pipe_with("take(#{n})")
    end

    def range(n)
      pipe_with("range(#{n})")
    end

    def slice(start, stop)
      pipe_with("slice(#{start}, #{stop})")
    end

    def index(value)
      pipe_with("index(#{value.inspect})")
    end

    def rindex(value)
      pipe_with("rindex(#{value.inspect})")
    end

    def del(value)
      pipe_with("del(#{value.inspect})")
    end

    def insert(idx, val)
      pipe_with("insert(#{idx}, #{val.inspect})")
    end

    def repeat(n)
      pipe_with("repeat(#{n})")
    end

    def trim           = pipe_with("trim()")
    def ltrim          = pipe_with("ltrim()")
    def rtrim          = pipe_with("rtrim()")
    def downcase       = pipe_with("downcase()")
    def upcase         = pipe_with("upcase()")
    def explode        = pipe_with("explode()")
    def implode        = pipe_with("implode()")
    def url_encode     = pipe_with("url_encode()")
    def intern         = pipe_with("intern()")

    def gsub(pattern, replacement)
      pipe_with("gsub(#{pattern.inspect}, #{replacement.inspect})")
    end

    def replace(from, to)
      pipe_with("replace(#{from.inspect}, #{to.inspect})")
    end

    def test(pattern)
      pipe_with("test(#{pattern.inspect})")
    end

    def capture(pattern)
      pipe_with("capture(#{pattern.inspect})")
    end

    def abs            = pipe_with("abs()")
    def ceil           = pipe_with("ceil()")
    def floor          = pipe_with("floor()")
    def round          = pipe_with("round()")
    def trunc          = pipe_with("trunc()")
    def sqrt           = pipe_with("sqrt()")
    def ln             = pipe_with("ln()")
    def log10          = pipe_with("log10()")
    def exp            = pipe_with("exp()")
    def negate_val     = pipe_with("negate()")
    def is_nan         = pipe_with("is_nan()")

    def pow(n)
      pipe_with("pow(#{n})")
    end

    def min(other)
      pipe_with("min(#{other})")
    end

    def max(other)
      pipe_with("max(#{other})")
    end

    # --- Type / logic ---

    def type           = pipe_with("type")
    def debug          = pipe_with("debug")

    def coalesce(default)
      pipe_with("coalesce(#{default.inspect})")
    end

    def base64         = pipe_with("base64()")
    def base64d        = pipe_with("base64d()")
    def base64url      = pipe_with("base64url()")
    def base64urld     = pipe_with("base64urld()")
    def md5            = pipe_with("md5()")
    def sha256         = pipe_with("sha256()")
    def sha512         = pipe_with("sha512()")
    def from_hex       = pipe_with("from_hex()")
    def to_hex         = pipe_with("to_hex()")
    def to_hex_str     = pipe_with("to_hex()")

    def basename       = pipe_with("basename()")
    def dirname        = pipe_with("dirname()")
    def extname        = pipe_with("extname()")
    def stem           = pipe_with("stem()")

    def path_join(other)
      pipe_with("path_join(#{other.inspect})")
    end

    def get(key)
      pipe_with("get(#{key.inspect})")
    end

    def set(key, val)
      pipe_with("set(#{key.inspect}, #{val.inspect})")
    end

    # Access a dict property by key (generates ."key" selector)
    def property(key)
      pipe_with(".\"#{key}\"")
    end

    # Attribute selectors (access attributes of selected nodes)
    # These generate attribute selector syntax (.url, .lang, etc.)

    def value          = pipe_with(".value")
    def lang           = pipe_with(".lang")
    def meta           = pipe_with(".meta")
    def fence          = pipe_with(".fence")
    def url            = pipe_with(".url")
    def alt            = pipe_with(".alt")
    def title          = pipe_with(".title")
    def ident          = pipe_with(".ident")
    def label          = pipe_with(".label")
    def depth          = pipe_with(".depth")
    def level          = pipe_with(".level")
    def item_index     = pipe_with(".index")
    def ordered        = pipe_with(".ordered")
    def checked        = pipe_with(".checked")
    def column         = pipe_with(".column")
    def row            = pipe_with(".row")
    def align          = pipe_with(".align")
    def mdx_name       = pipe_with(".name")

    def update(content)
      pipe_with("update(#{content.inspect})")
    end

    def attr(name)
      pipe_with("attr(#{name.inspect})")
    end

    def set_attr(name, val)
      pipe_with("set_attr(#{name.inspect}, #{val.inspect})")
    end

    def get_title      = pipe_with("get_title")
    def get_url        = pipe_with("get_url")

    def set_check(val)
      pipe_with("set_check(#{val})")
    end

    def set_ref(ref)
      pipe_with("set_ref(#{ref.inspect})")
    end

    def set_code_block_lang(lang)
      pipe_with("set_code_block_lang(#{lang.inspect})")
    end

    def set_list_ordered(val)
      pipe_with("set_list_ordered(#{val})")
    end

    # Convert current value to a code block with the given language.
    def to_code(lang = nil)
      lang ? pipe_with("to_code(#{lang.inspect})") : pipe_with("to_code(null)")
    end

    def to_code_inline = pipe_with("to_code_inline()")

    # Convert current value to a heading of the given depth (1-6).
    def to_h(depth)
      pipe_with("to_h(#{depth})")
    end

    def to_hr          = pipe_with("to_hr()")

    # Create a link node. With all three args no auto-prepend occurs.
    # With two args the current value becomes the link text.
    def to_link(url, text = nil, link_title = "")
      if text
        pipe_with("to_link(#{url.inspect}, #{text.inspect}, #{link_title.inspect})")
      else
        pipe_with("to_link(#{url.inspect}, #{link_title.inspect})")
      end
    end

    # Create an image node. With all three args no auto-prepend occurs.
    # With two args the current value becomes the alt text.
    def to_image(url, img_alt = nil, img_title = "")
      if img_alt
        pipe_with("to_image(#{url.inspect}, #{img_alt.inspect}, #{img_title.inspect})")
      else
        pipe_with("to_image(#{url.inspect}, #{img_title.inspect})")
      end
    end

    def to_math        = pipe_with("to_math()")
    def to_math_inline = pipe_with("to_math_inline()")
    def to_strong      = pipe_with("to_strong()")
    def to_em          = pipe_with("to_em()")
    def to_md_text     = pipe_with("to_md_text()")

    # Convert current value to a list item at the given nesting level.
    def to_md_list(list_level)
      pipe_with("to_md_list(#{list_level})")
    end

    # Convert current value to a markdown element with the given node name.
    def to_md_name(node_name)
      pipe_with("to_md_name(#{node_name.inspect})")
    end

    # Build a table row from the given cell values.
    def to_md_table_row(*cells)
      pipe_with("to_md_table_row(#{cells.map(&:inspect).join(', ')})")
    end

    # Build a table cell with content, row index, and column index.
    def to_md_table_cell(content, r, c)
      pipe_with("to_md_table_cell(#{content.inspect}, #{r}, #{c})")
    end

    # Returns the mq query string.
    # @return [String]
    def to_query = @expr
    alias to_s to_query

    class << self
      # --- Heading selectors: h1 through h6 ---
      (1..6).each { |n| define_method("h#{n}") { new(".h#{n}") } }

      # Generic heading (any level)
      def heading    = new(".heading")

      # Block element selectors
      def code       = new(".code")
      def paragraph  = new(".p")
      def blockquote = new(".blockquote")
      def hr         = new(".hr")
      def image      = new(".image")
      def link       = new(".link")
      def text       = new(".text")
      def strong     = new(".strong")
      def emphasis   = new(".emphasis")
      def delete     = new(".delete")
      def math       = new(".math")
      def table      = new(".table")
      def table_align = new(".table_align")
      def html       = new(".html")
      def definition = new(".definition")
      def footnote   = new(".footnote")
      def toml       = new(".toml")
      def yaml       = new(".yaml")

      # Inline element selectors
      def code_inline  = new(".code_inline")
      def math_inline  = new(".math_inline")
      def link_ref     = new(".link_ref")
      def image_ref    = new(".image_ref")
      def footnote_ref = new(".footnote_ref")
      def line_break   = new(".break")

      # Task list selectors
      def task       = new(".task")
      def todo       = new(".todo")
      def done       = new(".done")

      # --- List selector ---
      def list       = new(".[]")

      # List item at a specific index: .[n]
      def list_at(n)
        new(".[#{n}]")
      end

      # --- Table selectors with row/column indexing ---

      # All cells in a specific row: .[n][]
      def table_row(n)
        new(".[#{n}][]")
      end

      # All cells in a specific column: .[][n]
      def table_col(n)
        new(".[][#{n}]")
      end

      # A specific cell: .[row][col]
      def table_cell(r, c)
        new(".[#{r}][#{c}]")
      end

      # --- MDX selectors ---
      def mdx_jsx_flow_element  = new(".mdx_jsx_flow_element")
      def mdx_text_expression   = new(".mdx_text_expression")
      def mdx_jsx_text_element  = new(".mdx_jsx_text_element")
      def mdx_flow_expression   = new(".mdx_flow_expression")
      def mdx_js_esm            = new(".mdx_js_esm")

      # Recursive / deep selector (..)
      def recursive  = new("..")

      # --- Attribute selectors (as standalone starting points) ---
      def value      = new(".value")
      def node_values = new(".values")
      def lang       = new(".lang")
      def meta       = new(".meta")
      def fence      = new(".fence")
      def url        = new(".url")
      def alt        = new(".alt")
      def depth      = new(".depth")
      def level      = new(".level")
      def ordered    = new(".ordered")
      def checked    = new(".checked")
      def column     = new(".column")
      def row        = new(".row")
      def align      = new(".align")

      # Dict property selector: ."key"
      def property(key)
        new(".\"#{key}\"")
      end

      # Class-level select (no leading selector)
      #
      # @param filter [Filter, String, nil]
      # @yield block evaluated in {FilterDSL} context
      # @return [Query]
      def select(filter = nil, &block)
        filter_str = new.send(:resolve_filter, filter, &block)
        new("select(#{filter_str})")
      end

      def to_text     = new("to_text()")
      def to_markdown = new("to_markdown()")
    end

    private

    def pipe_with(expr)
      @expr.empty? ? self.class.new(expr) : self.class.new("#{@expr} | #{expr}")
    end

    def resolve_filter(filter, &block)
      if block_given?
        Filter.build(&block)
      elsif filter.respond_to?(:to_query)
        filter.to_query
      else
        filter.to_s
      end
    end
  end

  # Represents a boolean filter expression for use inside select() and map().
  #
  # Filters can be combined with & (and) and | (or):
  #   contains("foo") & starts_with("bar")
  #   # => 'contains("foo") and starts_with("bar")'
  class Filter
    def initialize(expr)
      @expr = expr.to_s
    end

    # Build a filter expression by evaluating a block in {FilterDSL} context.
    # @yield block in FilterDSL context
    # @return [String]
    def self.build(&block)
      result = FilterDSL.new.instance_eval(&block)
      result.respond_to?(:to_filter) ? result.to_filter : result.to_s
    end

    # Combine two filters with boolean AND.
    def &(other) = self.class.new("#{@expr} and #{other}")

    # Combine two filters with boolean OR.
    def |(other) = self.class.new("#{@expr} or #{other}")

    def to_filter = @expr
    alias to_query to_filter
    alias to_s to_filter
  end

  # DSL context for building filter expressions inside select/map blocks.
  #
  # All methods return a {Filter} that can be combined with & and |.
  #
  # @example String matching
  #   MQ::Query.h2.select { contains("Feature") & starts_with("##") }
  #
  # @example Comparison
  #   MQ::Query.list.select { gt(5) }
  #
  # @example Negation
  #   MQ::Query.select { negate(contains("draft")) }
  class FilterDSL
    # String matching
    def contains(text)    = Filter.new("contains(#{text.inspect})")
    def starts_with(text) = Filter.new("starts_with(#{text.inspect})")
    def ends_with(text)   = Filter.new("ends_with(#{text.inspect})")
    def test(pattern)     = Filter.new("test(#{pattern.inspect})")

    # Regex matching
    def is_regex_match(pattern)     = Filter.new("is_regex_match(#{pattern.inspect})")
    def is_not_regex_match(pattern) = Filter.new("is_not_regex_match(#{pattern.inspect})")

    # Comparison operators
    # These compare the current pipeline value against the given argument.
    def eq(value)  = Filter.new("eq(#{value.inspect})")
    def ne(value)  = Filter.new("ne(#{value.inspect})")
    def gt(value)  = Filter.new("gt(#{value.inspect})")
    def gte(value) = Filter.new("gte(#{value.inspect})")
    def lt(value)  = Filter.new("lt(#{value.inspect})")
    def lte(value) = Filter.new("lte(#{value.inspect})")

    # Type checks
    def is_mdx  = Filter.new("is_mdx()")
    def is_none = Filter.new("is_none()")
    def is_nan  = Filter.new("is_nan()")
    def type    = Filter.new("type")

    # String transforms usable in filter context
    def length         = Filter.new("len()")
    def trim           = Filter.new("trim()")
    def empty          = Filter.new("is_empty()")

    def add(other) = Filter.new("add(#{other.inspect})")

    # Negate a filter expression with not().
    # Use +negate+ instead of +not+ since +not+ is a Ruby keyword.
    #
    # @example
    #   MQ::Query.select { negate(contains("draft")) }
    #   # => 'select(not(contains("draft")))'
    def negate(filter) = Filter.new("not(#{filter})")
  end
end
