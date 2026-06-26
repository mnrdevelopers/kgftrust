-- Supabase Schema for KGF Trust (Kalki Grit Force Trust)
-- This file creates all necessary tables, trigger functions, indexes, and Row Level Security (RLS) policies.

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. USERS (Profiles linked to auth.users)
create table public.users (
    id uuid references auth.users on delete cascade primary key,
    email text not null,
    full_name text,
    phone text,
    avatar_url text,
    role text not null default 'user' check (role in ('user', 'admin')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for users
alter table public.users enable row level security;

-- 2. MEMBERS (Membership applications and details)
create table public.members (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references public.users(id) on delete set null,
    member_id text unique, -- Unique ID (e.g. KGF-MEM-2026-1002)
    full_name text not null,
    email text not null,
    mobile text not null,
    address text not null,
    aadhaar text not null,
    membership_type text not null check (membership_type in ('Annual', 'Life', 'Honorary')),
    photo_url text, -- Path in Supabase Storage
    status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for members
alter table public.members enable row level security;

-- 3. VOLUNTEERS (Volunteer registrations)
create table public.volunteers (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references public.users(id) on delete set null,
    full_name text not null,
    email text not null,
    mobile text not null,
    address text not null,
    aadhaar text not null,
    occupation text,
    skills text,
    photo_url text, -- Path in Supabase Storage
    status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for volunteers
alter table public.volunteers enable row level security;

-- 4. DONATIONS (Donation records)
create table public.donations (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references public.users(id) on delete set null,
    donor_name text not null,
    donor_email text not null,
    donor_mobile text not null,
    donor_pan text, -- Optional PAN for 80G tax benefit
    amount numeric not null check (amount > 0),
    payment_id text unique not null, -- Razorpay Payment ID (e.g., pay_xxxxx)
    order_id text, -- Razorpay Order ID (e.g., order_xxxxx)
    status text not null default 'pending' check (status in ('pending', 'success', 'failed')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for donations
alter table public.donations enable row level security;

-- 5. EVENTS (Events organized by the Trust)
create table public.events (
    id uuid default gen_random_uuid() primary key,
    title text not null,
    description text not null,
    date date not null,
    time time not null,
    location text not null,
    image_url text, -- Path in Supabase Storage or external link
    capacity integer not null default 100,
    registrations_count integer not null default 0,
    status text not null default 'upcoming' check (status in ('upcoming', 'past', 'cancelled')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for events
alter table public.events enable row level security;

-- 6. EVENT REGISTRATIONS (Users registering for events)
create table public.event_registrations (
    id uuid default gen_random_uuid() primary key,
    event_id uuid references public.events(id) on delete cascade not null,
    user_id uuid references public.users(id) on delete set null,
    name text not null,
    email text not null,
    mobile text not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique (event_id, email) -- Prevent duplicate registrations for same event with same email
);

-- Enable RLS for event registrations
alter table public.event_registrations enable row level security;

-- 7. GALLERY (Images & Videos)
create table public.gallery (
    id uuid default gen_random_uuid() primary key,
    url text not null,
    type text not null default 'image' check (type in ('image', 'video')),
    category text not null default 'general', -- e.g. 'education', 'sports', 'health', 'food'
    caption text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for gallery
alter table public.gallery enable row level security;

-- 8. NEWS (Latest updates and blog posts)
create table public.news (
    id uuid default gen_random_uuid() primary key,
    title text not null,
    content text not null,
    image_url text,
    date date not null default current_date,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for news
alter table public.news enable row level security;

-- 9. CONTACT MESSAGES (Contact Us submissions)
create table public.contact_messages (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    email text not null,
    phone text not null,
    message text not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for contact messages
alter table public.contact_messages enable row level security;


-- ========================================================
-- DATABASE TRIGGERS & FUNCTIONS
-- ========================================================

-- Trigger to automatically create a profile in public.users on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'role', 'user')
  );
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Trigger to update updated_at timestamp on record updates
create or replace function public.handle_update_timestamp()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create or replace trigger update_users_timestamp
  before update on public.users
  for each row execute procedure public.handle_update_timestamp();

create or replace trigger update_members_timestamp
  before update on public.members
  for each row execute procedure public.handle_update_timestamp();

create or replace trigger update_volunteers_timestamp
  before update on public.volunteers
  for each row execute procedure public.handle_update_timestamp();

create or replace trigger update_events_timestamp
  before update on public.events
  for each row execute procedure public.handle_update_timestamp();

create or replace trigger update_news_timestamp
  before update on public.news
  for each row execute procedure public.handle_update_timestamp();

-- Trigger to update registrations_count when a new event registration is added
create or replace function public.increment_event_registration()
returns trigger as $$
begin
  update public.events
  set registrations_count = registrations_count + 1
  where id = new.event_id;
  return new;
end;
$$ language plpgsql;

create or replace trigger on_event_registration
  after insert on public.event_registrations
  for each row execute procedure public.increment_event_registration();


-- ========================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ========================================================

-- Helper function to check if user is admin
create or replace function public.is_admin()
returns boolean as $$
begin
  return exists (
    select 1 from public.users
    where id = auth.uid() and role = 'admin'
  );
end;
$$ language plpgsql security definer;

-- USERS POLICIES
create policy "Allow public read of profiles" on public.users for select using (true);
create policy "Allow users to update own profile" on public.users for update using (auth.uid() = id);
create policy "Allow admin write access to profiles" on public.users for all using (public.is_admin());

-- MEMBERS POLICIES
create policy "Allow users to read own membership" on public.members for select using (auth.uid() = user_id or public.is_admin());
create policy "Allow public/users to create membership" on public.members for insert with check (true);
create policy "Allow admin full access to memberships" on public.members for all using (public.is_admin());

-- VOLUNTEERS POLICIES
create policy "Allow users to read own volunteer application" on public.volunteers for select using (auth.uid() = user_id or public.is_admin());
create policy "Allow public/users to register as volunteer" on public.volunteers for insert with check (true);
create policy "Allow admin full access to volunteers" on public.volunteers for all using (public.is_admin());

-- DONATIONS POLICIES
create policy "Allow users to view own donations" on public.donations for select using (auth.uid() = user_id or public.is_admin());
create policy "Allow public/users to insert donations" on public.donations for insert with check (true);
create policy "Allow admin full access to donations" on public.donations for all using (public.is_admin());

-- EVENTS POLICIES
create policy "Allow public read of events" on public.events for select using (true);
create policy "Allow admin full access to events" on public.events for all using (public.is_admin());

-- EVENT REGISTRATIONS POLICIES
create policy "Allow users to view own registrations" on public.event_registrations for select using (auth.uid() = user_id or public.is_admin());
create policy "Allow public to register for events" on public.event_registrations for insert with check (true);
create policy "Allow admin full access to registrations" on public.event_registrations for all using (public.is_admin());

-- GALLERY POLICIES
create policy "Allow public read of gallery" on public.gallery for select using (true);
create policy "Allow admin full access to gallery" on public.gallery for all using (public.is_admin());

-- NEWS POLICIES
create policy "Allow public read of news" on public.news for select using (true);
create policy "Allow admin full access to news" on public.news for all using (public.is_admin());

-- CONTACT MESSAGES POLICIES
create policy "Allow public to submit contact messages" on public.contact_messages for insert with check (true);
create policy "Allow admin full access to contact messages" on public.contact_messages for all using (public.is_admin());


-- ========================================================
-- STORAGE BUCKETS SETUP (Instructions)
-- ========================================================
-- Note: Create the following public storage buckets in Supabase Storage console:
-- 1. "members" (For member photo uploads)
--    - RLS policy: Insert allowed for all. Select allowed for owner (auth.uid() = user_id) or admin.
-- 2. "volunteers" (For volunteer photo uploads)
--    - RLS policy: Insert allowed for all. Select allowed for owner (auth.uid() = user_id) or admin.
-- 3. "gallery" (For gallery media uploads)
--    - RLS policy: Select allowed for all. Insert/Update/Delete allowed for admins.
-- 4. "news" (For news thumbnails uploads)
--    - RLS policy: Select allowed for all. Insert/Update/Delete allowed for admins.
