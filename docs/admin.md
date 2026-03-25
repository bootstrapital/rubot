# Rubot Admin Mounting and Customization

This guide documents the intended Rails integration story for the Rubot admin engine.

The admin engine is currently a `provisional` API surface. See [`public_api.md`](./public_api.md) for the current contract boundary.

## What the Admin Engine Owns

Rubot ships a framework-owned admin surface for:

- dashboard summary
- runs index and run detail
- approvals inbox
- replay and trace inspection
- developer playground

The intended split is:

- your Rails app owns product-facing routes, controllers, auth, and feature UI
- Rubot owns the admin/governance surface mounted under a dedicated route

In practice that usually means:

- app UI under routes like `/`, `/ops/...`, or your product-specific paths
- Rubot admin under `/rubot/admin/...`

## Recommended Mount Path

Mount the engine in your host app routes:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount Rubot::Engine, at: "/rubot/admin"
end
```

That gives you engine-owned routes such as:

- `/rubot/admin`
- `/rubot/admin/dashboard`
- `/rubot/admin/runs`
- `/rubot/admin/runs/:id`
- `/rubot/admin/approvals`
- `/rubot/admin/playground`

The host app owns the outer mount path. The engine owns the routes inside that mount.

## Install Flow

For a Rails app using the built-in setup path:

```bash
bin/rails generate rubot:install
bin/rails db:migrate
```

The install generator now:

- mounts the engine at `/rubot/admin`
- writes `config/initializers/rubot.rb`
- creates the Active Record tables used by `Rubot::Stores::ActiveRecordStore`

The generated initializer defaults to durable Active Record persistence for Rails installs.

## Auth Hook

Rubot does not hardcode admin authentication.

Instead, configure `admin_authorizer` in your initializer:

```ruby
Rubot.configure do |config|
  config.admin_authorizer = proc do
    authenticate_admin!
  end
end
```

Rubot also supports an explicit controller argument:

```ruby
Rubot.configure do |config|
  config.admin_authorizer = ->(controller) do
    controller.authenticate_admin!
  end
end
```

Supported forms today:

- `-> { ... }` executed in the engine controller instance context
- `->(controller) { ... }` with the engine controller passed explicitly

This hook is the framework-owned integration point for admin auth.

## Runtime Authorization vs Admin Auth

Keep these distinct:

- `admin_authorizer` controls whether a request may enter the admin engine UI
- `policy_adapter` controls runtime and admin action authorization decisions inside Rubot

Example:

```ruby
Rubot.configure do |config|
  config.admin_authorizer = ->(controller) { controller.authenticate_admin! }
  config.policy_adapter = Rubot::Policy::PunditAdapter.new
  config.policy_actor_resolver = ->(context, controller) do
    context[:current_user] || controller&.current_user
  end
end
```

That split lets you reuse existing app auth while still enforcing Rubot action-level policy checks.

## What Host Apps May Customize Safely

Safe, supported host-app customization points today:

- outer mount path in `config/routes.rb`
- `admin_authorizer`
- `policy_adapter` and `policy_actor_resolver`
- store selection such as `Rubot::Stores::ActiveRecordStore`
- provider configuration
- subject memory configuration

Useful admin-facing data contracts:

- `Rubot::Presenters::RunPresenter#as_admin_json`
- `Rubot::Presenters::ApprovalPresenter#as_admin_json`
- `Rubot::Presenters::ToolCallPresenter#as_admin_json`

These presenter contracts are useful for frontend-driven extensions, but remain `provisional` during `v0.2`.

## What Rubot Owns

These areas should be treated as engine-owned:

- admin controllers
- admin routes inside the mounted engine
- shell layout and navigation structure
- built-in views and partials
- built-in admin CSS package
- live-update broadcasting behavior

You can override Rails engine views in a host app if you choose, but that is not yet a documented stable extension surface. Prefer configuration hooks and presenter contracts over partial overrides.

## Layout and Asset Expectations

Rubot packages its admin shell assets and views with the gem.

Framework-owned pieces include:

- layout: `rubot/application`
- stylesheet: `rubot/application.css`
- reusable views and partials under `app/views/rubot/...`

The admin UI assumes the host app can serve standard Rails engine assets. It does not require the host app to adopt Rubot’s layout outside the mounted engine.

## JSON and Frontend Expectations

The engine remains server-rendered Rails by default.

JSON endpoints exposed by the admin controllers are intended for richer frontend-driven clients later, not as a separate product UI contract for your normal app routes. Use them when you are extending the admin surface, not when building ordinary app-facing feature pages.

## Product UI vs Admin UI

The recommended model is:

- product-facing controllers and pages live in your app
- those entrypoints launch operations, workflows, or runs
- the Rubot admin engine is the inspection and governance surface

Put differently:

- your app answers “how does the user do the work?”
- Rubot admin answers “what happened, and how do operators inspect or govern it?”

## Current Status

Post-`029`, the admin engine is packaged as a framework-owned surface rather than an in-repo convenience:

- engine runtime files are shipped in the gem
- routes, views, helpers, assets, and controllers are packaged together
- the auth hook contract is explicit

That makes `/rubot/admin` the recommended adoption path for Rails teams today.
