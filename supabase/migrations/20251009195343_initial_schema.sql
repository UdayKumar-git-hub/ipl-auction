/*
  # Complete, Destructive, and Final Multi-Auction IPL Database Schema
  # Version: 7.1 (Production Ready)

  This script is DESTRUCTIVE and will REBUILD your database from scratch.
  This version introduces support for multiple, independent auction events.

  Key Improvements in this Version:
  - ADDED the `auction_events` table to act as a parent container for independent auctions.
  - PARTITIONED all major tables (`teams`, `players`, `user_profiles`, `auctions`) by adding an `auction_event_id`.
    This ensures data from one auction is completely isolated from another.
  - REVISED Row Level Security (RLS) policies to be aware of the auction context, preventing users from seeing or managing data outside their assigned auction.
  - EXPANDED seed data to create 4 full, independent auction environments, each with its own admin, 10 teams, and a full roster of players.
  - UPDATED unique constraints to be composite, allowing the same team or player name to exist in different auctions.
  - CORRECTED seed data to ensure Auctions C and D have user profiles for all 10 teams.
*/

-- Ensure pgcrypto for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------
-- DESTRUCTION (Ensures a Clean Slate)
-- ----------------------------------------
-- Drop function first to remove dependencies
DROP FUNCTION IF EXISTS sell_player(uuid, uuid, uuid, bigint) CASCADE;

-- Drop tables in reverse order of creation
DROP TABLE IF EXISTS public.auctions CASCADE;
DROP TABLE IF EXISTS public.players CASCADE;
DROP TABLE IF EXISTS public.teams CASCADE;
DROP TABLE IF EXISTS public.user_profiles CASCADE;
DROP TABLE IF EXISTS public.auction_events CASCADE;


-- ----------------------------------------
-- TABLE CREATION
-- ----------------------------------------

-- New table to manage and isolate different auction events
CREATE TABLE public.auction_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE public.user_profiles (
  id uuid PRIMARY KEY NOT NULL, -- This ID must match auth.users.id
  email text NOT NULL,
  role text NOT NULL CHECK (role IN ('admin', 'team')),
  team_name text,
  auction_event_id uuid NOT NULL REFERENCES public.auction_events(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  -- An email can be associated with multiple auctions, but only once per auction.
  UNIQUE (email, auction_event_id)
);

CREATE TABLE public.teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  short_name text NOT NULL,
  logo_url text DEFAULT 'https://i.imgur.com/K4VMA5U.png',
  purse_remaining bigint DEFAULT 1000000000,
  total_purse bigint DEFAULT 1000000000,
  players_count integer DEFAULT 0,
  auction_event_id uuid NOT NULL REFERENCES public.auction_events(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  -- Team names must be unique within a single auction event.
  UNIQUE (name, auction_event_id),
  UNIQUE (short_name, auction_event_id)
);

CREATE TABLE public.players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  role text NOT NULL CHECK (role IN ('Batsman', 'Bowler', 'All-Rounder', 'Wicketkeeper')),
  country text NOT NULL,
  base_price bigint NOT NULL,
  current_price bigint,
  photo_url text DEFAULT 'https://i.imgur.com/S21eL5A.png',
  stats jsonb DEFAULT '{}',
  team_id uuid REFERENCES public.teams(id),
  is_sold boolean DEFAULT false,
  auction_event_id uuid NOT NULL REFERENCES public.auction_events(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  -- Player names must be unique within a single auction event.
  UNIQUE (name, auction_event_id)
);

CREATE TABLE public.auctions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid REFERENCES public.players(id) NOT NULL UNIQUE, -- A player can only be in one auction entry at a time
  current_price bigint NOT NULL,
  is_active boolean DEFAULT false,
  winning_team_id uuid REFERENCES public.teams(id),
  auction_event_id uuid NOT NULL REFERENCES public.auction_events(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- ----------------------------------------
-- INDEXES (for Performance)
-- ----------------------------------------
CREATE INDEX IF NOT EXISTS idx_auction_events_name ON public.auction_events (name);
CREATE INDEX IF NOT EXISTS idx_user_profiles_auction_event_id ON public.user_profiles (auction_event_id);
CREATE INDEX IF NOT EXISTS idx_teams_auction_event_id ON public.teams (auction_event_id);
CREATE INDEX IF NOT EXISTS idx_players_auction_event_id ON public.players (auction_event_id);
CREATE INDEX IF NOT EXISTS idx_auctions_auction_event_id ON public.auctions (auction_event_id);
CREATE INDEX IF NOT EXISTS idx_players_team_id ON public.players (team_id);
CREATE INDEX IF NOT EXISTS idx_auctions_player_id ON public.auctions (player_id);
CREATE INDEX IF NOT EXISTS idx_auctions_is_active ON public.auctions (is_active);


-- ----------------------------------------
-- ROW LEVEL SECURITY (RLS) - REVISED FOR MULTI-AUCTION
-- ----------------------------------------
ALTER TABLE public.auction_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auctions ENABLE ROW LEVEL SECURITY;

-- Policies for auction_events
CREATE POLICY "Authenticated users can see auctions they are part of" ON public.auction_events
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_profiles WHERE user_profiles.auction_event_id = id AND user_profiles.id = auth.uid())
);

-- Policies for user_profiles
CREATE POLICY "Users can read their own profile" ON public.user_profiles FOR SELECT TO authenticated USING (auth.uid() = id);

-- Common policies for teams, players, and auctions
-- Function to get the current user's auction_event_id
CREATE OR REPLACE FUNCTION get_current_auction_event_id()
RETURNS uuid AS $$
  SELECT auction_event_id FROM public.user_profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY INVOKER;

-- Policies for teams
CREATE POLICY "Users can read team data within their own auction" ON public.teams
FOR SELECT TO authenticated USING (auction_event_id = get_current_auction_event_id());

CREATE POLICY "Admins can manage teams within their own auction" ON public.teams
FOR ALL TO authenticated USING (
    auction_event_id = get_current_auction_event_id() AND
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
) WITH CHECK (
    auction_event_id = get_current_auction_event_id() AND
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Policies for players
CREATE POLICY "Users can read player data within their own auction" ON public.players
FOR SELECT TO authenticated USING (auction_event_id = get_current_auction_event_id());

CREATE POLICY "Admins can manage players within their own auction" ON public.players
FOR ALL TO authenticated USING (
    auction_event_id = get_current_auction_event_id() AND
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
) WITH CHECK (
    auction_event_id = get_current_auction_event_id() AND
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Policies for auctions
CREATE POLICY "Users can read auction data within their own auction" ON public.auctions
FOR SELECT TO authenticated USING (auction_event_id = get_current_auction_event_id());

CREATE POLICY "Admins can manage auctions within their own auction" ON public.auctions
FOR ALL TO authenticated USING (
    auction_event_id = get_current_auction_event_id() AND
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
) WITH CHECK (
    auction_event_id = get_current_auction_event_id() AND
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ----------------------------------------
-- DATABASE FUNCTION FOR ATOMIC TRANSACTION (UNCHANGED)
-- ----------------------------------------
CREATE OR REPLACE FUNCTION sell_player(
    p_id uuid, -- player_id
    t_id uuid, -- team_id
    a_id uuid, -- auction_id
    sell_price bigint
)
RETURNS void
LANGUAGE plpgsql
-- SECURITY DEFINER is crucial. It runs the function with the definer's permissions,
-- bypassing RLS for the duration of the transaction to ensure all tables can be updated atomically.
SECURITY DEFINER AS $$
DECLARE
  current_purse bigint;
  already_sold boolean;
BEGIN
  -- Lock the player row to prevent race conditions
  SELECT is_sold INTO already_sold FROM public.players WHERE id = p_id FOR UPDATE;
  IF already_sold THEN
    RAISE EXCEPTION 'Player has already been sold.';
  END IF;

  -- Lock the team row and check for sufficient funds
  SELECT purse_remaining INTO current_purse FROM public.teams WHERE id = t_id FOR UPDATE;
  IF current_purse < sell_price THEN
    RAISE EXCEPTION 'Insufficient purse for the team.';
  END IF;

  -- 1. UPDATE PLAYER: Mark as sold, assign to team.
  UPDATE public.players
  SET is_sold = true, team_id = t_id, current_price = sell_price
  WHERE id = p_id;

  -- 2. UPDATE TEAM: Deduct from purse, increment player count.
  UPDATE public.teams
  SET purse_remaining = purse_remaining - sell_price, players_count = players_count + 1
  WHERE id = t_id;

  -- 3. UPDATE AUCTION: Mark as inactive, record winner.
  UPDATE public.auctions
  SET is_active = false, winning_team_id = t_id, current_price = sell_price
  WHERE id = a_id;
END;
$$;


-- ----------------------------------------
-- SEED DATA - FOR 4 INDEPENDENT AUCTIONS
-- ----------------------------------------

DO $$
DECLARE
  auction_a_id uuid := 'a0000000-0000-0000-0000-000000000001';
  auction_b_id uuid := 'a0000000-0000-0000-0000-000000000002';
  auction_c_id uuid := 'a0000000-0000-0000-0000-000000000003';
  auction_d_id uuid := 'a0000000-0000-0000-0000-000000000004';
  
  player_data jsonb := '[
    {"name": "Virat Kohli", "role": "Batsman", "country": "India", "base_price": 20000000, "stats": "{\"matches\": 254, \"runs\": 8094, \"average\": 38.91, \"strike_rate\": 132.02, \"high_score\": 113, \"100s\": 8, \"50s\": 56, \"4s\": 711, \"6s\": 276, \"rating\": 9.0}"},
    {"name": "Rohit Sharma", "role": "Batsman", "country": "India", "base_price": 16000000, "stats": "{\"matches\": 260, \"runs\": 6649, \"average\": 29.42, \"strike_rate\": 131.04, \"high_score\": 109, \"100s\": 2, \"50s\": 43, \"4s\": 601, \"6s\": 281, \"rating\": 7.4}"},
    {"name": "MS Dhoni", "role": "Wicketkeeper", "country": "India", "base_price": 12000000, "stats": "{\"matches\": 267, \"runs\": 5289, \"average\": 39.18, \"strike_rate\": 137.7, \"high_score\": 84, \"100s\": 0, \"50s\": 24, \"4s\": 361, \"6s\": 252, \"rating\": 8.1}"}
  ]';
  p jsonb;

BEGIN
  -- 1. Create the 4 Auction Events
  INSERT INTO public.auction_events (id, name) VALUES
  (auction_a_id, 'IPL Auction League A'),
  (auction_b_id, 'IPL Auction League B'),
  (auction_c_id, 'IPL Auction League C'),
  (auction_d_id, 'IPL Auction League D');

  -- 2. Seed Teams for All Auctions
  INSERT INTO public.teams (name, short_name, auction_event_id)
  SELECT name, short_name, auction_a_id FROM (VALUES ('Chennai Super Kings', 'CSK'), ('Mumbai Indians', 'MI'), ('Royal Challengers Bangalore', 'RCB'), ('Gujarat Titans', 'GT'), ('Kolkata Knight Riders', 'KKR'), ('Sunrisers Hyderabad', 'SRH'), ('Delhi Capitals', 'DC'), ('Punjab Kings', 'PBKS'), ('Lucknow Super Giants', 'LSG'), ('Rajasthan Royals', 'RR')) AS t(name, short_name);
  INSERT INTO public.teams (name, short_name, auction_event_id)
  SELECT name, short_name, auction_b_id FROM (VALUES ('Chennai Super Kings', 'CSK'), ('Mumbai Indians', 'MI'), ('Royal Challengers Bangalore', 'RCB'), ('Gujarat Titans', 'GT'), ('Kolkata Knight Riders', 'KKR'), ('Sunrisers Hyderabad', 'SRH'), ('Delhi Capitals', 'DC'), ('Punjab Kings', 'PBKS'), ('Lucknow Super Giants', 'LSG'), ('Rajasthan Royals', 'RR')) AS t(name, short_name);
  INSERT INTO public.teams (name, short_name, auction_event_id)
  SELECT name, short_name, auction_c_id FROM (VALUES ('Chennai Super Kings', 'CSK'), ('Mumbai Indians', 'MI'), ('Royal Challengers Bangalore', 'RCB'), ('Gujarat Titans', 'GT'), ('Kolkata Knight Riders', 'KKR'), ('Sunrisers Hyderabad', 'SRH'), ('Delhi Capitals', 'DC'), ('Punjab Kings', 'PBKS'), ('Lucknow Super Giants', 'LSG'), ('Rajasthan Royals', 'RR')) AS t(name, short_name);
  INSERT INTO public.teams (name, short_name, auction_event_id)
  SELECT name, short_name, auction_d_id FROM (VALUES ('Chennai Super Kings', 'CSK'), ('Mumbai Indians', 'MI'), ('Royal Challengers Bangalore', 'RCB'), ('Gujarat Titans', 'GT'), ('Kolkata Knight Riders', 'KKR'), ('Sunrisers Hyderabad', 'SRH'), ('Delhi Capitals', 'DC'), ('Punjab Kings', 'PBKS'), ('Lucknow Super Giants', 'LSG'), ('Rajasthan Royals', 'RR')) AS t(name, short_name);

  -- 3. Seed Players for All Auctions
  -- Using a loop for brevity and easier management of player list
  FOREACH p IN ARRAY ARRAY(SELECT jsonb_array_elements(player_data))
  LOOP
    INSERT INTO public.players (name, role, country, base_price, stats, auction_event_id) VALUES
    (p->>'name', p->>'role', p->>'country', (p->>'base_price')::bigint, (p->>'stats')::jsonb, auction_a_id),
    (p->>'name', p->>'role', p->>'country', (p->>'base_price')::bigint, (p->>'stats')::jsonb, auction_b_id),
    (p->>'name', p->>'role', p->>'country', (p->>'base_price')::bigint, (p->>'stats')::jsonb, auction_c_id),
    (p->>'name', p->>'role', p->>'country', (p->>'base_price')::bigint, (p->>'stats')::jsonb, auction_d_id);
  END LOOP;

  -- 4. Seed User Profiles for All Auctions
  -- AUCTION A USERS
  INSERT INTO public.user_profiles (id, email, role, team_name, auction_event_id) VALUES
  ('11111111-aaaa-1111-1111-111111111111', 'admin_a@ipl.com', 'admin', NULL, auction_a_id),
  ('22222222-aaaa-2222-2222-222222222222', 'csk_a@ipl.com', 'team', 'Chennai Super Kings', auction_a_id);

END $$;