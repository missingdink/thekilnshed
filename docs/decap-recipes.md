# Decap CMS Recipes

Copy-paste collection snippets for `src/admin/config.yml`. Pair each with a corresponding Bridgetown collection definition in `config/initializers.rb` and a layout in `src/_layouts/`.

## Blog posts

```yaml
- name: posts
  label: "Blog Posts"
  folder: "src/_posts"
  create: true
  slug: "{{year}}-{{month}}-{{day}}-{{slug}}"
  fields:
    - { label: "Title", name: "title", widget: "string" }
    - { label: "Date", name: "date", widget: "datetime" }
    - { label: "Author", name: "author", widget: "string" }
    - { label: "Body", name: "body", widget: "markdown" }
```

Bridgetown collection:

```ruby
posts do
  output true
  permalink "/blog/:slug.*"
  sort_by "date"
  sort_direction "descending"
end
```

## Generic pages

```yaml
- name: pages
  label: "Pages"
  folder: "src/_pages"
  create: true
  slug: "{{slug}}"
  fields:
    - { label: "Title", name: "title", widget: "string" }
    - { label: "Permalink", name: "permalink", widget: "string" }
    - { label: "Body", name: "body", widget: "markdown" }
```

## Team / Staff

```yaml
- name: team
  label: "Team"
  folder: "src/_team"
  create: true
  slug: "{{slug}}"
  fields:
    - { label: "Name", name: "name", widget: "string" }
    - { label: "Role", name: "role", widget: "string" }
    - { label: "Photo", name: "photo", widget: "image" }
    - { label: "Bio", name: "bio", widget: "markdown" }
```

## FAQ

```yaml
- name: faq
  label: "FAQ"
  files:
    - file: "src/_data/faq.yml"
      label: "FAQ Entries"
      name: "faq"
      fields:
        - label: "Entries"
          name: "entries"
          widget: "list"
          fields:
            - { label: "Question", name: "q", widget: "string" }
            - { label: "Answer", name: "a", widget: "markdown" }
```

## Events

```yaml
- name: events
  label: "Events"
  folder: "src/_events"
  create: true
  slug: "{{date}}-{{slug}}"
  fields:
    - { label: "Title", name: "title", widget: "string" }
    - { label: "Date", name: "date", widget: "datetime" }
    - { label: "Venue", name: "venue", widget: "string" }
    - { label: "Body", name: "body", widget: "markdown" }
```

## Image gallery

```yaml
- name: gallery
  label: "Gallery"
  folder: "src/_gallery"
  create: true
  slug: "{{slug}}"
  fields:
    - { label: "Title", name: "title", widget: "string" }
    - label: "Images"
      name: "images"
      widget: "list"
      fields:
        - { label: "Caption", name: "caption", widget: "string" }
        - { label: "Image", name: "image", widget: "image" }
```

## Custom widget tips

Decap widgets are registered in `src/admin/index.html` via JS. Reference: <https://decapcms.org/docs/custom-widgets/>.
