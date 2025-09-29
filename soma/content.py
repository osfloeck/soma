'''
content.py

Default content for newly generated sites

Author: Oskar Floeck
Date: 12-09-2025
License: MIT
'''

DEFAULT_CONTENT = {
    "index.md": '''---
title: "Welcome to My Site"
template: "home"
---

# Welcome!

This is your new static site built with Soma. Edit this file to customise your homepage.

## Getting Started

- Add blog posts in the `blog/content/` directory
- Add projects in the `projects/content/` directory
- Customise templates in the `templates/` directory
- Run `soma build` to generate your site
- Run `soma serve` to preview locally
''',

    "blog/index.md": '''---
title: "Blog"
template: "category-index"
---

Welcome to my blog! Here you'll find my latest thoughts and updates.
''',

    "projects/index.md": '''---
title: "Projects"
template: "category-index"
---

Welcome to my projects page! Here are some things I've been working on.
''',

    "blog/content/first-post.md": '''---
title: "My First Blog Post"
template: "blog-post"
date: "2024-01-01"
---

# Hello World!

This is my first blog post. You can edit this file or create new `.md` files in the `blog/content/` directory.

## Features

- Write in **Markdown**
- Automatic template rendering
- Clean URL structure
''',

    "projects/content/cool-project.md": '''---
title: "My Cool Project"
template: "project"
date: "2024-01-01"
---

# My Cool Project

This is a description of one of my projects. Add more `.md` files in the `projects/content/` directory to showcase your work.

## What I Built

- Feature 1
- Feature 2
- Feature 3
'''
}
