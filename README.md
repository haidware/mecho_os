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

The Source a Part form publishes mechanic requests and photos to the in-app
marketplace. Registered sellers sign in at `/spareparts`, view open requests,
and submit an offer with price, condition, and location. Mechanics can compare
the offers under My Part Requests, chat with each responding seller, and accept
one. Seller/mechanic chat updates live. Request images are stored in a private
Supabase Storage bucket and served through short-lived signed URLs.
The seller portal is available at
<https://mecho-os.onrender.com/spareparts>.

Before deploying this feature, run
[`supabase/spare_parts_marketplace.sql`](./supabase/spare_parts_marketplace.sql)
in the Supabase SQL Editor as an administrator. This configures the marketplace
tables, their row-level security policies, and the private image bucket. Render
does not run SQL scripts automatically.

Spare-part seller accounts are admin-provisioned; public seller signup is not
available. Create or invite the seller's Auth account through Supabase, then
use a trusted administrator session to give its profile the seller role and
active status. For example, after replacing the values with the invited
account's details:

```sql
INSERT INTO public.users (id, full_name, email, phone_number, role, status)
SELECT id, 'Seller Name', email, '08000000000', 'spare_part_seller', 'active'
FROM auth.users
WHERE email = 'seller@example.com'
ON CONFLICT (id) DO UPDATE
SET full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    phone_number = EXCLUDED.phone_number,
    role = EXCLUDED.role,
    status = EXCLUDED.status;
```

Run account provisioning only from the Supabase Dashboard or another trusted
server-side admin process. Never put a Supabase service-role key in the Flutter
app.
