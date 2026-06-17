/*
	main.odin
	The driver for soma, a static site generator.
*/

package soma

import "core:fmt"
import "core:os"
import "core:strings"
import "core:path/filepath"
import "core:c"
import "base:runtime"

// md4c FFI
foreign import md4c "system:md4c-html"

@(default_calling_convention = "c")
foreign md4c {
	md_html :: proc(
		input:          [^]u8,
		input_size:     c.uint,
		process_output: proc "c" (text: [^]u8, size: c.uint, userdata: rawptr),
		userdata:       rawptr,
		parser_flags:   c.uint,
		renderer_flags: c.uint,
	) -> c.int ---
}

// md4c parser flags
MD_FLAG_PERMISSIVE_URL_AUTOLINKS :: c.uint(0x0004)
MD_FLAG_TABLES                   :: c.uint(0x0100)
MD_FLAG_STRIKETHROUGH            :: c.uint(0x0200)
MD_FLAG_TASKLISTS                :: c.uint(0x0800)

MARKDOWN_PARSER_FLAGS :: MD_FLAG_PERMISSIVE_URL_AUTOLINKS |
						 MD_FLAG_TABLES |
						 MD_FLAG_STRIKETHROUGH |
						 MD_FLAG_TASKLISTS


// -------------------------------- Core types ---------------------------------

Process_Mode :: enum {
	Root_Page,
	Cat_Page,
	Cat_Index,
}

Frontmatter_Value :: union {
	string,
	i64,
	[]string,
}

Value :: union {
	string,
	i64,
	bool,
	Date,
	[]Value,
	map[string]Value,
}

Date :: struct {
	year:  int,
	month: int,
	day:   int,
}


// --------------------------- Template engine AST -----------------------------
// Supported surface only: {{ var }}, dotted access, | safe, | format_date,
// {% if path %}, {% for x in path %}, {% extends %}, {% block %}.

Node_Kind :: enum {
	Text,      // literal passthrough HTML
	Variable,  // {{ a.b.c | filter }}
	If,        // {% if path %} ... {% endif %}
	For,       // {% for name in path %} ... {% endfor %}
	Block,     // {% block name %} ... {% endblock %}
}

Filter :: enum {
	None,
	Safe,
	Format_Date,
}

Template_Node :: struct {
	kind:          Node_Kind,

	text:          string,           // Text
	path:          []string,         // Variable / If: dotted access, e.g. {"item","url"}
	filter:        Filter,           // Variable

	loop_var:      string,           // For: the per-iteration binding name
	iterable_path: []string,         // For: dotted access to the list

	block_name:    string,           // Block

	children:      []Template_Node,  // If / For / Block bodies
}

Parsed_Template :: struct {
	extends: string,                        // "" when the template has no parent
	nodes:   []Template_Node,               // top-level node stream
	blocks:  map[string][]Template_Node,    // block overrides this template defines
}

Template_Env :: struct {
	templates_dir: string,
}


// ------------------------------ Default content ------------------------------

default_templates :: proc() -> map[string]string {
    templates := make(map[string]string, context.allocator)

    templates["base.html"]     = BASE_TEMPLATE
    templates["default.html"]  = DEFAULT_TEMPLATE
    templates["category.html"] = CATEGORY_TEMPLATE
    templates["content.html"]  = CONTENT_TEMPLATE  

    return templates
}

default_content :: proc() -> map[string]string {
	default_content := make(map[string]string, context.allocator)

	default_content["index.md"] = "---\ntitle: \"Home\"\ntemplate: \"default\"\n---\n\n# Welcome\n\nNew soma site.\n"
	default_content["about.md"] = "---\ntitle: \"About\"\ntemplate: \"default\"\n---\n\nAbout this site.\n"
	default_content["blog/index.md"] = "---\ntitle: \"Blog\"\ntemplate: \"category\"\n---\n\nPosts.\n"
	default_content["projects/index.md"] = "---\ntitle: \"Projects\"\ntemplate: \"category\"\n---\n\nThings I built.\n"

	return default_content
}


// ----------------------------------- init ------------------------------------

init :: proc(name: string) {
	if os.exists(name) {
		fmt.printfln("soma (error): directory `%s` already exists", name)
		return
	}

	scaffold_directories(name)
	create_default_templates(join_path({name, "templates"}))
	create_default_content(name)
	create_default_assets(join_path({name, "assets"}))
	copy_default_fonts(join_path({name, "assets", "fonts"}))

	fmt.printfln("soma: new instance `%s` created", name)
	fmt.println("soma: run `soma build` then `soma serve` to get started")
}

scaffold_directories :: proc(name: string) {
	directories := []string {
		name,
		join_path({name, "templates"}),
		join_path({name, "build"}),
		join_path({name, "assets"}),
		join_path({name, "assets", "css"}),
		join_path({name, "assets", "fonts"}),
		join_path({name, "blog"}),
		join_path({name, "projects"}),
	}
	for directory in directories {
		os.make_directory(directory)
	}
}

create_default_templates :: proc(templates_dir: string) {
	templates := default_templates()
	for file_name, contents in templates {
		write_text_file(join_path({templates_dir, file_name}), contents)
	}
}

create_default_content :: proc(site_path: string) {
	content := default_content()
	for relative_path, contents in content {
		write_text_file(join_path({site_path, relative_path}), contents)
	}
}

create_default_assets :: proc(asset_path: string) {
	// TODO: write the Tailwind input css (with CMU Serif @font-face) and a
	// minimal app.css placeholder. The real app.css is produced by the
	// Tailwind CLI, orchestrated from package.json — not by soma.
	fmt.println("soma: create_default_assets — TODO")
}

copy_default_fonts :: proc(font_path: string) {
	// TODO: embed the CMU Serif suite at compile time and write it out here.
	// Intended approach once the font files live beside this source:
	//     FONT_FILES :: #load_directory("fonts")
	//     for f in FONT_FILES { write_bytes_file(filepath.join({font_path, f.name}), f.data) }
	fmt.println("soma: copy_default_fonts — TODO")
}

join_path :: proc(parts: []string) -> string {
	path, err := filepath.join(parts)
		if err != nil {
			panic("soma: filepath.join allocation failed")
		}
		return path
}

write_text_file :: proc(path: string, contents: string) {
	parent := filepath.dir(path)
	os.make_directory(parent)
	err := os.write_entire_file(path, transmute([]u8)contents)
	if err != nil {
		fmt.printfln("soma (error): could not write file %s", path)
	}
}


// ----------------------------------- Build -----------------------------------

build :: proc(dev_mode: bool = false) {
	// TODO: clear build/, generate+save build hash, copy assets, then for each
	// discovered root item and category, render through the template engine.
	fmt.printfln("soma: build (dev_mode=%v) — TODO", dev_mode)
}

build_assets :: proc() {
	// TODO: copy assets/ tree into build/assets/.
	fmt.println("soma: build_assets — TODO")
}

discover_content :: proc() -> []string {
	// TODO: return category directories (those containing index.md), skipping
	// templates/build/assets and dotfiles.
	return nil
}

discover_root_items :: proc() -> []string {
	// TODO: return top-level *.md files (index.md, about.md, ...).
	return nil
}

process_category_dir :: proc(env: ^Template_Env, category_dir: string, dev_mode: bool, build_hash: string) {
	// TODO: for each non-draft *.md, classify index vs item, then build_page.
	fmt.printfln("soma: process_category_dir %s — TODO", category_dir)
}

build_page :: proc(env: ^Template_Env, md_file_path: string, mode: Process_Mode, dev_mode: bool, build_hash: string) {
	// TODO: parse_md -> build context (+ items for Cat_Index) -> render -> write
	// to build/ with pretty-URL folder layout (post -> post/index.html).
	fmt.printfln("soma: build_page %s — TODO", md_file_path)
}

collect_items :: proc(content_dir: string, category_name: string) -> []map[string]Value {
	// TODO: parse every non-draft, non-index *.md into a context map, attach a
	// "url" key, then SORT here in Odin (newest first / by rank) so templates
	// only ever iterate already-ordered data.
	return nil
}


// ----------------------- Parse Markdown + Frontmatter ------------------------

parse_md :: proc(file_path: string) -> (page: map[string]Value, ok: bool) {
	raw, err := os.read_entire_file_from_path(file_path, context.allocator)
	if err != nil {
		fmt.printfln("soma (error): could not read %s", file_path)
		return nil, false
	}
	defer delete(raw)

	source := string(raw)
	if !strings.has_prefix(source, "---") {
		fmt.printfln("soma (error): missing frontmatter in %s", file_path)
		return nil, false
	}

	frontmatter_text, body_text, split_ok := split_frontmatter(source)
	if !split_ok {
		fmt.printfln("soma (error): incomplete frontmatter in %s", file_path)
		return nil, false
	}

	frontmatter := parse_frontmatter(frontmatter_text)
	html_body := markdown_to_html(body_text)

	page = frontmatter_to_context(frontmatter)
	page["content"] = html_body
	return page, true
}

// Splits a "---\n...\n---\n..." document into (frontmatter, body).
split_frontmatter :: proc(source: string) -> (frontmatter: string, body: string, ok: bool) {
	// TODO: find the two `---` fences and slice between/after them.
	return "", "", false
}

parse_frontmatter :: proc(text: string) -> map[string]Frontmatter_Value {
	// TODO: line-by-line `key: value`. Values: quoted string, integer, or
	// inline ["a", "b"] string array. No nesting, no multiline.
	return nil
}

frontmatter_to_context :: proc(frontmatter: map[string]Frontmatter_Value) -> map[string]Value {
	// TODO: lift each Frontmatter_Value into a Value; parse a "date" string
	// into a Date so format_date can work.
	return nil
}

// The md4c callback appends each emitted chunk to the strings.Builder passed
// as userdata. It runs with the C calling convention, so we restore a usable
// Odin context before doing anything allocator-aware.
markdown_append_chunk :: proc "c" (text: [^]u8, size: c.uint, userdata: rawptr) {
	context = runtime.default_context()
	builder := cast(^strings.Builder)userdata
	chunk := string(text[:int(size)])
	strings.write_string(builder, chunk)
}

markdown_to_html :: proc(markdown_source: string) -> string {
	builder := strings.builder_make()
	input := transmute([]u8)markdown_source

	md_html(
		raw_data(input),
		c.uint(len(input)),
		markdown_append_chunk,
		&builder,
		MARKDOWN_PARSER_FLAGS,
		0,
	)

	return strings.to_string(builder)
}


// ------------------------------ Template engine ------------------------------


render_template :: proc(env: ^Template_Env, template_name: string, context_map: map[string]Value) -> (string, bool) {
	// TODO: load+parse the named template, resolve its extends chain by
	// substituting block overrides into the base, then walk nodes.
	return "", false
}

parse_template :: proc(source: string) -> Parsed_Template {
	// TODO: tokenize {{ }} and {% %}, building the Template_Node tree.
	return Parsed_Template{}
}

render_nodes :: proc(builder: ^strings.Builder, nodes: []Template_Node, context_map: map[string]Value) {
	// TODO: dispatch on node.kind; recurse into If/For/Block children.
}

// Walks a dotted path like {"item","url"} through nested maps.
lookup_value :: proc(context_map: map[string]Value, path: []string) -> (Value, bool) {
	// TODO: descend map[string]Value per segment.
	return nil, false
}

// {% if %} truthiness: nil, false, "", and empty lists are falsy.
is_truthy :: proc(value: Value) -> bool {
	// TODO
	return false
}


// ---------------------------- Date helpers -----------------------------------

parse_iso_date :: proc(text: string) -> (Date, bool) {
	// TODO: parse "YYYY-MM-DD".
	return Date{}, false
}

MONTH_NAMES := [13]string {
	"", "January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December",
}

WEEKDAY_NAMES := [7]string {
	"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
}

// Sakamoto's method: weekday index 0=Sunday for a proleptic Gregorian date.
weekday_index :: proc(date: Date) -> int {
	month_offsets := [12]int{0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4}
	year := date.year
	if date.month < 3 {
		year -= 1
	}
	return (year + year / 4 - year / 100 + year / 400 + month_offsets[date.month - 1] + date.day) % 7
}

ordinal_suffix :: proc(day: int) -> string {
	if 11 <= day && day <= 13 {
		return "th"
	}
	switch day % 10 {
	case 1:
		return "st"
	case 2:
		return "nd"
	case 3:
		return "rd"
	case:
		return "th"
	}
}

format_date :: proc(date: Date) -> string {
	weekday := WEEKDAY_NAMES[weekday_index(date)]
	month := MONTH_NAMES[date.month]
	suffix := ordinal_suffix(date.day)
	// "Sunday, 19th January, 2026".
	return fmt.tprintf("%s, %d%s %s, %d", weekday, date.day, suffix, month, date.year)
}


// ----------------------------------- Serve -----------------------------------

serve :: proc(port: int, dev: bool) {
	// TODO: hand-rolled static HTTP server over core:net TCP sockets. In dev,
	// poll file mtimes on a short interval, debounce, rebuild(dev_mode=true),
	// and inject the live-reload script.
	fmt.printfln("soma: serve port=%d dev=%v — TODO", port, dev)
}

clean :: proc() {
	// TODO: remove build/.
	fmt.println("soma: cleaning build directory — TODO")
}


// ------------------------------------ CLI ------------------------------------

print_usage :: proc() {
	fmt.println("soma — a static site generator without the noise")
	fmt.println("usage:")
	fmt.println("  soma init <name>     scaffold a new site")
	fmt.println("  soma build           render site into build/")
	fmt.println("  soma serve [port]    serve build/ (add --dev to watch+rebuild)")
	fmt.println("  soma clean           remove build/")
}

main :: proc() {
	arguments := os.args
	if len(arguments) < 2 {
		print_usage()
		return
	}

	command := arguments[1]
	switch command {
	case "init":
		if len(arguments) < 3 {
			fmt.println("soma (error): `init` needs a site name")
			return
		}
		init(arguments[2])

	case "build":
		build(false)

	case "serve":
		port := 8000
		dev := false
		for argument in arguments[2:] {
			if argument == "--dev" {
				dev = true
			}
			// TODO: parse a numeric port argument here.
		}
		serve(port, dev)

	case "clean":
		clean()

	case:
		print_usage()
	}
}
