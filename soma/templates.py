'''
templates.py

Default templates for new sites

Author: Oskar Floeck
Date: 12-09-2025
License: MIT
'''

# Base template
BASE_TEMPLATE = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta name="build-hash" content="{{ build_hash }}">
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ title }}</title>
    <link rel="stylesheet" href="/assets/css/style.css">
    <link rel="stylesheet" href="/assets/css/pygments.css">
</head>
<body>
    <nav>
        <a href="/">Home</a>
        <a href="/blog/">Blog</a>
        <a href="/projects/">Projects</a>
        <a href="/about">About</a>
    </nav>
    <div class="content">
        {% block content %} {% endblock %}
    </div>
    {% if dev_mode %}
    <script>
        {{ inject_script | safe }}
    </script>
    {% endif %}
</body>
</html>'''

# Default Template: e.g. Landing page, About, Contact..
DEFAULT_TEMPLATE = '''{% extends "base.html" %}
{% block content %}
<h1>{{ title }}</h1>
{{ content | safe }}
{% endblock %}'''

# Category Template: e.g. Blog or Projects
CATEGORY_TEMPLATE = '''{% extends "base.html" %}
{% block content %}
<h1>{{ title }}</h1>
{{ content | safe }}
<h2>Recent Content</h2>
<ul>
{% for item in items %}
    <li><a href="{{ item.url }}">{{ item.title }}</a> - {{ item.date | format_date }}</li>
{% endfor %}
</ul>
{% endblock %}'''

# Content Template: e.g. Blog Post or Project
CONTENT_TEMPLATE = '''{% extends "base.html" %}
{% block content %}
<h1>{{ title }}</h1>
<p><time datetime="{{ date }}">{{ date | format_date }}</time></p>
{{ content | safe }}
{% endblock %}'''

DEFAULT_TEMPLATES = {
    'base.html': BASE_TEMPLATE,
    'default.html': DEFAULT_TEMPLATE,
    'category.html': CATEGORY_TEMPLATE,
    'content.html': CONTENT_TEMPLATE,
}
