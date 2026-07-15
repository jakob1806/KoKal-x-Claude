-- Nutzerprofile & Personalisierung, siehe docs/02-database-schema.md §10
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  home_location geography(Point, 4326),
  onboarding_completed boolean default false,
  created_at timestamptz default now()
);

create table favorites (
  user_id uuid references profiles(id) on delete cascade,
  event_id uuid references events(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, event_id)
);

create table favorite_lists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  name text not null,
  created_at timestamptz default now()
);

create table favorite_list_items (
  list_id uuid references favorite_lists(id) on delete cascade,
  event_id uuid references events(id) on delete cascade,
  added_at timestamptz default now(),
  primary key (list_id, event_id)
);

create table user_favorite_persons (
  user_id uuid references profiles(id) on delete cascade,
  person_id uuid references persons(id) on delete cascade,
  primary key (user_id, person_id)
);
create table user_favorite_ensembles (
  user_id uuid references profiles(id) on delete cascade,
  ensemble_id uuid references ensembles(id) on delete cascade,
  primary key (user_id, ensemble_id)
);
create table user_favorite_venues (
  user_id uuid references profiles(id) on delete cascade,
  venue_id uuid references venues(id) on delete cascade,
  primary key (user_id, venue_id)
);

create table notification_preferences (
  user_id uuid primary key references profiles(id) on delete cascade,
  new_matching_events boolean default true,
  price_changes boolean default true,
  almost_sold_out boolean default true,
  reminder_day_before boolean default true,
  followed_ensemble_new_event boolean default true
);

create table push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  token text not null unique,
  platform text not null,
  created_at timestamptz default now()
);

create table search_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  query text not null,
  created_at timestamptz default now()
);

create table event_views (
  id bigint generated always as identity primary key,
  user_id uuid references profiles(id),
  event_id uuid references events(id),
  viewed_at timestamptz default now()
);
create index idx_event_views_user on event_views(user_id);
create index idx_event_views_event on event_views(event_id);
