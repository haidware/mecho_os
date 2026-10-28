# mecho_os

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Build for the web

Build the production web app with:

```sh
flutter build web --release
```

The static site is generated in `build/web`.

## Deploy to Render

Render can use the Blueprint in `render.yaml` to build and publish the Flutter
web app as a static site. In Render, create a new Blueprint from this repository
and select the `mecho-os-web` static site. The Blueprint pins Flutter 3.35.1 and
rewrites app routes to `index.html` so Flutter navigation works on refresh.

The existing Supabase initialization and app flow are unchanged.

## Restrict Supabase table access

The Supabase SQL script at `supabase/workshop_row_level_security.sql` enables
Row Level Security on public tables that do not already have it and applies
workshop-scoped policies where a table has a `workshop_id`, `user_id`,
`owner_id`, or a foreign key to a workshop-scoped table. Tables without a
recognized ownership path are denied client access until an explicit policy is
added.

Review and run the script in the Supabase Dashboard SQL Editor. Existing
tables that already have Row Level Security enabled are left unchanged.
The SQL script reports each changed table; tables reported as having no client
access policy need an explicit ownership rule before the app can use them.
Render deployments do not execute this database script automatically.
The script also secures the `active_job_balance` and `active_job_balances`,
`customer_financial_summary`, `workshop_daily_accounting`, and
`workshop_revenue_breakdown` views using caller permissions and allows access
only to authenticated users, subject to the underlying tables' RLS policies.
Supabase Storage access is configured separately and is not changed by this
script.

## Spare-parts marketplace

The Source a Part form is available to any active registered account, with or
without a workshop link. It publishes requests and photos to the in-app
marketplace. Registered sellers sign in at `/spareparts`, view open requests,
and submit an offer with price, condition, and location. Mechanics can compare
the offers under My Part Requests, chat with each responding seller, and accept
one. Seller/mechanic chat updates live. Request images are stored in a private
Supabase Storage bucket and served through short-lived signed URLs.
The request automatically includes the mechanic's saved name, phone number,
and workshop address from Supabase instead of asking for them again.
The seller portal is available at
<https://mecho-os.onrender.com/spareparts>.

Before deploying this feature, run
[`supabase/spare_parts_marketplace.sql`](./supabase/spare_parts_marketplace.sql)
in the Supabase SQL Editor as an administrator. This configures the marketplace
tables, their row-level security policies, and the private image bucket. Render
does not run SQL scripts automatically.
If an existing deployment reports SQLSTATE `42501` when publishing a request,
run [`supabase/fix_spare_parts_request_insert_rls.sql`](./supabase/fix_spare_parts_request_insert_rls.sql)
in the Supabase SQL Editor, then retry. It allows active accounts without a
workshop link to publish, and repairs request, image, and marketplace access
authorization without deleting marketplace data. Request visibility is checked
from the row itself so the app can retrieve a newly created draft under RLS.

Spare-part seller sign-up requires a one-time numeric ID issued by an admin at
<https://mecho-os.onrender.com/admin>. Sellers create their account at
`/spareparts/signup` with that ID; on success, the app opens seller login with
their email and password filled in.

Run [`supabase/spare_parts_seller_signup.sql`](./supabase/spare_parts_seller_signup.sql)
in the Supabase SQL Editor as an administrator after the marketplace SQL. This
creates a private one-time-ID table and RPC functions. The Render Blueprint
also adds the `mecho-os-seller-admin-api` Node service. Set these environment
variables on that service in Render:

- `ADMIN_USERNAME` and `ADMIN_PASSWORD`: the single admin login for `/admin`.
- `ADMIN_TOKEN_SECRET`: a randomly generated secret used to sign short-lived
  admin sessions.
- `SELLER_ID_HASH_SECRET`: a separate randomly generated secret used to hash
  issued IDs; keep it stable so existing unused IDs remain valid.
- `SUPABASE_SERVICE_ROLE_KEY`: the Supabase project service-role key. Keep it
  only in the backend service's Render environment; never put it in Flutter or
  the static-site build variables.

The Blueprint sets the API origin and the public app origin. Admin credentials
are checked only by the backend, and seller IDs are stored as hashes and can be
redeemed once. `ADMIN_TOKEN_SECRET` and `SELLER_ID_HASH_SECRET` can have
different lengths; the service does not enforce a minimum length. Keep them
private and distinct. Render may require these secret environment variables to
be entered before the backend service becomes healthy.
