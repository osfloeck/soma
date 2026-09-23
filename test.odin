/*
	test.odin
	Provides basic test coverage for soma
*/

package soma

import "core:testing"

// TODO(oskar): All of these need work

/* 
	Frontmatter parsing and value conversion
*/
@(test)
test_parse_value :: proc(t: ^testing.T) {
	value := _parse_value("[odin, \"static sites\", c++, \"web\"]", context.allocator)

	tags, ok := value.([]string)

	testing.expect(t, ok)
	testing.expect_value(t, len(tags), 4)
	testing.expect_value(t, tags[0], "odin")
	testing.expect_value(t, tags[1], "static sites")
	testing.expect_value(t, tags[2], "c++")
	testing.expect_value(t, tags[3], "web")
}

/*
	Frontmatter handling correctness
*/
@(test)
test_extract_frontmatter :: proc(t: ^testing.T) {
	source := `
		title: "Building Soma"
		template: "article.html"
		date: 2026-09-23
		tags: [odin, "static sites", programming]
		draft: false
		reading_time: 12
		content: "should be rejected"
		page_ref: "should be rejected"
	`

	result := _extract_frontmatter(source, context.allocator)

	title, title_ok := result["title"].(string)
	template, template_ok := result["template"].(string)
	date, date_ok := result["date"].(Date)
	tags, tags_ok := result["tags"].([]string)
	draft, draft_ok := result["draft"].(bool)
	reading_time, reading_time_ok := result["reading_time"].(int)

	testing.expect(t, title_ok)
	testing.expect(t, template_ok)
	testing.expect(t, date_ok)
	testing.expect(t, tags_ok)
	testing.expect(t, draft_ok)
	testing.expect(t, reading_time_ok)

	testing.expect_value(t, title, "Building Soma")
	testing.expect_value(t, template, "article.html")
	testing.expect_value(t, date.year, 2026)
	testing.expect_value(t, date.month, 9)
	testing.expect_value(t, date.day, 23)
	testing.expect_value(t, len(tags), 3)
	testing.expect_value(t, tags[1], "static sites")
	testing.expect_value(t, draft, false)
	testing.expect_value(t, reading_time, 12)

	_, content_exists := result["content"]
	_, page_ref_exists := result["page_ref"]

	testing.expect(t, !content_exists)
	testing.expect(t, !page_ref_exists)
}


/* 
	Output paths and URLs
*/
@(test)
test_page_rel_output_path :: proc(t: ^testing.T) {
	page := Page{
		file_path = "/home/usr/site/projects/soma.md",
		category = "projects",
		is_index = false,
	}

	result := _page_rel_output_path(page)

	testing.expect_value(t, result, "projects/soma/index.html")
}

@(test)
test_page_url :: proc(t: ^testing.T) {
	page := Page{
		file_path = "/home/usr/site/blog/hello-world.md",
		category = "blog",
		is_index = false,
	}

	result := _page_url(page)

	testing.expect_value(t, result, "/blog/hello-world/")
}

/* 
	Template lexing
*/
@(test)
test_template_lexer :: proc(t: ^testing.T) {
	dummy_content := 
		`<article>
			<h1>{{ title | uppercase | brief }}</h1>
			{% if published %}
				<p>Published</p>
			{% endif %}
			{% for item in items %}
				{{ item.title }}
			{% endfor %}
		</article>`
	
	templates := [dynamic]Template{}
	
	template := Template{ raw = dummy_content }
	append(&templates, template)
	
	_template_lexer(&templates)

	tokens := templates[0].content

	testing.expect_value(t, len(tokens), 13)
	testing.expect_value(t, tokens[1].type, Token_Kind.Tag)
	testing.expect_value(t, tokens[12].content, "\n\t\t</article>")
}

/*
	Template parsing
*/
@(test)
test_parse_nodes :: proc(t: ^testing.T) {
	tokens := []Token{
		{
			type = .Text,
			content = "<article><h1>",
		},
		{
			type = .Tag,
			content = "title | uppercase | brief",
		},
		{
			type = .Text,
			content = "</h1>",
		},
		{
			type = .Block,
			content = "if published",
		},
		{
			type = .Text,
			content = "<p>Published</p>",
		},
		{
			type = .Block,
			content = "endif",
		},
		{
			type = .Block,
			content = "for item in items",
		},
		{
			type = .Tag,
			content = "item.title",
		},
		{
			type = .Block,
			content = "endfor",
		},
		{
			type = .Text,
			content = "</article>",
		},
	}

	nodes, extends, _ := _parse_nodes(tokens)

	testing.expect_value(t, len(nodes), 6)

	testing.expect_value(t, nodes[0].kind, Node_Kind.Text)
	testing.expect_value(t, nodes[0].value, "<article><h1>")

	testing.expect_value(t, nodes[1].kind, Node_Kind.Tag)
	testing.expect_value(t, nodes[1].value, "title")
	testing.expect_value(t, len(nodes[1].pipes), 2)
	testing.expect_value(t, nodes[1].pipes[0], "uppercase")
	testing.expect_value(t, nodes[1].pipes[1], "brief")

	testing.expect_value(t, nodes[2].kind, Node_Kind.Text)
	testing.expect_value(t, nodes[2].value, "</h1>")

	testing.expect_value(t, nodes[3].kind, Node_Kind.If)
	testing.expect_value(t, nodes[3].value, "published")
	testing.expect_value(t, len(nodes[3].children), 1)
	testing.expect_value(t, nodes[3].children[0].kind, Node_Kind.Text)
	testing.expect_value(t, nodes[3].children[0].value, "<p>Published</p>")

	testing.expect_value(t, nodes[4].kind, Node_Kind.For)
	testing.expect_value(t, nodes[4].value, "item in items")
	testing.expect_value(t, len(nodes[4].children), 1)
	testing.expect_value(t, nodes[4].children[0].kind, Node_Kind.Tag)
	testing.expect_value(t, nodes[4].children[0].value, "item.title")

	testing.expect_value(t, nodes[5].kind, Node_Kind.Text)
	testing.expect_value(t, nodes[5].value, "</article>")
}


/*
	Template inheritance
*/
@(test)
test_resolve_template :: proc(t: ^testing.T) {
	base := Parsed_Template{
		name = "base.html",
		nodes = []Node{
			{
				kind = .Text,
				value = "<html><body>",
			},
			{
				kind = .Block,
				value = "content",
				children = []Node{
					{
						kind = .Text,
						value = "Default content",
					},
				},
			},
			{
				kind = .Text,
				value = "</body></html>",
			},
		},
	}

	child := Parsed_Template{
		name = "article.html",
		extends = "base.html",
		nodes = []Node{
			{
				kind = .Block,
				value = "content",
				children = []Node{
					{
						kind = .Text,
						value = "<article>{{ title }}</article>",
					},
				},
			},
		},
	}

	templates := [dynamic]Parsed_Template{}
	append(&templates, base)
	append(&templates, child)

	result := _resolve_template(child, templates)

	testing.expect_value(t, result.name, "article.html")
	testing.expect_value(t, result.extends, "")
	testing.expect_value(t, len(result.nodes), 3)

	testing.expect_value(t, result.nodes[0].value, "<html><body>")
	testing.expect_value(t, result.nodes[1].value, "<article>{{ title }}</article>")
	testing.expect_value(t, result.nodes[2].value, "</body></html>")
}


/*
	Template lookup
*/
@(test)
test_search_templates :: proc(t: ^testing.T) {
	templates := [dynamic]Parsed_Template{}

	append(&templates, Parsed_Template{
		name = "base.html",
	})
	append(&templates, Parsed_Template{
		name = "default.html",
	})
	append(&templates, Parsed_Template{
		name = "article.html",
	})

	result, found := _search_templates("article.html", templates)

	testing.expect(t, found)
	testing.expect_value(t, result.name, "article.html")
}
