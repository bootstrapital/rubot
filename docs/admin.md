# Rubot Admin Panel Frontend Architecture

## Decision

Rubot should use a hybrid frontend architecture.

- The built-in engine remains server-rendered Rails by default.
- Presenter-backed JSON endpoints provide a stable contract for richer frontend-driven pages later.
- Shared design tokens, shell layout, and reusable partials should serve both the engine UI and embedded app surfaces.

This avoids locking Rubot into a one-off engine UI while also avoiding a premature SPA rewrite.

## Why Hybrid

- Rails views already fit Rubot's realtime and operator-heavy workflows well.
- The current engine pages prove routing, presenters, approvals, and Turbo update paths.
- A dedicated frontend app would add build, auth, and state complexity before the UI model is mature enough.
- Stable JSON contracts let future React or other frontend layers reuse the same data model instead of scraping HTML.

## Foundation Pieces

- `rubot/application` layout provides the authenticated admin shell.
- `DashboardController`, `RunsController`, and `ApprovalsController` now support presenter-backed admin pages.
- `RunsController` and `ApprovalsController` also expose JSON contracts for frontend-driven clients.
- Shared tokens in `app/assets/stylesheets/rubot/application.css` define typography, spacing, status color, and motion defaults.
- Reusable UI primitives like stat cards and empty states establish a design baseline for later screens.

## Auth Model

The engine should not hardcode authentication.

Instead, host apps can configure:

```ruby
Rubot.configure do |config|
  config.admin_authorizer = proc do
    authenticate_admin!
  end
end
```

That keeps Rubot Rails-native while allowing integration with existing admin auth systems.

## Presenter Contract

The presenter contract is the backend boundary for admin pages.

- `RunPresenter#as_admin_json`
- `ApprovalPresenter#as_admin_json`
- `ToolCallPresenter#as_admin_json`

This contract should be treated as the canonical shape for future frontend work.

## Next Steps

- Add metrics and trace surfaces on top of the shell.
- Expand operation-aware screens and subject embedding.
- Layer richer frontend-driven pages on top of the same presenter contract where interaction complexity justifies it.
