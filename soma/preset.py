'''
preset.py

Default content for newly generated sites

Author: Oskar Floeck
Date: 12-09-2025
License: MIT
'''

DEFAULT_CONTENT = {
    "index.md": '''---
title: "Welcome to My Site"
template: "default"
---

# Welcome!

This is your new static site built with Soma. Edit this file to customise your homepage.

## Getting Started

- Add blog posts in the `blog/` directory
- Add projects in the `projects/` directory
- Customise templates in the `templates/` directory
- Run `soma build` to generate your site
- Run `soma serve` to preview locally
''',

    "blog/index.md": '''---
title: "Blog"
template: "category"
---

Welcome to my blog! Here you'll find my latest thoughts and updates.
''',

    "projects/index.md": '''---
title: "Projects"
template: "category"
---

Welcome to my projects page! Here are some things I've been working on.
''',

    "blog/first-post.md": '''---
title: "My First Blog Post"
template: "content"
date: "2024-01-01"
---

# Hello World!

This is my first blog post. You can edit this file or create new `.md` files in the `blog/` directory.

## Features

- Write in **Markdown**
- Automatic template rendering
- Clean URL structure
''',

    "projects/cool-project.md": '''---
title: "My Cool Project"
template: "content"
date: "2024-01-01"
---

# My Cool Project

This is a description of one of my projects. Add more `.md` files in the `projects/` directory to showcase your work.

## What I Built

- Feature 1
- Feature 2
- Feature 3
'''
}
