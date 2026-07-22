# frozen_string_literal: true

require "spec_helper"

RSpec.describe MQ do
  describe ".run" do
    context "with basic markdown queries" do
      it "extracts h1 headings" do
        content = "# Hello World\n\n## Heading2\n\nText"
        result = MQ.run(".h1", content, nil)
        expect(result.values).to eq(["# Hello World"])
      end

      it "extracts h2 headings" do
        content = "# Hello World\n\n## Heading2\n\nText"
        result = MQ.run(".h2", content, nil)
        expect(result.values).to eq(["## Heading2"])
      end

      it "extracts multiple h2 headings" do
        content = "# Main Title\n\n## Heading2A\n\nText\n\n## Heading2B\n\nMore text"
        result = MQ.run(".h2", content, nil)
        expect(result.values).to eq(["## Heading2A", "## Heading2B"])
      end

      it "filters headings with select" do
        content = "# Product\n\n## Features\n\nText\n\n## Installation\n\nMore text"
        result = MQ.run('.h2 | select(contains("Feature"))', content, nil)
        expect(result.values).to eq(["## Features"])
      end

      it "extracts list items" do
        content = "# List\n\n- Item 1\n- Item 2\n- Item 3"
        result = MQ.run(".[]", content, nil)
        expect(result.values).to eq(["- Item 1", "- Item 2", "- Item 3"])
      end

      it "extracts code blocks" do
        content = "# Code\n\n```python\nprint('Hello')\n```"
        result = MQ.run(".code", content, nil)
        expect(result.values).to eq(["```python\nprint('Hello')\n```"])
      end
    end

    context "with different input formats" do
      it "processes TEXT format" do
        options = MQ::Options.new
        options.input_format = MQ::InputFormat::TEXT

        content = "Line 1\nLine 2\nLine 3"
        result = MQ.run('select(contains("2"))', content, options)
        expect(result.values).to eq(["Line 2"])
      end

      it "processes MDX format" do
        options = MQ::Options.new
        options.input_format = MQ::InputFormat::MDX

        content = "# MDX Content\n\n<Component />"
        result = MQ.run("select(is_mdx())", content, options)
        expect(result.values).to eq(["<Component />"])
      end

      it "processes HTML format" do
        options = MQ::Options.new
        options.input_format = MQ::InputFormat::HTML

        content = "<h1>Hello</h1><p>World</p>"
        result = MQ.run('select(contains("Hello"))', content, options)
        expect(result.values).to eq(["# Hello"])
      end
    end

    context "with invalid queries" do
      it "raises an error for invalid syntax" do
        expect {
          MQ.run(".invalid_selector!!!", "# Heading", nil)
        }.to raise_error(RuntimeError, /Error evaluating query/)
      end
    end
  end

  describe ".html_to_markdown" do
    it "converts HTML to Markdown" do
      html_content = "<h1>Hello World</h1><p>This is a <strong>test</strong>.</p>"
      expected_markdown = "# Hello World\n\nThis is a **test**."
      markdown = MQ.html_to_markdown(html_content, nil)
      expect(markdown.strip).to eq(expected_markdown)
    end

    it "converts HTML with options" do
      html_content = "<html><head><title>Page Title</title></head><body><h1>Content</h1></body></html>"

      options = MQ::ConversionOptions.new
      options.use_title_as_h1 = true

      markdown = MQ.html_to_markdown(html_content, options)
      expect(markdown).to include("# Page Title")
    end
  end

  describe MQ::Result do
    let(:content) { "# Title\n\n## Section 1\n\n## Section 2" }
    let(:result) { MQ.run(".h2", content, nil) }

    describe "#text" do
      it "returns text representation" do
        expect(result.text).to eq("## Section 1\n## Section 2")
      end
    end

    describe "#values" do
      it "returns array of values" do
        expect(result.values).to eq(["## Section 1", "## Section 2"])
      end
    end

    describe "#length" do
      it "returns the number of values" do
        expect(result.length).to eq(3)
      end
    end

    describe "#[]" do
      it "accesses values by index" do
        expect(result[1]).to eq("## Section 1")
        expect(result[2]).to eq("## Section 2")
      end

      it "raises error for out of range index" do
        expect { result[10] }.to raise_error
      end
    end

    describe "#each" do
      it "iterates over values" do
        values = []
        result.each { |v| values << v }
        expect(values).to eq(["", "## Section 1", "## Section 2"])
      end
    end
  end

  describe "InputFormat constants" do
    it "defines all input format constants" do
      expect(MQ::InputFormat::MARKDOWN).to eq(0)
      expect(MQ::InputFormat::MDX).to eq(1)
      expect(MQ::InputFormat::TEXT).to eq(2)
      expect(MQ::InputFormat::HTML).to eq(3)
      expect(MQ::InputFormat::RAW).to eq(4)
      expect(MQ::InputFormat::NULL).to eq(5)
    end
  end

  describe MQ::Options do
    it "can be instantiated with default values" do
      options = MQ::Options.new
      expect(options.input_format).to be_nil
    end

    it "allows setting input format" do
      options = MQ::Options.new
      options.input_format = MQ::InputFormat::TEXT
      expect(options.input_format).to eq(MQ::InputFormat::TEXT)
    end
  end

  describe MQ::ConversionOptions do
    it "can be instantiated with default values" do
      options = MQ::ConversionOptions.new
      expect(options.extract_scripts_as_code_blocks).to be false
      expect(options.generate_front_matter).to be false
      expect(options.use_title_as_h1).to be false
    end

    it "allows setting options" do
      options = MQ::ConversionOptions.new
      options.extract_scripts_as_code_blocks = true
      options.generate_front_matter = true
      options.use_title_as_h1 = true

      expect(options.extract_scripts_as_code_blocks).to be true
      expect(options.generate_front_matter).to be true
      expect(options.use_title_as_h1).to be true
    end
  end

  describe MQ::Query do
    describe "selector class methods" do
      it "builds h1 selector" do
        expect(MQ::Query.h1.to_query).to eq(".h1")
      end

      it "builds h2 selector" do
        expect(MQ::Query.h2.to_query).to eq(".h2")
      end

      it "builds h3-h6 selectors" do
        (3..6).each do |n|
          expect(MQ::Query.public_send("h#{n}").to_query).to eq(".h#{n}")
        end
      end

      it "builds code selector" do
        expect(MQ::Query.code.to_query).to eq(".code")
      end

      it "builds list selector" do
        expect(MQ::Query.list.to_query).to eq(".[]")
      end

      it "builds paragraph selector" do
        expect(MQ::Query.paragraph.to_query).to eq(".p")
      end

      it "builds blockquote selector" do
        expect(MQ::Query.blockquote.to_query).to eq(".blockquote")
      end

      it "builds heading selector" do
        expect(MQ::Query.heading.to_query).to eq(".heading")
      end

      it "builds text selector" do
        expect(MQ::Query.text.to_query).to eq(".text")
      end

      # New selectors
      it "builds strong selector"    do expect(MQ::Query.strong.to_query).to eq(".strong") end
      it "builds emphasis selector"  do expect(MQ::Query.emphasis.to_query).to eq(".emphasis") end
      it "builds delete selector"    do expect(MQ::Query.delete.to_query).to eq(".delete") end
      it "builds math selector"      do expect(MQ::Query.math.to_query).to eq(".math") end
      it "builds table selector"     do expect(MQ::Query.table.to_query).to eq(".table") end
      it "builds table_align selector" do expect(MQ::Query.table_align.to_query).to eq(".table_align") end
      it "builds html selector"      do expect(MQ::Query.html.to_query).to eq(".html") end
      it "builds definition selector" do expect(MQ::Query.definition.to_query).to eq(".definition") end
      it "builds footnote selector"  do expect(MQ::Query.footnote.to_query).to eq(".footnote") end
      it "builds toml selector"      do expect(MQ::Query.toml.to_query).to eq(".toml") end
      it "builds yaml selector"      do expect(MQ::Query.yaml.to_query).to eq(".yaml") end
      it "builds code_inline selector" do expect(MQ::Query.code_inline.to_query).to eq(".code_inline") end
      it "builds math_inline selector" do expect(MQ::Query.math_inline.to_query).to eq(".math_inline") end
      it "builds link_ref selector"  do expect(MQ::Query.link_ref.to_query).to eq(".link_ref") end
      it "builds image_ref selector" do expect(MQ::Query.image_ref.to_query).to eq(".image_ref") end
      it "builds footnote_ref selector" do expect(MQ::Query.footnote_ref.to_query).to eq(".footnote_ref") end
      it "builds line_break selector" do expect(MQ::Query.line_break.to_query).to eq(".break") end
      it "builds task selector"      do expect(MQ::Query.task.to_query).to eq(".task") end
      it "builds todo selector"      do expect(MQ::Query.todo.to_query).to eq(".todo") end
      it "builds done selector"      do expect(MQ::Query.done.to_query).to eq(".done") end
      it "builds recursive selector" do expect(MQ::Query.recursive.to_query).to eq("..") end

      it "builds mdx_jsx_flow_element selector" do
        expect(MQ::Query.mdx_jsx_flow_element.to_query).to eq(".mdx_jsx_flow_element")
      end
      it "builds mdx_text_expression selector" do
        expect(MQ::Query.mdx_text_expression.to_query).to eq(".mdx_text_expression")
      end
      it "builds mdx_jsx_text_element selector" do
        expect(MQ::Query.mdx_jsx_text_element.to_query).to eq(".mdx_jsx_text_element")
      end
      it "builds mdx_flow_expression selector" do
        expect(MQ::Query.mdx_flow_expression.to_query).to eq(".mdx_flow_expression")
      end
      it "builds mdx_js_esm selector" do
        expect(MQ::Query.mdx_js_esm.to_query).to eq(".mdx_js_esm")
      end
    end

    describe "indexed and parameterized selectors" do
      it "builds list_at(n) selector" do
        expect(MQ::Query.list_at(0).to_query).to eq(".[0]")
        expect(MQ::Query.list_at(2).to_query).to eq(".[2]")
      end

      it "builds table_row(n) selector" do
        expect(MQ::Query.table_row(0).to_query).to eq(".[0][]")
      end

      it "builds table_col(n) selector" do
        expect(MQ::Query.table_col(1).to_query).to eq(".[][1]")
      end

      it "builds table_cell(row, col) selector" do
        expect(MQ::Query.table_cell(1, 2).to_query).to eq(".[1][2]")
      end

      it "builds property selector" do
        expect(MQ::Query.property("title").to_query).to eq('."title"')
      end
    end

    describe "attribute selectors (class-level)" do
      it "builds value attribute selector"   do expect(MQ::Query.value.to_query).to eq(".value") end
      it "builds lang attribute selector"    do expect(MQ::Query.lang.to_query).to eq(".lang") end
      it "builds meta attribute selector"    do expect(MQ::Query.meta.to_query).to eq(".meta") end
      it "builds fence attribute selector"   do expect(MQ::Query.fence.to_query).to eq(".fence") end
      it "builds url attribute selector"     do expect(MQ::Query.url.to_query).to eq(".url") end
      it "builds alt attribute selector"     do expect(MQ::Query.alt.to_query).to eq(".alt") end
      it "builds depth attribute selector"   do expect(MQ::Query.depth.to_query).to eq(".depth") end
      it "builds level attribute selector"   do expect(MQ::Query.level.to_query).to eq(".level") end
      it "builds ordered attribute selector" do expect(MQ::Query.ordered.to_query).to eq(".ordered") end
      it "builds checked attribute selector" do expect(MQ::Query.checked.to_query).to eq(".checked") end
      it "builds column attribute selector"  do expect(MQ::Query.column.to_query).to eq(".column") end
      it "builds row attribute selector"     do expect(MQ::Query.row.to_query).to eq(".row") end
      it "builds align attribute selector"   do expect(MQ::Query.align.to_query).to eq(".align") end
    end

    describe "pipe operator |" do
      it "pipes two queries together" do
        query = MQ::Query.h2 | MQ::Query.to_text
        expect(query.to_query).to eq(".h2 | to_text()")
      end

      it "pipes multiple queries" do
        query = MQ::Query.h2 | MQ::Query.select { contains("Section") } | MQ::Query.to_text
        expect(query.to_query).to eq('.h2 | select(contains("Section")) | to_text()')
      end
    end

    describe "#select with block" do
      it "appends select with contains filter" do
        query = MQ::Query.h2.select { contains("Feature") }
        expect(query.to_query).to eq('.h2 | select(contains("Feature"))')
      end

      it "appends select with starts_with filter" do
        query = MQ::Query.h2.select { starts_with("##") }
        expect(query.to_query).to eq('.h2 | select(starts_with("##"))')
      end

      it "appends select with is_mdx filter" do
        query = MQ::Query.select { is_mdx }
        expect(query.to_query).to eq("select(is_mdx())")
      end

      it "combines filters with AND (&)" do
        query = MQ::Query.h2.select { contains("Feature") & starts_with("##") }
        expect(query.to_query).to eq('.h2 | select(contains("Feature") and starts_with("##"))')
      end

      it "combines filters with OR (|)" do
        query = MQ::Query.h2.select { contains("A") | contains("B") }
        expect(query.to_query).to eq('.h2 | select(contains("A") or contains("B"))')
      end

      it "negates a filter with negate()" do
        query = MQ::Query.select { negate(contains("draft")) }
        expect(query.to_query).to eq('select(not(contains("draft")))')
      end
    end

    describe "#select with string argument" do
      it "accepts a raw string filter" do
        query = MQ::Query.h2.select('contains("Feature")')
        expect(query.to_query).to eq('.h2 | select(contains("Feature"))')
      end
    end

    describe "#select with Filter argument" do
      it "accepts a Filter object" do
        filter = MQ::Filter.new('contains("Feature")')
        query = MQ::Query.h2.select(filter)
        expect(query.to_query).to eq('.h2 | select(contains("Feature"))')
      end
    end

    describe "output transformation methods" do
      it "chains to_text"            do expect(MQ::Query.h2.to_text.to_query).to eq(".h2 | to_text()") end
      it "chains to_markdown"        do expect(MQ::Query.h2.to_markdown.to_query).to eq(".h2 | to_markdown()") end
      it "chains to_mdx"             do expect(MQ::Query.text.to_mdx.to_query).to eq(".text | to_mdx()") end
      it "chains to_html"            do expect(MQ::Query.text.to_html.to_query).to eq(".text | to_html()") end
      it "chains to_string"          do expect(MQ::Query.text.to_string.to_query).to eq(".text | to_string()") end
      it "chains to_number"          do expect(MQ::Query.text.to_number.to_query).to eq(".text | to_number()") end
      it "chains to_boolean"         do expect(MQ::Query.text.to_boolean.to_query).to eq(".text | to_boolean()") end
      it "chains to_array"           do expect(MQ::Query.text.to_array.to_query).to eq(".text | to_array()") end
      it "chains to_markdown_string" do expect(MQ::Query.text.to_markdown_string.to_query).to eq(".text | to_markdown_string()") end
    end

    describe "string transformation methods" do
      it "chains trim"          do expect(MQ::Query.text.trim.to_query).to eq(".text | trim()") end
      it "chains ltrim"         do expect(MQ::Query.text.ltrim.to_query).to eq(".text | ltrim()") end
      it "chains rtrim"         do expect(MQ::Query.text.rtrim.to_query).to eq(".text | rtrim()") end
      it "chains downcase"      do expect(MQ::Query.text.downcase.to_query).to eq(".text | downcase()") end
      it "chains upcase"        do expect(MQ::Query.text.upcase.to_query).to eq(".text | upcase()") end
      it "chains ascii_downcase" do expect(MQ::Query.text.ascii_downcase.to_query).to eq(".text | ascii_downcase()") end
      it "chains ascii_upcase"  do expect(MQ::Query.text.ascii_upcase.to_query).to eq(".text | ascii_upcase()") end
      it "chains explode"       do expect(MQ::Query.text.explode.to_query).to eq(".text | explode()") end
      it "chains implode"       do expect(MQ::Query.text.implode.to_query).to eq(".text | implode()") end
      it "chains url_encode"    do expect(MQ::Query.text.url_encode.to_query).to eq(".text | url_encode()") end
      it "chains url_decode"    do expect(MQ::Query.text.url_decode.to_query).to eq(".text | url_decode()") end
      it "chains intern"        do expect(MQ::Query.text.intern.to_query).to eq(".text | intern()") end
      it "chains html_escape"   do expect(MQ::Query.text.html_escape.to_query).to eq(".text | html_escape()") end
      it "chains html_unescape" do expect(MQ::Query.text.html_unescape.to_query).to eq(".text | html_unescape()") end
      it "chains sanitize_html" do expect(MQ::Query.text.sanitize_html.to_query).to eq(".text | sanitize_html()") end
      it "chains strip_tags"    do expect(MQ::Query.text.strip_tags.to_query).to eq(".text | strip_tags()") end
      it "chains len"           do expect(MQ::Query.text.len.to_query).to eq(".text | len()") end
      it "chains utf8bytelen"   do expect(MQ::Query.text.utf8bytelen.to_query).to eq(".text | utf8bytelen()") end

      it "chains gsub with pattern and replacement" do
        expect(MQ::Query.text.gsub("foo", "bar").to_query).to eq('.text | gsub("foo", "bar")')
      end

      it "chains replace with from and to" do
        expect(MQ::Query.text.replace("old", "new").to_query).to eq('.text | replace("old", "new")')
      end

      it "chains test with regex pattern" do
        expect(MQ::Query.text.test("\\d+").to_query).to eq('.text | test("\\\\d+")')
      end

      it "chains capture with regex pattern" do
        expect(MQ::Query.text.capture("(\\w+)").to_query).to eq('.text | capture("(\\\\w+)")')
      end

      it "chains scan with regex pattern" do
        expect(MQ::Query.text.scan("(\\w+)").to_query).to eq('.text | scan("(\\\\w+)")')
      end

      it "chains split" do
        expect(MQ::Query.text.split(",").to_query).to eq('.text | split(",")')
      end

      it "chains repeat" do
        expect(MQ::Query.text.repeat(3).to_query).to eq(".text | repeat(3)")
      end

      it "chains slice" do
        expect(MQ::Query.text.slice(0, 5).to_query).to eq(".text | slice(0, 5)")
      end

      it "chains index" do
        expect(MQ::Query.text.index("foo").to_query).to eq('.text | index("foo")')
      end

      it "chains rindex" do
        expect(MQ::Query.text.rindex("foo").to_query).to eq('.text | rindex("foo")')
      end

      it "chains word_wrap" do
        expect(MQ::Query.text.word_wrap(20).to_query).to eq(".text | word_wrap(20)")
      end

      it "chains truncate" do
        expect(MQ::Query.text.truncate(10, "...").to_query).to eq('.text | truncate(10, "...")')
      end

      it "chains token_count without a model" do
        expect(MQ::Query.text.token_count.to_query).to eq(".text | token_count()")
      end

      it "chains token_count with a model" do
        expect(MQ::Query.text.token_count("gpt-4").to_query).to eq('.text | token_count("gpt-4")')
      end
    end

    describe "collection/array methods" do
      it "chains length"   do expect(MQ::Query.list.length.to_query).to eq(".[] | len()") end
      it "chains add"      do expect(MQ::Query.list.add("x").to_query).to eq('.[] | add("x")') end
      it "chains first"    do expect(MQ::Query.list.first.to_query).to eq(".[] | first") end
      it "chains last"     do expect(MQ::Query.list.last.to_query).to eq(".[] | last") end
      it "chains empty"    do expect(MQ::Query.list.empty.to_query).to eq(".[] | is_empty()") end
      it "chains reverse"  do expect(MQ::Query.list.reverse.to_query).to eq(".[] | reverse") end
      it "chains sort"     do expect(MQ::Query.list.sort.to_query).to eq(".[] | sort") end
      it "chains compact"  do expect(MQ::Query.list.compact.to_query).to eq(".[] | compact") end
      it "chains uniq"     do expect(MQ::Query.list.uniq.to_query).to eq(".[] | uniq") end
      it "chains flatten"  do expect(MQ::Query.list.flatten.to_query).to eq(".[] | flatten") end
      it "chains keys"     do expect(MQ::Query.list.keys.to_query).to eq(".[] | keys") end
      it "chains values"   do expect(MQ::Query.list.values.to_query).to eq(".[] | values") end
      it "chains entries"  do expect(MQ::Query.list.entries.to_query).to eq(".[] | entries") end
      it "chains children" do expect(MQ::Query.list.children.to_query).to eq(".[] | .children") end

      it "chains nth"   do expect(MQ::Query.h2.nth(2).to_query).to eq(".h2 | get(2)") end
      it "chains limit" do expect(MQ::Query.h2.limit(5).to_query).to eq(".h2 | take(5)") end
      it "chains range" do expect(MQ::Query.h2.range(3).to_query).to eq(".h2 | range(3)") end

      it "chains join" do
        expect(MQ::Query.list.join(", ").to_query).to eq('.[] | join(", ")')
      end

      it "chains del" do
        expect(MQ::Query.list.del("item").to_query).to eq('.[] | del("item")')
      end

      it "chains insert" do
        expect(MQ::Query.list.insert(0, "new").to_query).to eq('.[] | insert(0, "new")')
      end

      it "chains shuffle" do expect(MQ::Query.list.shuffle.to_query).to eq(".[] | shuffle()") end

      it "chains sample" do
        expect(MQ::Query.list.sample(3).to_query).to eq(".[] | sample(3)")
      end
    end

    describe "math methods" do
      it "chains abs"       do expect(MQ::Query.text.abs.to_query).to eq(".text | abs()") end
      it "chains ceil"      do expect(MQ::Query.text.ceil.to_query).to eq(".text | ceil()") end
      it "chains floor"     do expect(MQ::Query.text.floor.to_query).to eq(".text | floor()") end
      it "chains round"     do expect(MQ::Query.text.round.to_query).to eq(".text | round()") end
      it "chains trunc"     do expect(MQ::Query.text.trunc.to_query).to eq(".text | trunc()") end
      it "chains sqrt"      do expect(MQ::Query.text.sqrt.to_query).to eq(".text | sqrt()") end
      it "chains ln"        do expect(MQ::Query.text.ln.to_query).to eq(".text | ln()") end
      it "chains log10"     do expect(MQ::Query.text.log10.to_query).to eq(".text | log10()") end
      it "chains exp"       do expect(MQ::Query.text.exp.to_query).to eq(".text | exp()") end
      it "chains negate_val" do expect(MQ::Query.text.negate_val.to_query).to eq(".text | negate()") end
      it "chains is_nan"    do expect(MQ::Query.text.is_nan.to_query).to eq(".text | is_nan()") end

      it "chains pow" do
        expect(MQ::Query.text.pow(2).to_query).to eq(".text | pow(2)")
      end

      it "chains min" do
        expect(MQ::Query.text.min(0).to_query).to eq(".text | min(0)")
      end

      it "chains max" do
        expect(MQ::Query.text.max(100).to_query).to eq(".text | max(100)")
      end
    end

    describe "type / logic methods" do
      it "chains type"     do expect(MQ::Query.text.type.to_query).to eq(".text | type") end
      it "chains debug"    do expect(MQ::Query.text.debug.to_query).to eq(".text | debug") end

      it "chains coalesce with default value" do
        expect(MQ::Query.text.coalesce("default").to_query).to eq('.text | coalesce("default")')
      end
    end

    describe "encoding methods" do
      it "chains base64"    do expect(MQ::Query.text.base64.to_query).to eq(".text | base64()") end
      it "chains base64d"   do expect(MQ::Query.text.base64d.to_query).to eq(".text | base64d()") end
      it "chains base64url" do expect(MQ::Query.text.base64url.to_query).to eq(".text | base64url()") end
      it "chains base64urld" do expect(MQ::Query.text.base64urld.to_query).to eq(".text | base64urld()") end
      it "chains md5"       do expect(MQ::Query.text.md5.to_query).to eq(".text | md5()") end
      it "chains sha256"    do expect(MQ::Query.text.sha256.to_query).to eq(".text | sha256()") end
      it "chains sha512"    do expect(MQ::Query.text.sha512.to_query).to eq(".text | sha512()") end
      it "chains from_hex"  do expect(MQ::Query.text.from_hex.to_query).to eq(".text | from_hex()") end
      it "chains to_hex"    do expect(MQ::Query.text.to_hex.to_query).to eq(".text | to_hex()") end
      it "chains uuid"      do expect(MQ::Query.text.uuid.to_query).to eq(".text | uuid()") end
      it "chains uuid_v4"   do expect(MQ::Query.text.uuid_v4.to_query).to eq(".text | uuid_v4()") end
      it "chains uuid_v7"   do expect(MQ::Query.text.uuid_v7.to_query).to eq(".text | uuid_v7()") end
      it "chains rand"      do expect(MQ::Query.text.rand.to_query).to eq(".text | rand()") end

      it "chains rand_int" do
        expect(MQ::Query.text.rand_int(1, 10).to_query).to eq(".text | rand_int(1, 10)")
      end

      it "builds uuid as a class-level generator" do
        expect(MQ::Query.uuid.to_query).to eq("uuid()")
      end

      it "builds uuid_v4 as a class-level generator" do
        expect(MQ::Query.uuid_v4.to_query).to eq("uuid_v4()")
      end

      it "builds uuid_v7 as a class-level generator" do
        expect(MQ::Query.uuid_v7.to_query).to eq("uuid_v7()")
      end

      it "builds rand as a class-level generator" do
        expect(MQ::Query.rand.to_query).to eq("rand()")
      end

      it "builds rand_int as a class-level generator" do
        expect(MQ::Query.rand_int(1, 10).to_query).to eq("rand_int(1, 10)")
      end

      it "builds random_string as a class-level generator" do
        expect(MQ::Query.random_string(8, "abc").to_query).to eq('random_string(8, "abc")')
      end
    end

    describe "path methods" do
      it "chains basename"  do expect(MQ::Query.text.basename.to_query).to eq(".text | basename()") end
      it "chains dirname"   do expect(MQ::Query.text.dirname.to_query).to eq(".text | dirname()") end
      it "chains extname"   do expect(MQ::Query.text.extname.to_query).to eq(".text | extname()") end
      it "chains stem"      do expect(MQ::Query.text.stem.to_query).to eq(".text | stem()") end

      it "chains path_join" do
        expect(MQ::Query.text.path_join("file.md").to_query).to eq('.text | path_join("file.md")')
      end

      it "chains glob_match" do
        expect(MQ::Query.text.glob_match("docs/readme.md").to_query).to eq('.text | glob_match("docs/readme.md")')
      end
    end

    describe "css selector methods" do
      it "chains css" do
        expect(MQ::Query.text.css("p.intro").to_query).to eq('.text | css("p.intro")')
      end

      it "chains css_text" do
        expect(MQ::Query.text.css_text("p.intro").to_query).to eq('.text | css_text("p.intro")')
      end

      it "chains css_attr" do
        expect(MQ::Query.text.css_attr("a", "href").to_query).to eq('.text | css_attr("a", "href")')
      end
    end

    describe "dict methods" do
      it "chains get" do
        expect(MQ::Query.text.get("key").to_query).to eq('.text | get("key")')
      end

      it "chains set" do
        expect(MQ::Query.text.set("key", "val").to_query).to eq('.text | set("key", "val")')
      end

      it "chains property" do
        expect(MQ::Query.text.property("title").to_query).to eq('.text | ."title"')
      end

      it "chains get_path" do
        expect(MQ::Query.text.get_path(%w[a b]).to_query).to eq('.text | get_path(["a", "b"])')
      end

      it "chains set_path" do
        expect(MQ::Query.text.set_path(%w[a b], 1).to_query).to eq('.text | set_path(["a", "b"], 1)')
      end

      it "chains paths" do
        expect(MQ::Query.text.paths.to_query).to eq(".text | paths()")
      end
    end

    describe "attribute selector methods (instance)" do
      it "chains value"      do expect(MQ::Query.link.value.to_query).to eq(".link | .value") end
      it "chains lang"       do expect(MQ::Query.code.lang.to_query).to eq(".code | .lang") end
      it "chains meta"       do expect(MQ::Query.code.meta.to_query).to eq(".code | .meta") end
      it "chains fence"      do expect(MQ::Query.code.fence.to_query).to eq(".code | .fence") end
      it "chains url"        do expect(MQ::Query.link.url.to_query).to eq(".link | .url") end
      it "chains alt"        do expect(MQ::Query.image.alt.to_query).to eq(".image | .alt") end
      it "chains title"      do expect(MQ::Query.link.title.to_query).to eq(".link | .title") end
      it "chains ident"      do expect(MQ::Query.link_ref.ident.to_query).to eq(".link_ref | .ident") end
      it "chains label"      do expect(MQ::Query.link_ref.label.to_query).to eq(".link_ref | .label") end
      it "chains depth"      do expect(MQ::Query.heading.depth.to_query).to eq(".heading | .depth") end
      it "chains level"      do expect(MQ::Query.heading.level.to_query).to eq(".heading | .level") end
      it "chains item_index" do expect(MQ::Query.list.item_index.to_query).to eq(".[] | .index") end
      it "chains ordered"    do expect(MQ::Query.list.ordered.to_query).to eq(".[] | .ordered") end
      it "chains checked"    do expect(MQ::Query.task.checked.to_query).to eq(".task | .checked") end
      it "chains column"     do expect(MQ::Query.table.column.to_query).to eq(".table | .column") end
      it "chains row"        do expect(MQ::Query.table.row.to_query).to eq(".table | .row") end
      it "chains align"      do expect(MQ::Query.table_align.align.to_query).to eq(".table_align | .align") end
      it "chains mdx_name"   do expect(MQ::Query.mdx_jsx_flow_element.mdx_name.to_query).to eq(".mdx_jsx_flow_element | .name") end
    end

    describe "markdown attribute mutation methods" do
      it "chains update" do
        expect(MQ::Query.h2.update("New Title").to_query).to eq('.h2 | update("New Title")')
      end

      it "chains attr" do
        expect(MQ::Query.code.attr("lang").to_query).to eq('.code | attr("lang")')
      end

      it "chains set_attr" do
        expect(MQ::Query.code.set_attr("lang", "ruby").to_query).to eq('.code | set_attr("lang", "ruby")')
      end

      it "chains get_title" do
        expect(MQ::Query.link.get_title.to_query).to eq(".link | get_title")
      end

      it "chains get_url" do
        expect(MQ::Query.link.get_url.to_query).to eq(".link | get_url")
      end

      it "chains set_check" do
        expect(MQ::Query.task.set_check(true).to_query).to eq(".task | set_check(true)")
      end

      it "chains set_ref" do
        expect(MQ::Query.link_ref.set_ref("myref").to_query).to eq('.link_ref | set_ref("myref")')
      end

      it "chains set_code_block_lang" do
        expect(MQ::Query.code.set_code_block_lang("ruby").to_query).to eq('.code | set_code_block_lang("ruby")')
      end

      it "chains set_list_ordered" do
        expect(MQ::Query.list.set_list_ordered(true).to_query).to eq(".[] | set_list_ordered(true)")
      end
    end

    describe "markdown construction methods" do
      it "chains to_code with language" do
        expect(MQ::Query.text.to_code("ruby").to_query).to eq('.text | to_code("ruby")')
      end

      it "chains to_code without language" do
        expect(MQ::Query.text.to_code.to_query).to eq(".text | to_code(null)")
      end

      it "chains to_code_inline" do
        expect(MQ::Query.text.to_code_inline.to_query).to eq(".text | to_code_inline()")
      end

      it "chains to_h with depth" do
        expect(MQ::Query.text.to_h(2).to_query).to eq(".text | to_h(2)")
      end

      it "chains to_hr" do
        expect(MQ::Query.text.to_hr.to_query).to eq(".text | to_hr()")
      end

      it "chains to_link with url, text, and title" do
        expect(MQ::Query.text.to_link("https://example.com", "Example", "title").to_query).to eq(
          '.text | to_link("https://example.com", "Example", "title")'
        )
      end

      it "chains to_link with url and empty title" do
        expect(MQ::Query.text.to_link("https://example.com", "Example").to_query).to eq(
          '.text | to_link("https://example.com", "Example", "")'
        )
      end

      it "chains to_link with url only (current value as text)" do
        expect(MQ::Query.text.to_link("https://example.com").to_query).to eq(
          '.text | to_link("https://example.com", "")'
        )
      end

      it "chains to_image with url, alt, and title" do
        expect(MQ::Query.text.to_image("img.png", "alt text", "title").to_query).to eq(
          '.text | to_image("img.png", "alt text", "title")'
        )
      end

      it "chains to_image with url and alt" do
        expect(MQ::Query.text.to_image("img.png", "alt text").to_query).to eq(
          '.text | to_image("img.png", "alt text", "")'
        )
      end

      it "chains to_math"        do expect(MQ::Query.text.to_math.to_query).to eq(".text | to_math()") end
      it "chains to_math_inline" do expect(MQ::Query.text.to_math_inline.to_query).to eq(".text | to_math_inline()") end
      it "chains to_strong"      do expect(MQ::Query.text.to_strong.to_query).to eq(".text | to_strong()") end
      it "chains to_em"          do expect(MQ::Query.text.to_em.to_query).to eq(".text | to_em()") end
      it "chains to_md_text"     do expect(MQ::Query.text.to_md_text.to_query).to eq(".text | to_md_text()") end

      it "chains to_md_list with level" do
        expect(MQ::Query.text.to_md_list(0).to_query).to eq(".text | to_md_list(0)")
      end

      it "chains to_md_name" do
        expect(MQ::Query.text.to_md_name("component").to_query).to eq('.text | to_md_name("component")')
      end

      it "chains to_md_table_row with cells" do
        expect(MQ::Query.text.to_md_table_row("A", "B", "C").to_query).to eq('.text | to_md_table_row("A", "B", "C")')
      end

      it "chains to_md_table_cell" do
        expect(MQ::Query.text.to_md_table_cell("content", 0, 1).to_query).to eq('.text | to_md_table_cell("content", 0, 1)')
      end
    end

    describe "chaining multiple operations" do
      it "chains selector, select, and to_text" do
        query = MQ::Query.h2
          .select { contains("Section") }
          .to_text
        expect(query.to_query).to eq('.h2 | select(contains("Section")) | to_text()')
      end

      it "chains code selector with lang attribute" do
        expect(MQ::Query.code.lang.to_query).to eq(".code | .lang")
      end

      it "chains link selector with url attribute" do
        expect(MQ::Query.link.url.to_query).to eq(".link | .url")
      end

      it "builds complex query with multiple steps" do
        query = MQ::Query.h2
          .select { contains("API") & negate(contains("Internal")) }
          .to_text
          .downcase
        expect(query.to_query).to eq('.h2 | select(contains("API") and not(contains("Internal"))) | to_text() | downcase()')
      end
    end

    describe "integration with MQ.run" do
      let(:content) { "# Main\n\n## Features\n\n## Installation\n\n## Contributing" }

      it "accepts a Query object in MQ.run" do
        result = MQ.run(MQ::Query.h2, content)
        expect(result.values).to eq(["## Features", "## Installation", "## Contributing"])
      end

      it "filters with select via Query object" do
        result = MQ.run(MQ::Query.h2.select { contains("Feature") }, content)
        expect(result.values).to eq(["## Features"])
      end

      it "still accepts plain strings in MQ.run" do
        result = MQ.run(".h2", content)
        expect(result.values).to eq(["## Features", "## Installation", "## Contributing"])
      end

      it "extracts code block language via attribute selector" do
        md = "# Code\n\n```ruby\nputs 'hello'\n```"
        result = MQ.run(MQ::Query.code.lang, md)
        expect(result.values).to eq(["ruby"])
      end

      it "extracts link URLs via attribute selector" do
        md = "# Links\n\n[Google](https://google.com)\n\n[GitHub](https://github.com)"
        result = MQ.run(MQ::Query.link.url, md)
        expect(result.values).to eq(["https://google.com", "https://github.com"])
      end

      it "applies downcase transformation" do
        md = "# Hello World"
        result = MQ.run(MQ::Query.h1.to_text.downcase, md)
        # to_text() strips heading marks, returning plain text
        expect(result.values).to eq(["hello world"])
      end

      it "filters with comparison operator" do
        md = "# Section A\n\n## Section B\n\n### Topic C"
        result = MQ.run(MQ::Query.h2.select { contains("Section B") }, md)
        expect(result.values).to eq(["## Section B"])
      end

      it "filters with ends_with" do
        md = "# Section A\n\n## Section B\n\n### Topic C"
        result = MQ.run(MQ::Query.heading.select { ends_with("B") }, md)
        expect(result.values).to eq(["## Section B"])
      end

      it "filters with is_none check" do
        md = "# Title\n\n```ruby\ncode\n```"
        result = MQ.run(MQ::Query.code.lang.select { negate(is_none) }, md)
        expect(result.values).to eq(["ruby"])
      end
    end
  end

  describe MQ::Filter do
    it "builds a filter from a string" do
      filter = MQ::Filter.new('contains("foo")')
      expect(filter.to_filter).to eq('contains("foo")')
    end

    it "combines filters with AND" do
      a = MQ::Filter.new('contains("foo")')
      b = MQ::Filter.new('starts_with("bar")')
      expect((a & b).to_filter).to eq('contains("foo") and starts_with("bar")')
    end

    it "combines filters with OR" do
      a = MQ::Filter.new('contains("foo")')
      b = MQ::Filter.new('contains("bar")')
      expect((a | b).to_filter).to eq('contains("foo") or contains("bar")')
    end
  end

  describe MQ::FilterDSL do
    subject(:dsl) { MQ::FilterDSL.new }

    describe "string matching" do
      it "contains"    do expect(dsl.contains("foo").to_filter).to eq('contains("foo")') end
      it "starts_with" do expect(dsl.starts_with("foo").to_filter).to eq('starts_with("foo")') end
      it "ends_with"   do expect(dsl.ends_with("foo").to_filter).to eq('ends_with("foo")') end
      it "test"        do expect(dsl.test("\\d+").to_filter).to eq('test("\\\\d+")') end
    end

    describe "regex matching" do
      it "is_regex_match" do
        expect(dsl.is_regex_match("\\d+").to_filter).to eq('is_regex_match("\\\\d+")')
      end
      it "is_not_regex_match" do
        expect(dsl.is_not_regex_match("\\d+").to_filter).to eq('is_not_regex_match("\\\\d+")')
      end
    end

    describe "comparison operators" do
      it "eq"  do expect(dsl.eq("foo").to_filter).to eq('eq("foo")') end
      it "ne"  do expect(dsl.ne("foo").to_filter).to eq('ne("foo")') end
      it "gt"  do expect(dsl.gt(5).to_filter).to eq("gt(5)") end
      it "gte" do expect(dsl.gte(5).to_filter).to eq("gte(5)") end
      it "lt"  do expect(dsl.lt(5).to_filter).to eq("lt(5)") end
      it "lte" do expect(dsl.lte(5).to_filter).to eq("lte(5)") end
    end

    describe "type checks" do
      it "is_mdx"  do expect(dsl.is_mdx.to_filter).to eq("is_mdx()") end
      it "is_none" do expect(dsl.is_none.to_filter).to eq("is_none()") end
      it "is_nan"  do expect(dsl.is_nan.to_filter).to eq("is_nan()") end
      it "type"    do expect(dsl.type.to_filter).to eq("type") end
    end

    describe "negation" do
      it "negate wraps filter with not()" do
        f = dsl.contains("draft")
        expect(dsl.negate(f).to_filter).to eq('not(contains("draft"))')
      end
    end

    describe "complex filter combinations" do
      it "combines comparison and string filters" do
        query = MQ::Query.h2.select { ne("## Draft") & contains("Feature") }
        expect(query.to_query).to eq('.h2 | select(ne("## Draft") and contains("Feature"))')
      end

      it "triple-combines with AND" do
        query = MQ::Query.h2.select {
          contains("API") & negate(contains("Internal")) & starts_with("## ")
        }
        expect(query.to_query).to eq(
          '.h2 | select(contains("API") and not(contains("Internal")) and starts_with("## "))'
        )
      end
    end
  end
end
