# soma
Static sites without the noise

## About
Allows users to quickly spin up a Github Pages compatible static site with minimal fuss and configuration.

Note: This tool is not made for production. It was merely an instructional exercise for myself to learn how static site generators work and so I can maintain my own site with a greater level of control.

## Usage & Features
Any folders added are recognised as categories, and content placed therin automatically processed as long as a few basic rules are followed.

1. The root dir of the project contains an index.md. You are free to add additional pages such as about.md within this dir.

2. Category folders (placed within the root dir) contain an index.md which serve as the index page for the category and will collate all items for that category.

3. Each markdownfile contains a title, template and some content. Dates, tags and categories are optional.

## Features in progress
- Restructure content dir layout
- Implement dev serve & better file watching
- Add support for themes
