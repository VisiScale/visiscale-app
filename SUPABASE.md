# Supabase — VisiScale app

Reference for the CRM backend. Read this before touching anything database-related.

---

## Rule 1: how to hand over SQL

**This one caused three failed attempts. Do not repeat it.**

When Jack needs to run SQL, put **the SQL itself** in a fenced code block, alone, with
nothing else inside the fence. He copies the whole block. Anything else in it goes to
Postgres and errors.

**Never put in the block:**
- A filename (`001_crm.sql`) — Postgres reads it as a broken numeric literal
- A shell command (`cd ...`, `cat ...`) — errors at `cd`
- A file path, a `$` prompt, or terminal output

**Never say "paste `supabase/001_crm.sql`".** That reads as "paste this text". Say
"copy the SQL below" and then show it.

**Do not print the SQL with `cat` in a tool call and expect him to copy from there.**
The command line renders above the output and gets copied with it. Write the SQL
directly into the reply instead.

Every line he pastes should start with `create`, `alter`, `drop`, `grant`, `insert`
or `select`. If it starts with anything else, it is not SQL.

Same applies to any other copy-paste handover: keys, config values, env vars. One
thing per block, nothing around it.

---

## Rule 2: every new table gets RLS and a policy in the same migration

Every client's data lives in the same tables, separated only by a `business_id`
column. Gavin's customers and Chase's customers are neighbouring rows. **RLS is
the only thing keeping them apart** — there is no separate database, schema or
connection per client.

So a table created without RLS is not "unfinished", it is **every client able to
read every other client's data**. And the failure is silent: the app works, the
data looks right to whoever is testing, and nobody notices until a client does.

**In the same migration that creates a table, always:**

```
alter table <name> enable row level security;
create policy ... using (business_id = auth_business_id());
grant select, insert, update, delete on <name> to authenticated;
```

Never "add the policy after". There is no after.

**Test it by logging in, not by reading the policy.** Sign in as one client, try
to read another's row, and confirm you get nothing back. A policy that looks
correct and a policy that is correct are different things, and the dashboard
cannot tell you which you have — the SQL editor runs as a superuser and bypasses
RLS entirely, so everything always looks fine from there.

---

## Rule 3: grants and RLS are two different locks

The project was created with **"automatically expose new tables" off**, which is
correct, and it means:

- **Grants** decide which *tables* the app can reach at all
- **RLS policies** decide which *rows* within them

Both have to be right. Getting only the policies right produces tables that exist,
have correct policies, and fail every query on permissions. Every new table needs a
matching `grant` line or the app cannot see it.

**"Enable automatic RLS" is on**, so new tables get RLS switched on automatically.
That is a safety net, not a substitute for writing policies: a table with RLS on and
no policies returns zero rows to everyone.

---

## Rule 4: keys

| Key | Safe in client code | Use |
|---|---|---|
| Project URL | Yes | `window.SUPABASE_URL` |
| `anon` / public | Yes | `window.SUPABASE_ANON_KEY` |
| `service_role` | **Never** | Server-side only, n8n at most |

The anon key is public by design; RLS is what protects the data. The service_role key
bypasses RLS entirely. In a static app it would be readable by anyone who opens dev
tools, exposing every client's customer list.

---

## Architecture

**One Supabase project holds every client.** Every row carries `business_id`, and RLS
scopes reads and writes to the caller's business. One project to migrate, back up and
maintain, rather than one per client.

**One deployed app, everyone logs in.** This replaced the old model of duplicating
`index.html` per client with hardcoded CONFIG. That model cannot work with a database:
with no login there is nothing for RLS to scope against.

### Tables

```
businesses    id, name, created_at
profiles      id (= auth user id), business_id, full_name
customers     id, business_id, name, phone, email, address, source, notes
```

`customers.source` is `'manual'` when typed in, and will be `'form'` when the website
integration lands. It exists now so that does not need a migration later.

Planned and additive, needing no change to the above: `jobs`, `time_entries`,
`expenses`, `estimates`.

### auth_business_id()

Returns the caller's `business_id`. It is `SECURITY DEFINER` because a policy on
`profiles` that queries `profiles` recurses and deadlocks. This is the standard
Supabase pattern and the first thing people trip on.

---

## Onboarding a client

1. **Authentication → Users → Add user.** Their email, a temporary password, tick
   **Auto Confirm User**.
2. Run the add-a-client SQL with three values changed: business name, person's name,
   and the login email. It matches the user by email, so no UUIDs get copied around.
3. The `select` at the end must return **one row**. Empty means the email in the
   script does not match the login exactly.

Make yourself a login first and test against it before any client sees the app.

---

## Settings chosen at project creation

Region and Postgres type **cannot be changed** after creation.

| Setting | Value |
|---|---|
| Region | East US (N. Virginia) |
| Postgres type | Postgres (default), not OrioleDB |
| Data API | Enabled |
| Automatically expose new tables | **Off** |
| Automatic RLS | **On** |
| AI schema sharing | **Schema Only** — never logs or data, since it holds clients' customer PII |

**Free tier projects pause after 7 days of inactivity.** Acceptable while building,
not once a client depends on it. Move to Pro before it goes in front of anyone.
