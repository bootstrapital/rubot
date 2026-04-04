# Sample App

This app is a deliberately small host Rails application that demonstrates the intended Rubot integration pattern.

It shows:

- normal app routes, controllers, and views in the host app
- a Rubot operation launched from an app controller
- operation, workflow, tool, and agent code living in app-owned directories
- the Rubot admin engine mounted separately at `/rubot/admin`

The demo capability is a resume screener:

- the controller gathers form input
- the operation owns the business entrypoint
- the workflow sequences tools and the screening agent
- the admin engine is used for run inspection, replay, approvals, and traces

This app is intentionally not a large reference product. Its job is to show the host-app-plus-mounted-admin shape clearly.

## Booting The Sample App

The sample app has its own Bundler and Rails boot boundary. Use the sample-app entrypoints rather than loading `sample_app/config/environment` through the repo root bundle.

From the repository root:

```bash
bin/setup --sample-app
ruby bin/sample_app server
```

Or from inside `sample_app/`:

```bash
bin/setup
bin/rails server
```

Why this matters:

- `sample_app/config/boot.rb` pins `BUNDLE_GEMFILE` to `sample_app/Gemfile`
- that keeps sample-app-only Rails framework choices isolated from the main Rubot gem path
- the main repo should not depend on the sample app's boot assumptions

Once the server is running, the host app is available at `/` and the mounted Rubot admin UI is available at `/rubot/admin`.
