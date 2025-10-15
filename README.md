# soma
Static sites without the noise

## About
Allows users to quickly spin up a Github Pages compatible static site with minimal fuss and configuration.

Note: This tool is not made for production. It was merely an instructional exercise to learn how static site generators work.

## Quickstart

Run the following commands to get started quickly.

```
# Navigate to a directory where you would like the site first
soma init --name mysite

# Then navigate to the directory and serve to preview the site
soma serve
```

## Usage & Features
Any folders added are recognised as categories, and content placed therin automatically processed as long as a few basic rules are followed.

1. The root dir of the project contains an index.md. This is your landing page. You are free to add additional pages such as about.md within this dir.

2. Category folders (placed within the root dir) contain an index.md which serve as the index page for the category and will collate all items for that category.

3. Each markdownfile contains a title, template and some content. Dates, tags and categories are optional.

### Example Folder Layout

Below is an example of what your layout may look like before building.

```
// UPDATE WITH STYLES AND FONT
```

## Coming soon (10 years later)..
- Better config settings (probably not going to happen)
- Commands `new category` & `new item`
- Support for themes
