# Plugin Composition System — Rails + Hotwire + Inertia + React

## Context

You are working on a Ruby on Rails application with Hotwire, Turbo and React via
Inertia.js. The application has a plugin system that extends Ruby models, ERB views,
React/JSX components and CSS files **without ever modifying the original files**.

The system has a unified DSL (`FilePatch`) that works for any file type. All layers
share a single execution mechanism: the `storage/build/` folder.

---

## The fundamental rule

> No file inside `app/` is ever written to. The `storage/build/` folder is gitignored,
> disposable, and can be fully recreated at any time with `rails plugins:rebuild`.

---

## How it works

On boot, `PluginLoader` loads the plugins and `BuildManager` syncs `storage/build/`.

For every file found in `plugins/*/app/**`, the `BuildManager` applies one rule:

```
plugins/<n>/app/<relative_path> exists
  AND app/<relative_path> also exists      →  patch — apply DSL over the original
  AND app/<relative_path> does NOT exist   →  new file — copy directly to storage/build/
```

There is no `patches/` folder. The file path inside the plugin is the signal —
if a matching original exists in `app/`, the file is a patch. If not, it is a new file.

Every layer (Rails, Vite) looks in `storage/build/` first. If the file does not exist
there, the original in `app/` is used as fallback.

```
storage/build/{target} exists?  →  yes → use storage/build/
                                →  no  → use app/ (original)
```

---

## Full folder structure

```
my_app/
├── app/                                               ← NEVER TOUCHED
│   ├── models/contact.rb
│   ├── views/users/show.html.erb
│   ├── javascript/pages/UserProfile.jsx
│   └── assets/stylesheets/app.css
│
├── storage/
│   └── build/                                         ← GENERATED ON BOOT (gitignored)
│       └── app/
│           ├── models/
│           │   ├── contact.rb                         ← original + patches applied
│           │   └── new_model.rb                       ← copied from plugins/example/app/models/
│           ├── views/users/
│           │   └── show.html.erb                      ← original + patches applied
│           ├── javascript/
│           │   ├── pages/UserProfile.jsx              ← original + patches applied
│           │   └── components/ExampleBadge.jsx        ← copied from plugins/example/app/javascript/
│           └── assets/stylesheets/
│               └── app.css                            ← original + patches applied
│
├── plugins/
│   └── <plugin_name>/
│       ├── plugin.rb                                  ← plugin manifest
│       ├── app/                                       ← all plugin files live here
│       │   ├── models/
│       │   │   ├── contact.rb                         ← PATCH: same path as app/models/contact.rb
│       │   │   ├── contact_extension.rb               ← NEW FILE: no match in app/
│       │   │   └── new_model.rb                       ← NEW FILE: no match in app/
│       │   ├── controllers/
│       │   │   └── example_controller.rb              ← NEW FILE
│       │   ├── views/
│       │   │   ├── users/
│       │   │   │   └── show.html.erb                  ← PATCH: same path as app/views/users/
│       │   │   └── example/
│       │   │       └── _badge.html.erb                ← NEW FILE
│       │   ├── javascript/
│       │   │   ├── pages/
│       │   │   │   └── UserProfile.jsx                ← PATCH: same path as app/javascript/pages/
│       │   │   └── components/
│       │   │       └── ExampleBadge.jsx               ← NEW FILE
│       │   └── assets/stylesheets/
│       │       └── app.css                            ← PATCH: same path as app/assets/stylesheets/
│       ├── config/
│       │   └── routes.rb                              ← plugin routes (optional)
│       ├── db/
│       │   └── migrate/                               ← plugin migrations (optional)
│       └── spec/                                      ← plugin tests
│           ├── models/
│           ├── requests/
│           ├── patches/
│           └── javascript/
│
├── docs/
│   └── plugins.md                                     ← plugin authoring documentation
│
└── lib/
    └── plugins/
        ├── file_patch.rb                              ← DSL + registry + engine
        ├── build_manager.rb                           ← detects patch vs new file, syncs storage/build/
        ├── plugin_loader.rb                           ← discovers and loads plugins
        └── adapters/
            ├── text_line.rb                           ← adapter for .rb, .erb, .css
            └── js_ast.rb                              ← adapter for .js, .jsx, .ts, .tsx
```

---

## How a patch file works

A patch file lives at the same relative path as the original inside `plugins/<n>/app/`.
Its content is the `FilePatch` DSL — not a class or module. It is loaded by
`BuildManager` via explicit `require`, never autoloaded by Zeitwerk.

```ruby
# plugins/example/app/models/contact.rb
# PATCH — because app/models/contact.rb exists.

Plugins::FilePatch.define target: "app/models/contact.rb" do
  after_line containing: "class Contact < ApplicationRecord" do
    "  include Plugins::Example::ContactExtension"
  end

  replace_line containing: "ROLES = %w[admin user]",
               with: "  ROLES = %w[admin user example_role]"
end
```

A new file lives at a path that has no match in `app/`. Its content is a normal Ruby
class, React component, ERB partial, or CSS file — copied as-is into `storage/build/`
and loaded normally by Rails or Vite.

```ruby
# plugins/example/app/models/contact_extension.rb
# NEW FILE — because app/models/contact_extension.rb does NOT exist.

module Plugins
  module Example
    module ContactExtension
      extend ActiveSupport::Concern

      included do
        has_many :example_records
      end

      def example_method
        "extended"
      end
    end
  end
end
```

---

## Patch DSL — full reference

The same DSL works for any file type. The engine picks the correct adapter from the
file extension.

```ruby
after_line  containing: "string"  do ... end   # insert after the matching line
before_line containing: "string"  do ... end   # insert before the matching line
replace_line containing: "string", with: "..." # replace the entire matching line
replace_block from: "start_marker",
              to:   "end_marker"  do ... end   # replace a block between two markers
append_to_file  do ... end                     # append to end of file
prepend_to_file do ... end                     # prepend to beginning of file
```

---

## Patch examples by file type

### Ruby model patch

**Original** (`app/models/contact.rb`):

```ruby
class Contact < ApplicationRecord
  include Devise::JWT

  ROLES = %w[admin user]

  belongs_to :account
  validates :email, presence: true

  def display_name
    "#{first_name} #{last_name}"
  end
end
```

**Patch** (`plugins/example/app/models/contact.rb`):

```ruby
Plugins::FilePatch.define target: "app/models/contact.rb" do
  after_line containing: "class Contact < ApplicationRecord" do
    "  include Plugins::Example::ContactExtension"
  end

  replace_line containing: "ROLES = %w[admin user]",
               with: "  ROLES = %w[admin user example_role]"
end
```

**Result in `storage/build/app/models/contact.rb`**:

```ruby
class Contact < ApplicationRecord
  include Plugins::Example::ContactExtension
  include Devise::JWT

  ROLES = %w[admin user example_role]

  belongs_to :account
  validates :email, presence: true

  def display_name
    "#{first_name} #{last_name}"
  end
end
```

---

### ERB view patch

**Original** (`app/views/users/show.html.erb`):

```erb
<div class="user-card">
  <h1 class="user-name"><%= @user.name %></h1>
  <%= render "shared/avatar" %>

  <%# plugin:example:start %>
  <%# plugin:example:end %>
</div>
```

**Patch** (`plugins/example/app/views/users/show.html.erb`):

```ruby
Plugins::FilePatch.define target: "app/views/users/show.html.erb" do
  after_line containing: '<h1 class="user-name">' do
    <<~ERB
      <% if @user.example_active? %>
        <%= render "example/badge", user: @user %>
      <% end %>
    ERB
  end

  replace_block from: "<%# plugin:example:start %>",
                to:   "<%# plugin:example:end %>" do
    <<~ERB
      <section class="example-panel">
        <%= render "example/full_panel", user: @user %>
      </section>
    ERB
  end
end
```

**Result in `storage/build/app/views/users/show.html.erb`**:

```erb
<div class="user-card">
  <h1 class="user-name"><%= @user.name %></h1>
  <% if @user.example_active? %>
    <%= render "example/badge", user: @user %>
  <% end %>
  <%= render "shared/avatar" %>

  <section class="example-panel">
    <%= render "example/full_panel", user: @user %>
  </section>
</div>
```

---

### JSX component patch

**Original** (`app/javascript/pages/UserProfile.jsx`):

```jsx
import React, { useState } from "react"
import Avatar from "@/components/Avatar"

export default function UserProfile({ user }) {
  const [tab, setTab] = useState("info")

  return (
    <div className="user-profile">
      <h1 className="user-name">{user.name}</h1>

      <div className="tabs">
        <button onClick={() => setTab("info")}>Info</button>
        {/* plugin:tabs */}
      </div>

      <div className="tab-content">
        {tab === "info" && <InfoTab user={user} />}
        {/* plugin:tab-content */}
      </div>
    </div>
  )
}
```

**Patch** (`plugins/example/app/javascript/pages/UserProfile.jsx`):

```ruby
Plugins::FilePatch.define target: "app/javascript/pages/UserProfile.jsx" do
  after_line containing: 'import Avatar from "@/components/Avatar"' do
    'import ExampleBadge from "@/components/ExampleBadge"'
  end

  after_line containing: "{/* plugin:tabs */}" do
    '        <button onClick={() => setTab("example")}>Example</button>'
  end

  after_line containing: "{/* plugin:tab-content */}" do
    '        {tab === "example" && <ExampleBadge userId={user.id} />}'
  end
end
```

**Result in `storage/build/app/javascript/pages/UserProfile.jsx`**:

```jsx
import React, { useState } from "react"
import Avatar from "@/components/Avatar"
import ExampleBadge from "@/components/ExampleBadge"

export default function UserProfile({ user }) {
  const [tab, setTab] = useState("info")

  return (
    <div className="user-profile">
      <h1 className="user-name">{user.name}</h1>

      <div className="tabs">
        <button onClick={() => setTab("info")}>Info</button>
        {/* plugin:tabs */}
        <button onClick={() => setTab("example")}>Example</button>
      </div>

      <div className="tab-content">
        {tab === "info" && <InfoTab user={user} />}
        {/* plugin:tab-content */}
        {tab === "example" && <ExampleBadge userId={user.id} />}
      </div>
    </div>
  )
}
```

---

### CSS patch

**Original** (`app/assets/stylesheets/app.css`):

```css
:root {
  --primary: #3b82f6;
  --danger:  #ef4444;
}

.user-card {
  padding: 1rem;
  background: white;
}
```

**Patch** (`plugins/example/app/assets/stylesheets/app.css`):

```ruby
Plugins::FilePatch.define target: "app/assets/stylesheets/app.css" do
  after_line containing: "--danger:  #ef4444;" do
    "  --example-color: #8b5cf6;"
  end

  append_to_file do
    <<~CSS

      /* ── example plugin ── */
      .example-badge {
        background: var(--example-color);
        border-radius: 9999px;
        padding: 0.25rem 0.5rem;
        font-size: 0.75rem;
        color: white;
      }
    CSS
  end
end
```

**Result in `storage/build/app/assets/stylesheets/app.css`**:

```css
:root {
  --primary: #3b82f6;
  --danger:  #ef4444;
  --example-color: #8b5cf6;
}

.user-card {
  padding: 1rem;
  background: white;
}

/* ── example plugin ── */
.example-badge {
  background: var(--example-color);
  border-radius: 9999px;
  padding: 0.25rem 0.5rem;
  font-size: 0.75rem;
  color: white;
}
```

---

### Two plugins patching the same file

Plugin `alpha` (priority 10) runs first. Plugin `beta` (priority 20) uses the line
inserted by `alpha` as its anchor — this only works because `beta` runs after `alpha`.

```ruby
# plugins/alpha/app/javascript/pages/UserProfile.jsx
Plugins::FilePatch.define target: "app/javascript/pages/UserProfile.jsx",
                           priority: 10 do
  after_line containing: 'import Avatar from "@/components/Avatar"' do
    'import AlphaBadge from "@/components/AlphaBadge"'
  end
end

# plugins/beta/app/javascript/pages/UserProfile.jsx
Plugins::FilePatch.define target: "app/javascript/pages/UserProfile.jsx",
                           priority: 20 do
  after_line containing: 'import AlphaBadge from "@/components/AlphaBadge"' do
    'import BetaBadge from "@/components/BetaBadge"'
  end
end
```

---

## Rake tasks

```bash
rails plugins:rebuild                                  # wipe and recreate storage/build/ from scratch
rails plugins:preview[app/models/contact.rb]           # print composed file after patches
rails plugins:preview[app/views/users/show.html.erb]
rails plugins:preview[app/javascript/pages/UserProfile.jsx]
rails plugins:preview[app/assets/stylesheets/app.css]
rails plugins:status                                   # list all files currently in storage/build/
```

---

## `.gitignore`

```
storage/build/
tmp/plugin_fingerprints/
```

---

## System invariants

1. **No file in `app/` is ever written to**
2. **`storage/build/` is fully disposable** — `rails plugins:rebuild` recreates it from scratch
3. **One mechanism for all file types** — write to `storage/build/`, every layer looks there first
4. **No `patches/` folder** — the file path is the signal: match in `app/` = patch, no match = new file
5. **Patch files are never autoloaded** — `BuildManager` loads them explicitly via `require`
6. **New plugin files are never modified** — copied as-is into `storage/build/`
7. **The `plugins/` folder is the only on/off switch** — remove it and `remove_orphans!` cleans `storage/build/` on next boot
8. **Incremental build** — only rebuilds files whose fingerprint (original + patches) has changed

---

---

# Tasks

## 1. Implement the plugin system infrastructure

Implement all infrastructure files. All code must be complete and production-ready —
no stubs, no placeholders, no TODO comments.

---

## 2. Write automated tests for the plugin system infrastructure

Write a complete test suite for the infrastructure under `spec/plugins/` (Ruby) and
`spec/javascript/` (JS). Tests must cover all components — `FilePatch`, the adapters,
`BuildManager`, and the Vite plugin. Use RSpec for Ruby and Vitest for JavaScript.
All tests must pass before the implementation is considered complete.

```bash
bundle exec rspec spec/plugins/
yarn vitest spec/javascript/
```

---

## 3. Create `docs/plugins.md` — plugin authoring documentation

Create the file `docs/plugins.md`. This is the authoritative reference for anyone
(human or AI) creating a new plugin. Write it in English and cover every topic below
with full working code examples.

### Required sections

#### Overview
What the plugin system does, what problems it solves, and the fundamental rule.

#### Folder structure
Complete folder layout of a plugin with every file and its purpose annotated.

#### Plugin manifest (`plugin.rb`)
Every field: `name`, `version`, `priority`. How priority controls patch order when
multiple plugins touch the same file.

#### The `storage/build/` folder
What it is, when it is generated, why it is gitignored, and how each layer (Rails,
Vite) uses it. The resolution rule: `storage/build/` first, `app/` as fallback.

#### New files vs patches — the path rule
There is no `patches/` folder. The file path is the signal:

- Same relative path as a file in `app/` → **patch** — file contains `FilePatch` DSL,
  loaded via `require`, result written to `storage/build/`
- No matching file in `app/` → **new file** — copied as-is to `storage/build/`, loaded
  normally by Rails or Vite

#### Patch DSL — complete reference
Every operation with purpose, syntax, and a before/after example: `after_line`,
`before_line`, `replace_line`, `replace_block`, `append_to_file`, `prepend_to_file`.

#### Extension markers
The convention for placing extension markers in base application files:

```erb
<%# plugin:example:start %>
<%# plugin:example:end %>
```

```jsx
{/* plugin:tabs */}
{/* plugin:tab-content */}
```

Why markers are more robust than `containing:` anchors for `replace_block`.

#### ActiveRecord macros in plugins
Why `has_many`, `belongs_to`, `validates`, `scope` must live in an
`ActiveSupport::Concern` as a **new file** (not a patch). Full Concern example and
how the patch file injects the `include`.

#### Multi-plugin patches and priority
How two plugins patch the same file, how priority controls order, and how a
lower-priority plugin's inserted lines can be used as anchors by the next one.

#### Routes
How to add routes from a plugin and how they are loaded automatically.

#### Testing requirements (AI instruction)

> **This section is a mandatory instruction for any AI generating plugin code.**
>
> Every plugin you create **must** ship with a complete test suite under
> `plugins/<plugin_name>/spec/`. Tests are not optional and must all pass before the
> plugin is considered complete.
>
> **Ruby** — use RSpec + FactoryBot. Cover every model, every Concern (tested on the
> host model), every controller (request specs), and every patch file (assert the
> composed output is correct AND that the original in `app/` was not modified).
>
> **JavaScript** — use Vitest + React Testing Library. Cover every React component.
>
> **Factories** — one FactoryBot factory per model defined by the plugin.
>
> Tests must be runnable in isolation:
> ```bash
> bundle exec rspec plugins/<plugin_name>/spec/
> yarn vitest plugins/<plugin_name>/spec/javascript/
> ```

#### Rake tasks reference
All available rake tasks with usage examples.

#### Checklist — creating a new plugin

```
[ ] Create plugins/<n>/plugin.rb with manifest
[ ] For each existing app/ file to extend:
    [ ] Create plugins/<n>/app/<same/relative/path> with FilePatch DSL
[ ] For each new file the plugin needs:
    [ ] Create plugins/<n>/app/<new/path> with normal content
[ ] Create plugins/<n>/spec/ with full test suite
[ ] Add migration if new tables are needed
[ ] Add routes if new endpoints are needed
[ ] Run rails plugins:rebuild — verify storage/build/ is generated correctly
[ ] Run rails plugins:preview[<target>] for each patched file — verify output
[ ] Run bundle exec rspec plugins/<n>/spec/ — all tests must pass
[ ] Run yarn vitest plugins/<n>/spec/javascript/ — all tests must pass
```

#### Removing a plugin
What happens when a plugin folder is deleted: `remove_orphans!` cleans `storage/build/`
on the next boot. No manual cleanup needed.

#### Troubleshooting

- `containing:` string not found — check for typos and leading/trailing whitespace
- Patch file accidentally autoloaded — it must mirror the original path exactly;
  `BuildManager` loads it via `require`, not Zeitwerk
- ActiveRecord macro in a patch file — move it to a Concern in a new file
- `storage/build/` out of sync — run `rails plugins:rebuild`
- Two plugins with the same priority on the same file — order is non-deterministic;
  assign distinct priority values