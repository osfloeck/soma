/*
	main.odin
	The driver for soma, a static site generator
*/

#+vet explicit-allocators
#+vet unused-variables
#+feature dynamic-literals

package soma

import "core:fmt"
import "core:os"
import "core:strings"
import "core:path/filepath"
import "core:c"
import "base:runtime"
import "core:strconv"
import "core:slice"

foreign import md4c_html "system:md4c-html"

foreign md4c_html {
    md_html :: proc(
        input:          cstring,
        size:           c.uint,
        process_output: proc "c" (output: cstring, size: c.uint, userdata: rawptr),
        userdata:       rawptr,
        parser_flags:   c.uint,
        renderer_flags: c.uint,
    ) -> c.int ---
}

// TODO(oskar): check actual md4c.h for more options
MARKDOWN_PARSER_FLAGS :: c.uint(0x0040 | 0x0004)

RESERVED_FRONTMATTER_KEYS :: []string{"content", "category", "items", "page_ref"}

Page :: struct {
	file_path: string, 				// home/user/my-site/index.md		
	category: string,  				// projects, ""
	is_index: bool,	   				// true, false
	frontmatter: map[string]Value,	// title: "test", rank: 1, tags: [code, stuff]
	content: string,				// HTML parsed of raw content
	items: []Page					// category & index pages only
}

Template :: struct {
	name: string,		// base.html, default.html, content.html
	file_path: string,	// home/user/my-site/templates/base.html
	raw: string,		// unprocessed content
	content: []Token	// lexed content
}

Parsed_Template :: struct {
	name: string,		// default.html
	extends: string,	// base.html
	nodes: []Node,		// parsed AST of template
}

Token_Kind :: enum {
	Text,		// raw literal " <main>\n "
	Tag,		// {{ title }}
	Block		// {% block content %} {% endblock %} {% extends "base.html" %}
}

Token :: struct {
	type: Token_Kind,
	content: string
}

Node_Kind :: enum {
	Text,		// <h1>Heading</h1>
	Tag,		// {{ title }}
	For,		// {{ for item in items }}
	If,			// {{ if dev_mode }}
	Block,		// {% block content %}
	Include,	// {% include "nav.html" %}
}

Node :: struct {
	kind: Node_Kind,	// Tag
	value: string,		// title
	pipes: []string,	// {"upper", "truncate"}
	children: []Node	
}

built_ins := map[string]Built_In_Function {
	"format_date" = format_date,
	"uppercase" = uppercase,
	"brief" = brief
}

PRINT_USAGE :: "soma — a static site generator without the noise\n" +
			   "usage:\n" +
			   "  soma init <name>     scaffold a new site\n" +
			   "  soma build           renders site into build directory\n" +
			   "  soma serve [port]    serve (--dev for live reload)\n" +
			   "  soma clean           clears build directory\n"

/*
	Program entrypoint. Handles the CLI interface
*/
main :: proc() {
	arguments := os.args
	arg_len := len(arguments)
	if arg_len < 2 {
		fmt.print(PRINT_USAGE)
		return
	}
	command := arguments[1]

	defer free_all(context.allocator)
	working_dir, _ := os.getwd(context.allocator)
	if command != "init" { _valid_dir(command) }

	switch command {
	case "init":
		if len(arguments) < 3 {
			fmt.println("soma (error): `init` needs a site name")
			return
		}
		init(arguments[2])

	case "build":
		build(working_dir, false)

	case "serve":
		port := 8000
		dev := false
		for arg, i in arguments {
			if arg == "--dev" {
				dev = true
			}
			if arg == "--port" {
				parsed_port, ok := strconv.parse_int(arguments[i+1], 10)
				if (!ok) {
					fmt.println("soma (err): Error parsing port!")
					return
				}
				port = parsed_port
			}
		}
		serve(port, dev)

	case "clean":
		clean(working_dir)

	case:
		fmt.print(PRINT_USAGE)
	}
}

/* 
	Initialise site with default content. Creates default directories,
	then populates with some categories and default styling
*/
init :: proc(name: string) {
	if os.exists(name) {
		fmt.printfln("soma (error): directory `%s` already exists", name)
		// TODO(oskar): || os.is_reserved_name(name)
		return
	}
	init_alloc := context.allocator

	// Scaffod directories
	directories := []string {
		name,
		strings.concatenate({name, "/templates"}, init_alloc),
		strings.concatenate({name, "/build"}, init_alloc),
		strings.concatenate({name, "/assets"}, init_alloc),
		strings.concatenate({name, "/assets", "/css"}, init_alloc),
		strings.concatenate({name, "/assets", "/fonts"}, init_alloc),
		strings.concatenate({name, "/blog"}, init_alloc),
		strings.concatenate({name, "/projects"}, init_alloc),
	}
	for directory in directories {
		os.make_directory(directory)
	}

	// Create default templates
	templates := default_templates()
	templates_dir, _ := filepath.join({name, "templates"}, init_alloc)
	for file_name, contents in templates {
		path, _ := filepath.join({templates_dir, file_name}, init_alloc)
		_write_text_file(path, contents)
	}

	// Create default content
	content := default_content()
	for relative_path, contents in content {
		path, _ := filepath.join({name, relative_path}, init_alloc)
		_write_text_file(path, contents)
	}

	// Copy default assets
	asset_path, _ := filepath.join({name, "assets", "css"}, init_alloc)
	ASSET_FILES := #load_directory("css")
	for a in ASSET_FILES {
		path, _ := filepath.join({asset_path, a.name}, init_alloc)
		err := os.write_entire_file_from_bytes(path, a.data)
		if (err != nil) {
			fmt.println("soma (error): Error writing asset!")
		}
	}

	// Copy default fonts
	font_path, _ := filepath.join({name, "assets", "fonts"}, init_alloc)
	FONT_FILES := #load_directory("fonts")
	for f in FONT_FILES { 
		path, _ := filepath.join({font_path, f.name}, init_alloc)
		err := os.write_entire_file_from_bytes(path, f.data) 
		if (err != nil) {
			fmt.println("soma (error): Error writing font file!")
		}
	}

	// Default soma.toml
	soma_toml, _ := filepath.join({name, "soma.toml"}, context.allocator)
	_write_text_file(soma_toml, "build_dir = \"build\"")

	fmt.printfln("soma: new instance `%s` created", name)
	fmt.println("soma: run `soma build` then `soma serve` to get started")
}

_write_text_file :: proc(path: string, contents: string) {
	parent := filepath.dir(path)
	os.make_directory(parent)
	err := os.write_entire_file(path, transmute([]u8)contents)
	if (err != nil) {
		fmt.printfln("soma (error): could not write file %s", path)
	}
}

/*
	Clears /build, builds html from parsed markdown files,
	does other stuff too
*/
build :: proc(working_dir: string, dev_mode: bool = false) {
	build_alloc := context.allocator

	build_dir, _ := filepath.join({working_dir, "/build"}, build_alloc)
	os.remove_all(build_dir)
	os.mkdir(build_dir)

	// Process templates
	templates := _discover_templates(working_dir)
	_template_lexer(&templates)								// Pure flat lex
	parsed_templates := _parse_templates(templates) 		// AST
	final_templates := _resolve_templates(parsed_templates)	// Render context templates

	// Process site content
	pages := _discover_content(working_dir, build_alloc)
    _discover_items(&pages, build_alloc)

	// Render html and write to build
	final_pages := _render_site(pages, final_templates)
	_build_site(final_pages, build_dir, working_dir)

	fmt.printfln("soma (info): build successful")
    fmt.printfln("	templates : %d", len(final_templates))
    fmt.printfln("	categories: %d", _n_unique_categories(final_pages))
    fmt.printfln("	pages     : %d", len(final_pages))
}

/*
	This function discovers content within the site and also validates
	to ensure it is relevant i.e. not draft, valid frontmatter. It also
	populates the registry with page content and frontmatter
*/
_discover_content :: proc(working_dir: string, allocator: runtime.Allocator) -> [dynamic]Page {
	discovered := make([dynamic]Page, allocator)

	w := os.walker_create_path(working_dir)
	defer os.walker_destroy(&w)
	
	for file in os.walker_walk(&w) {
		if (file.type != .Regular) || (filepath.ext(file.name) != ".md") {
			// Skip dirs & non-md files
			continue
		}
		if (strings.has_prefix(file.fullpath, strings.concatenate({working_dir, "/build"}, allocator))) {
			// Skip /build
			os.walker_skip_dir(&w)
			continue
		}
		if (strings.has_prefix(file.name, "_")) {
			// Skip drafts i.e. _post.md
			fmt.printfln("soma (info): Skipping draft %v", file.name)
			continue
		}

		parent_dir := filepath.dir(file.fullpath)
		is_in_root := parent_dir == working_dir
		category := "" if is_in_root else filepath.base(parent_dir)

		// Frontmatter & body splitting
		raw, _ := os.read_entire_file_from_path(file.fullpath, allocator)
		content := string(raw)

		// TODO(oskar): Maybe we strings.scrub here?
		split_content := strings.split_n(content, "---", 3, allocator)
		if len(split_content) != 3 {
			relative_path, _ := filepath.rel(working_dir, file.fullpath, allocator)
			fmt.printfln("soma (err): invalid frontmatter in `%s`", relative_path)
			continue
		}

		// Clean frontmatter and content
		final_frontmatter := strings.trim_space(split_content[1])
		final_content := strings.trim_space(split_content[2])

		// Return object
		page := Page {
			file_path = strings.clone(file.fullpath, allocator),
			category  = strings.clone(category, allocator),
			is_index  = strings.clone(file.name, allocator) == "index.md",
			frontmatter = _extract_frontmatter(final_frontmatter, allocator),
			content   = _markdown_to_html(final_content, allocator)
		}
		append(&discovered, page)

		// Register Page
		registry.items[{page.file_path, ""}] = 
		Item {
			page = page,
			type = .Page
		}

		// Register Page `content`
		registry.items[{page.file_path, "content"}] =
		Item {
			name = "content",
			value = page.content,
			type = .Value
		}

		// Register Page `category`
		registry.items[{page.file_path, "category"}] =
		Item {
			name = "category",
			value = page.category,
			type = .Value
		}

		// Register Page `page_ref`
		registry.items[{page.file_path, "page_ref"}] =
		Item {
			name = "page_ref",
			value = _page_url(page),
			type = .Value
		}

		// Register Page `frontmatter`
		for name, val in page.frontmatter {
			registry.items[{page.file_path, name}] =
			Item {
				name = name,
				value = val,
				type = .Value
			}
		}
	}

	return discovered
}

/*
	Appends the appropriate items to pages that need it.
	These incude only pages that are both an index.md AND
	belong to a category i.e. `blog/index.md`
*/
_discover_items :: proc(pages: ^[dynamic]Page, allocator: runtime.Allocator) {
	for &page in pages {
		found := make([dynamic]Page, allocator)
		if page.is_index && page.category != "" {
			// This page needs items
			for candidate in pages {
				cat_match := candidate.category == page.category
				not_self := candidate.file_path != page.file_path
				if (cat_match && not_self) {
					append(&found, candidate)
				}
			}
		}

		// TODO(oskar): default sorting needs reworking
		slice.sort_by(found[:], proc(i, j: Page) -> bool {
			date_a, has_date_a := i.frontmatter["date"].(Date)
			date_b, has_date_b := j.frontmatter["date"].(Date)

			if has_date_a && has_date_b {
				if date_a != date_b {
					return _date_after(date_a, date_b)
				}
			} else if has_date_a {
				return true
			} else if has_date_b {
				return false
			}

			title_a, _ := i.frontmatter["title"].(string)
			title_b, _ := j.frontmatter["title"].(string)

			return title_a < title_b
		})

		page.items = found[:]

		// Register items array (pages)
		registry.items[{page.file_path, "items"}] = 
		Item {
			name = "items",
			page = page,
			items = page.items,
			type = .Array
		}
	}
}

/*
	Accepts frontmatter such as:
		title: "Home"\n 
		template: "default"\n
		tags: [odin, test]\n
	and parses each individual entity with _parse_value
*/
_extract_frontmatter :: proc(frontmatter: string, allocator: runtime.Allocator) -> map[string]Value {
	parsed := make(map[string]Value, allocator)
	raw := strings.split_lines(frontmatter, allocator)

	for line in raw {
		if strings.trim_space(line) == "" {
			continue
		}

		// (key) tags (value) [c, c++]
		key, _, value := strings.partition(line, ":")
		key = strings.trim_space(key)
		value = strings.trim_space(value) 

		if slice.contains(RESERVED_FRONTMATTER_KEYS, key) {
			fmt.printfln("soma (err): `%s` is a reserved frontmatter key!", key)
			continue
		}
		parsed[key] = _parse_value(value, allocator)
	}
	
	return parsed
}

/*
	Partial YAML parsing of individual frontmatter
	i.e. "text", [c, c++], true, 1, Date 2015-09-11
	See `Value` for supported types
*/
_parse_value :: proc(value: string, allocator: runtime.Allocator) -> Value {
	if strings.has_prefix(value, "[") {
        inner := value[1:len(value)-1]
        parts := strings.split(inner, ",", allocator)
		result := make([dynamic]string, 0, len(parts), allocator)
        for part in parts {
			trimmed := strings.trim_space(part)
			trimmed = strings.trim(trimmed, "\"")
			if (len(trimmed) == 0) {
				continue
			}
            append(&result, trimmed)
        }
        return result[:]
    }

    if value == "true" { 
		return true  
	}
    if value == "false" { 
		return false 
	}

    if strings.contains(value, "-") {
        date, ok := _parse_iso_date(value)
        if ok { 
			return date 
		}
    }

    number, ok := strconv.parse_int(value, 10)
    if ok { 
		return number 
	}

    return strings.trim(value, "\"")
}

/*
	Discover site templates and tokenize
*/
_discover_templates :: proc(working_dir: string) -> [dynamic]Template {
	template_dir, _ := filepath.join({working_dir, "templates"}, context.allocator)
	templates := make([dynamic]Template, context.allocator)

	w := os.walker_create_path(template_dir)
	defer os.walker_destroy(&w)

	for file in os.walker_walk(&w) {
		if filepath.ext(file.name) != ".html" {
			continue
		}
		read, _ := os.read_entire_file_from_path(file.fullpath, context.allocator)

		append(&templates, Template{
			file_path = strings.clone(file.fullpath, context.allocator),
			name = strings.clone(file.name, context.allocator),
			raw = string(read)
		})
	}
	return templates
}

/*
	Lexes the template into discrete sections the parser can use.
	i.e. <h1> {{ heading }} </h1>
	RAW: "<h1> "
	VAR: "heading"
	RAW: " </h1>"
*/
_template_lexer :: proc(templates: ^[dynamic]Template) {
	for &file in templates {
		template := file.raw
		tokens := make([dynamic]Token, context.allocator)
		cursor := 0

		for cursor < len(template) {
			tag_start := strings.index(template[cursor:], "{{")
			block_start := strings.index(template[cursor:], "{%")

			// No more Tags or Blocks
			if tag_start == -1 && block_start == -1 {
				append(&tokens, Token {
					type = .Text,
					content = template[cursor:]
				})
				break
			}

			next := tag_start < block_start ? tag_start : block_start
			
			// TODO(oskar): this all looks so bad. Fix later
			if tag_start == -1 {
				next = block_start
			}
			if block_start == -1 {
				next = tag_start
			}

			next = next + cursor
			content := template[cursor:next]

			// If we have raw content, process it
			if len(content) > 0 {
				append(&tokens, Token {
					type = .Text,
					content = content
				})
				cursor = next
				continue
			} 

			// Process blocks and tags
			if template[cursor] == '{' && template[cursor+1] == '%' {
				end := strings.index(template[cursor:], "%}")
				inner := strings.trim_space(template[cursor+2:cursor+end])
				append(&tokens, Token {
					type = .Block,
					content = inner
				})
				cursor = cursor + end + 2
			} else {
				end := strings.index(template[cursor:], "}}")
				inner := strings.trim_space(template[cursor+2:cursor+end])
				append(&tokens, Token {
					type = .Tag,
					content = inner
				})
				cursor = cursor + end + 2
			}
		}

		file.content = tokens[:]
	}
}

/*
	Parses templates lexed content into an AST
*/
_parse_templates :: proc(templates: [dynamic]Template) -> [dynamic]Parsed_Template {
	parsed := make([dynamic]Parsed_Template, context.allocator)
	for template in templates {
		nodes, extends_target, _ := _parse_nodes(template.content)
		// fmt.printfln("--- AST DEBUG ---")
		// fmt.printfln("name: %v", template.name)
		// fmt.printfln("extends: %v", extends_target)
		// fmt.printfln("nodes: %v", nodes)
		append(&parsed, Parsed_Template {
			name = template.name,
			extends = extends_target,
			nodes = nodes
		})
	}
	return parsed
}

/*
	Performs actual conversion of lex'ed tokens to AST
*/
_parse_nodes :: proc(tokens: []Token) -> ([]Node, string, int) {
	nodes := make([dynamic]Node, context.allocator)
	extends_target := ""
	cursor := 0

	for cursor < len(tokens) {
		token := tokens[cursor]

		// .Text `<h1>Heading</h1>`
		if token.type == .Text {
			append(&nodes, Node {
				kind = .Text,
				value = token.content
			})
			cursor = cursor + 1
			continue
		}

		// .Tag `title | upper | truncate`
		if token.type == .Tag {
			parts := strings.split(token.content, "|", context.allocator)
			var := strings.trim_space(parts[0])

			pipes := make([dynamic]string, 0, len(parts) - 1, context.allocator)
			for part in parts[1:] {
				pipe := strings.trim_space(part)
				if len(pipe) == 0 {
					continue
				}
				append(&pipes, pipe)
			}

			append(&nodes, Node {
				kind = .Tag,
				value = var,
				pipes = pipes[:]
			})
			cursor = cursor + 1
			continue
		}

		// .Block `for, if, extends & block`
		// TODO(oskar): `include` in blocks
		if token.type == .Block {
			block_type, _, arg := strings.partition(token.content, " ")
			block_type = strings.trim_space(block_type)
			arg = strings.trim_space(arg)

			switch block_type {
				case "extends":
					extends_target = strings.trim(arg, "\"")
					cursor = cursor + 1
				
				case "block", "if", "for":
					node_kind := Node_Kind.Block
					if block_type == "if" { 
						node_kind = .If 
					}
					if block_type == "for" {
						node_kind = .For
					}

					child_nodes, _, consumed := _parse_nodes(tokens[cursor+1:])
					append(&nodes, Node {
						kind = node_kind,
						value = arg,
						children = child_nodes
					})
					cursor = cursor + consumed + 2

				case "endblock", "endif", "endfor":
					return nodes[:], extends_target, cursor
					
				case:
					fmt.printfln("soma (warn): unknown block type `%s`", block_type)
					cursor = cursor + 1
			}
		}
	}
	return nodes[:], extends_target, cursor
}

/*
	Resolves any possible inheritence requirements of templates
	TODO(oskar): cycle detection
*/
_resolve_templates :: proc(templates: [dynamic]Parsed_Template) -> [dynamic]Parsed_Template {
	result := make([dynamic]Parsed_Template, context.allocator)
	for template in templates {
		resolved := _resolve_template(template, templates)
		append(&result, resolved)
	}
	return result
}

_resolve_template :: proc(template: Parsed_Template, all: [dynamic]Parsed_Template) -> Parsed_Template {
	final_nodes := make([dynamic]Node, context.allocator)
	if template.extends == "" {
		return template
	}

	// base.html <- default.html <- post.html is not supported by design
	parent_template, found := _search_templates(template.extends, all)
	if !found {
		fmt.printfln("soma (err): parent template '%s' not found", template.extends)
		return template
	}

	// Get blocks from child template
	child_blocks := make(map[string][]Node, context.allocator)
	for node in template.nodes {
		if node.kind == .Block {
			map_insert(&child_blocks, node.value, node.children)
		}
	}

	// Build final nodes by resolving block overrides and expanding includes
	for node in parent_template.nodes {
		if node.kind == .Block {			// -- PROCESS BLOCKS
			block_name, found := child_blocks[node.value]
			if found {
				for child_node in block_name {
					append(&final_nodes, child_node)
				}
			} else {
				append(&final_nodes, node)
			}
		} else if node.kind == .Include {	// -- PROCESS INCLUDES
			include_template, found := _search_templates(node.value, all)
			if !found {
				fmt.printfln("soma (err): include template '%s' not found", node.value)
				continue
			}
			for include_node in include_template.nodes {
				append(&final_nodes, include_node)
			}
		} else {							// -- ADD REGULAR NODE
			append(&final_nodes, node)
		}
	}

	return Parsed_Template {
		name = template.name,
		nodes = final_nodes[:],
		extends = ""
	}
}

_search_templates :: proc(key: string, all: [dynamic]Parsed_Template) -> (Parsed_Template, bool) {
	for template in all {
		if template.name == key {
			return template, true
		}
	}
	return {}, false
}

/*
	Render the final build contents from resolved templates and content
*/
_render_site :: proc(pages: [dynamic]Page, templates: [dynamic]Parsed_Template) -> [dynamic]Page {
	final_pages := make([dynamic]Page, context.allocator)

	for page in pages {
		sb := strings.builder_make(context.allocator)
		page_path := page.file_path
		scope: Variable_Scope

		// Grab template
		page_template, ok := page.frontmatter["template"].(string)
		if !ok {
			page_template = "default.html"
		}
		template, found := _search_templates(page_template, templates)
		if !found {
			fmt.printfln("soma (err): template `%s` not found in `%s`!", 
			page_template, filepath.base(page_path))
		}

		// Set scope
		for name, _ in page.frontmatter {
			scope.variables[name] = &registry.items[{page_path, name}]
		}
		scope.variables["category"] = &registry.items[{page_path, "category"}]
		scope.variables["content"] 	= &registry.items[{page_path, "content"}]
		scope.variables["page_ref"] = &registry.items[{page_path, "page_ref"}]
		scope.variables["items"] 	= &registry.items[{page_path, "items"}]

		// Process template AST
		for node in template.nodes {
			_render_node(node, page, &sb, &scope)
		}

		build_html := strings.to_string(sb)
		
		//fmt.printfln("CONTENT RAW HTML: %v", page.content)
		//fmt.printfln("FINAL AST: %v", template.nodes)
		//fmt.printfln("HTML FOR `%v`:\n %v", page_path, build_html)
		append(&final_pages, Page {
			file_path = page_path,
			content = build_html,
			is_index = page.is_index,
			category = page.category
		})
	}

	return final_pages
}

_render_node :: proc(node: Node, page: Page, sb: ^strings.Builder, scope: ^Variable_Scope) {
	#partial switch node.kind {
		case .Text:
			strings.write_string(sb, node.value)
		case .Tag:
			_render_tag(node, page, sb, scope)
		case .For:
			_render_for(node, page, sb, scope)
		case .If:
			_render_if(node, page, sb, scope)
		case:
			return
	}
}

_render_tag :: proc(node: Node, page: Page, sb: ^strings.Builder, scope: ^Variable_Scope) {
	to_render := "none"

	tag, sep, accessor := strings.partition(node.value, ".")

	item := _var_scope_lookup(scope, tag)
	read: Value
	read_ok: bool

	switch item.type {
		case .Undefined:
			base := filepath.base(page.file_path)
			fmt.printfln("soma (err): `%s` not a property of `%s`", tag, base)
		case .Page:
			if sep == "." {
				reg_lookup, found := registry.items[{item.page.file_path, accessor}]
				if found 
				{ 
					read = reg_lookup.value
					read_ok = true
				}
			} else {
				fmt.printfln("soma (err): variable `%s` is a page and requires field access, e.g. `%s.title`",
				tag,
				tag)
			}
		case .Array:
			fmt.printfln("soma (err): variable is an array of pages and is not allowed here")
		case .Value:
			read = item.value
			read_ok = true
	}

	if !read_ok { return }

	switch varient in read {
		case string:
			to_render = varient
		case []string:
			tmp := make([dynamic]string, context.allocator)
			for str in varient {
				append(&tmp, str)
				append(&tmp, ", ")
			}
			len := len(tmp)
			if len >= 1 {
				to_render = strings.concatenate(tmp[:len-1], context.allocator)
			} else {
				to_render = ""
			}
		case int:
			to_render = fmt.aprint(varient, allocator = context.temp_allocator)
		case bool:
			to_render = varient ? "true" : "false"
		case Date:
			to_render = fmt.tprintf("%d-%02d-%02d", varient.year, varient.month, varient.day)
	}
	
	// Piping
	for pipe in node.pipes {
		built_in_func, ok := built_ins[pipe]
		if ok {
			to_render = built_in_func(to_render)
		} else {
			fmt.printfln("soma (err): failed to find function `%v`", pipe)
		}
	}

	strings.write_string(sb, to_render)
}

/*
	Handles rendering `for` nodes in AST.
		for item in items
		loop_var (item), collection (items)
*/
_render_for :: proc(node: Node, page: Page, sb: ^strings.Builder, scope: ^Variable_Scope) {
	for_scope: Variable_Scope
	for_scope.prev = scope
	
	loop_var, _, collection := strings.partition(node.value, "in")
	loop_var = strings.trim_space(loop_var)
	collection = strings.trim_space(collection)

	item := _resolve_scoped_item(collection, scope)

	// TODO(oskar): Assess whether or not we want to be able to
	// handle other values like we do with int. Just []string & []Page?
	switch item.type {
		case .Undefined:
			fmt.printfln("soma (err): collection `%s` undefined in `%s/%s`",
    			collection, page.category, filepath.base(page.file_path))
		case .Value:
			switch value in item.value {
				case string:
				case int:
					for v in 0..<value {
						item := new(Item, context.allocator)
						item.value = v
						item.type = .Value
						for_scope.variables[loop_var] = item
						for n in node.children {
							_render_node(n, page, sb, &for_scope)
						}
					}
				case bool:
				case Date:
				case []string:
					for v in value {
						item := new(Item, context.allocator)
						item.value = v
						item.type = .Value
						for_scope.variables[loop_var] = item
						for n in node.children {
							_render_node(n, page, sb, &for_scope)
						}
					}
			}
		case .Page:
		case .Array:
			for &page in item.items {
				for_scope.variables[loop_var] = &registry.items[{
					page.file_path, "",
				}]
				for n in node.children {
					_render_node(n, page, sb, &for_scope)
				}
			}
	}
}

_render_if :: proc(node: Node, page: Page, sb: ^strings.Builder, scope: ^Variable_Scope) {
	item := _resolve_scoped_item(node.value, scope)

	if item.type == .Undefined {
		fmt.printfln("soma (err): frontmatter `%s` not found in `%s/%s`",
    		node.value, page.category, filepath.base(page.file_path))
		return
	}

	bool_value, is_bool := item.value.(bool)
	if is_bool && !bool_value {
		return
	}

	for child in node.children {
		_render_node(child, page, sb, scope)
	}
}

/*
	Resolves expression to handle dot access if required
	i.e. `item.accessor` -> we find the relevant attribute
	whereas 	  `item` -> we just return the item
*/
_resolve_scoped_item :: proc(expression: string, scope: ^Variable_Scope) -> ^Item {
	tag, sep, accessor := strings.partition(expression, ".")

	if sep != "." {
		return _var_scope_lookup(scope, expression)
	}

	item := _var_scope_lookup(scope, tag)
	if item.type != .Page {
		undef := new(Item, context.allocator)
        undef.type = .Undefined
        return undef
	}

	field_item, found := &registry.items[{item.page.file_path, accessor}]
	if !found {
		undef := new(Item, context.allocator)
		undef.type = .Undefined
		return undef
	}

	return field_item
}

/*
	Writes our final pages to the build directory,
	with final path following simple rules
		index.md 	   -> index.html			.md -> .html
		blog/index.md  -> blog/index.html		.md -> .html
		blog/post.md   -> blog/post/index.html	.md -> /index.html
*/
_build_site :: proc(build_pages: [dynamic]Page, build_dir: string, working_dir: string) {
	asset_in ,_ := filepath.join({working_dir, "/assets"}, context.allocator)
	asset_out,_ := filepath.join({build_dir, "/assets"}, context.allocator)
	os.copy_directory_all(asset_out, asset_in)

	for page in build_pages {
		build_path, _ := filepath.join({build_dir, _page_rel_output_path(page)}, context.allocator)
		_write_text_file(build_path, page.content)
	}
}

_page_rel_output_path :: proc(page: Page) -> (string) {
	file_stem := filepath.short_stem(filepath.base(page.file_path))

	if page.category != "" {
		file_stem = strings.concatenate({page.category, "/", file_stem}, context.allocator)
	}
	
	extension := ".html"
	if !page.is_index {
		extension = "/index.html"
	}
	
	page_rel, _ := strings.concatenate({file_stem, extension}, context.allocator)
	return page_rel
}

_page_url :: proc(page: Page) -> string {
	page := strings.trim_suffix(_page_rel_output_path(page), "index.html")
	return strings.concatenate({"/", page}, context.allocator) or_else ""
}

_markdown_to_html :: proc(markdown_source: string, allocator: runtime.Allocator) -> string {
	builder := strings.builder_make(allocator)
	input := transmute([]u8)markdown_source

	md_html(
		cast(cstring)raw_data(input),
		c.uint(len(input)),
		_md4c_callback,
		&builder,
		MARKDOWN_PARSER_FLAGS,
		0,
	)

	return strings.to_string(builder)
}

_md4c_callback :: proc "c" (output: cstring, size: c.uint, userdata: rawptr) {
	// Due to nature of foregin C we need to declare context again?
	// TODO(oskar): research this ^
	context = runtime.default_context()
	builder := cast(^strings.Builder)userdata
	chunk := string(output)
	strings.write_string(builder, chunk[:size])
}

_valid_dir :: proc(cmd: string) {
	if (!os.exists("soma.toml")) {
		fmt.printfln("soma (err): soma.toml not found!\n" +
					"            %s must be ran from site root", cmd)
		os.exit(1)
	}
	return
}

_n_unique_categories :: proc(pages: [dynamic]Page) -> (int) {
    seen := make(map[string]bool, context.allocator)
	for page in pages {
        if page.category != "" {
            seen[page.category] = true
        }
    }
    return len(seen)
}

/*
	Command: serve
	Flag(s): port, dev
	Serve site at specific port. Can be in dev mode
	which supports live reload
*/
serve :: proc(port: int, dev: bool) {
	listen_and_serve(port)
}

/*
	Command: clean
	Cleans the specified build directory
*/
clean :: proc(working_dir: string) {
	path := strings.concatenate({working_dir, "/build"}, context.allocator)

	err := os.remove_all(path)
	if (err != nil) {
		fmt.printfln("soma (err): Error cleaning! %v", err)
		return
	}
	fmt.printfln("soma: cleaned %s", path)
}
