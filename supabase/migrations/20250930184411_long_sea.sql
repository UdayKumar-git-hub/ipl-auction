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
DROP POLICY IF EXISTS "Authenticated users can see auctions they are part of" ON public.auction_events;
CREATE POLICY "Authenticated users can see auctions they are part of" ON public.auction_events
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_profiles WHERE user_profiles.auction_event_id = id AND user_profiles.id = auth.uid())
);

-- Policies for user_profiles
DROP POLICY IF EXISTS "Users can read their own profile" ON public.user_profiles;
CREATE POLICY "Users can read their own profile" ON public.user_profiles FOR SELECT TO authenticated USING (auth.uid() = id);

-- Common policies for teams, players, and auctions
-- Function to get the current user's auction_event_id
CREATE OR REPLACE FUNCTION get_current_auction_event_id()
RETURNS uuid AS $$
  SELECT auction_event_id FROM public.user_profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY INVOKER;

-- Policies for teams
DROP POLICY IF EXISTS "Users can read team data within their own auction" ON public.teams;
CREATE POLICY "Users can read team data within their own auction" ON public.teams
FOR SELECT TO authenticated USING (auction_event_id = get_current_auction_event_id());

DROP POLICY IF EXISTS "Admins can manage teams within their own auction" ON public.teams;
CREATE POLICY "Admins can manage teams within their own auction" ON public.teams
FOR ALL TO authenticated USING (
    auction_event_id = get_current_auction_event_id() AND
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
) WITH CHECK (
    auction_event_id = get_current_auction_event_id() AND
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Policies for players
DROP POLICY IF EXISTS "Users can read player data within their own auction" ON public.players;
CREATE POLICY "Users can read player data within their own auction" ON public.players
FOR SELECT TO authenticated USING (auction_event_id = get_current_auction_event_id());

DROP POLICY IF EXISTS "Admins can manage players within their own auction" ON public.players;
CREATE POLICY "Admins can manage players within their own auction" ON public.players
FOR ALL TO authenticated USING (
    auction_event_id = get_current_auction_event_id() AND
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
) WITH CHECK (
    auction_event_id = get_current_auction_event_id() AND
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Policies for auctions
DROP POLICY IF EXISTS "Users can read auction data within their own auction" ON public.auctions;
CREATE POLICY "Users can read auction data within their own auction" ON public.auctions
FOR SELECT TO authenticated USING (auction_event_id = get_current_auction_event_id());

DROP POLICY IF EXISTS "Admins can manage auctions within their own auction" ON public.auctions;
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
    {"name": "MS Dhoni", "role": "Wicketkeeper", "country": "India", "base_price": 12000000, "stats": "{\"matches\": 267, \"runs\": 5289, \"average\": 39.18, \"strike_rate\": 137.7, \"high_score\": 84, \"100s\": 0, \"50s\": 24, \"4s\": 361, \"6s\": 252, \"rating\": 8.1}"},
    {"name": "Shikhar Dhawan", "role": "Batsman", "country": "India", "base_price": 8250000, "stats": "{\"matches\": 222, \"runs\": 6769, \"average\": 35.26, \"strike_rate\": 127.13, \"high_score\": 106, \"100s\": 2, \"50s\": 51, \"4s\": 768, \"6s\": 152, \"rating\": 8.3}"},
    {"name": "David Warner", "role": "Batsman", "country": "Australia", "base_price": 6250000, "stats": "{\"matches\": 184, \"runs\": 6565, \"average\": 41.55, \"strike_rate\": 139.73, \"high_score\": 109, \"100s\": 4, \"50s\": 62, \"4s\": 663, \"6s\": 236, \"rating\": 8.8}"},
    {"name": "Suresh Raina", "role": "Batsman", "country": "India", "base_price": 10000000, "stats": "{\"matches\": 205, \"runs\": 5528, \"average\": 32.52, \"strike_rate\": 136.76, \"high_score\": 100, \"100s\": 1, \"50s\": 39, \"4s\": 506, \"6s\": 203, \"rating\": 7.8}"},
    {"name": "Gautam Gambhir", "role": "Batsman", "country": "India", "base_price": 9000000, "stats": "{\"matches\": 154, \"runs\": 4217, \"average\": 31.01, \"strike_rate\": 123.88, \"high_score\": 93, \"100s\": 0, \"50s\": 36, \"4s\": 491, \"6s\": 59, \"rating\": 7.5}"},
    {"name": "Chris Gayle", "role": "Batsman", "country": "West Indies", "base_price": 10000000, "stats": "{\"matches\": 142, \"runs\": 4965, \"average\": 39.72, \"strike_rate\": 148.96, \"high_score\": 175, \"100s\": 6, \"50s\": 31, \"4s\": 404, \"6s\": 357, \"rating\": 8.5}"},
    {"name": "Robin Uthappa", "role": "Batsman", "country": "India", "base_price": 5000000, "stats": "{\"matches\": 205, \"runs\": 4952, \"average\": 27.51, \"strike_rate\": 130.35, \"high_score\": 88, \"100s\": 0, \"50s\": 27, \"4s\": 481, \"6s\": 182, \"rating\": 6.9}"},
    {"name": "Ajinkya Rahane", "role": "Batsman", "country": "India", "base_price": 4000000, "stats": "{\"matches\": 172, \"runs\": 4400, \"average\": 30.77, \"strike_rate\": 123.33, \"high_score\": 105, \"100s\": 2, \"50s\": 30, \"4s\": 431, \"6s\": 83, \"rating\": 6.8}"},
    {"name": "Dinesh Karthik", "role": "Wicketkeeper", "country": "India", "base_price": 7500000, "stats": "{\"matches\": 257, \"runs\": 4842, \"average\": 26.32, \"strike_rate\": 135.75, \"high_score\": 97, \"100s\": 0, \"50s\": 22, \"4s\": 441, \"6s\": 155, \"rating\": 7.1}"},
    {"name": "Faf du Plessis", "role": "Batsman", "country": "South Africa", "base_price": 6000000, "stats": "{\"matches\": 145, \"runs\": 4133, \"average\": 36.9, \"strike_rate\": 134.19, \"high_score\": 96, \"100s\": 0, \"50s\": 33, \"4s\": 371, \"6s\": 145, \"rating\": 8.2}"},
    {"name": "Shubman Gill", "role": "Batsman", "country": "India", "base_price": 8000000, "stats": "{\"matches\": 103, \"runs\": 3216, \"average\": 38.29, \"strike_rate\": 141.05, \"high_score\": 129, \"100s\": 4, \"50s\": 20, \"4s\": 314, \"6s\": 80, \"rating\": 8.4}"},
    {"name": "Mayank Agarwal", "role": "Batsman", "country": "India", "base_price": 3000000, "stats": "{\"matches\": 123, \"runs\": 2597, \"average\": 22.58, \"strike_rate\": 134.46, \"high_score\": 106, \"100s\": 1, \"50s\": 13, \"4s\": 265, \"6s\": 98, \"rating\": 6.2}"},
    {"name": "Nitish Rana", "role": "Batsman", "country": "India", "base_price": 3500000, "stats": "{\"matches\": 115, \"runs\": 2594, \"average\": 28.51, \"strike_rate\": 135.39, \"high_score\": 87, \"100s\": 0, \"50s\": 18, \"4s\": 204, \"6s\": 135, \"rating\": 6.7}"},
    {"name": "Wriddhiman Saha", "role": "Wicketkeeper", "country": "India", "base_price": 2000000, "stats": "{\"matches\": 173, \"runs\": 2798, \"average\": 24.54, \"strike_rate\": 128.69, \"high_score\": 115, \"100s\": 1, \"50s\": 13, \"4s\": 298, \"6s\": 84, \"rating\": 6.3}"},
    {"name": "Rahul Tripathi", "role": "Batsman", "country": "India", "base_price": 4000000, "stats": "{\"matches\": 100, \"runs\": 2071, \"average\": 26.55, \"strike_rate\": 139.72, \"high_score\": 93, \"100s\": 0, \"50s\": 11, \"4s\": 213, \"6s\": 77, \"rating\": 6.5}"},
    {"name": "Ishan Kishan", "role": "Wicketkeeper", "country": "India", "base_price": 15250000, "stats": "{\"matches\": 101, \"runs\": 2324, \"average\": 29.42, \"strike_rate\": 134.18, \"high_score\": 99, \"100s\": 0, \"50s\": 15, \"4s\": 218, \"6s\": 103, \"rating\": 7.3}"},
    {"name": "Devdutt Padikkal", "role": "Batsman", "country": "India", "base_price": 7750000, "stats": "{\"matches\": 57, \"runs\": 1521, \"average\": 27.65, \"strike_rate\": 125.39, \"high_score\": 101, \"100s\": 1, \"50s\": 9, \"4s\": 164, \"6s\": 41, \"rating\": 6.4}"},
    {"name": "Prithvi Shaw", "role": "Batsman", "country": "India", "base_price": 7500000, "stats": "{\"matches\": 71, \"runs\": 1694, \"average\": 23.86, \"strike_rate\": 146.5, \"high_score\": 99, \"100s\": 0, \"50s\": 13, \"4s\": 211, \"6s\": 58, \"rating\": 6.6}"},
    {"name": "David Miller", "role": "Batsman", "country": "South Africa", "base_price": 3000000, "stats": "{\"matches\": 133, \"runs\": 2714, \"average\": 36.19, \"strike_rate\": 138.86, \"high_score\": 101, \"100s\": 1, \"50s\": 13, \"4s\": 182, \"6s\": 126, \"rating\": 7.6}"},
    {"name": "Jos Buttler", "role": "Wicketkeeper", "country": "England", "base_price": 10000000, "stats": "{\"matches\": 106, \"runs\": 3223, \"average\": 37.92, \"strike_rate\": 148.32, \"high_score\": 124, \"100s\": 5, \"50s\": 19, \"4s\": 319, \"6s\": 149, \"rating\": 8.6}"},
    {"name": "Quinton de Kock", "role": "Wicketkeeper", "country": "South Africa", "base_price": 6750000, "stats": "{\"matches\": 107, \"runs\": 2907, \"average\": 31.6, \"strike_rate\": 134.02, \"high_score\": 140, \"100s\": 2, \"50s\": 20, \"4s\": 296, \"6s\": 107, \"rating\": 7.9}"},
    {"name": "Jonny Bairstow", "role": "Wicketkeeper", "country": "England", "base_price": 6750000, "stats": "{\"matches\": 39, \"runs\": 1291, \"average\": 35.86, \"strike_rate\": 142.65, \"high_score\": 114, \"100s\": 1, \"50s\": 9, \"4s\": 132, \"6s\": 54, \"rating\": 7.8}"},
    {"name": "Nicholas Pooran", "role": "Wicketkeeper", "country": "West Indies", "base_price": 16000000, "stats": "{\"matches\": 72, \"runs\": 1270, \"average\": 26.46, \"strike_rate\": 156.0, \"high_score\": 77, \"100s\": 0, \"50s\": 5, \"4s\": 79, \"6s\": 90, \"rating\": 7.2}"},
    {"name": "Ambati Rayudu", "role": "Batsman", "country": "India", "base_price": 6750000, "stats": "{\"matches\": 204, \"runs\": 4348, \"average\": 28.23, \"strike_rate\": 127.54, \"high_score\": 100, \"100s\": 1, \"50s\": 22, \"4s\": 361, \"6s\": 171, \"rating\": 6.7}"},
    {"name": "Manish Pandey", "role": "Batsman", "country": "India", "base_price": 4600000, "stats": "{\"matches\": 171, \"runs\": 3808, \"average\": 29.07, \"strike_rate\": 120.97, \"high_score\": 114, \"100s\": 1, \"50s\": 22, \"4s\": 320, \"6s\": 106, \"rating\": 6.5}"},
    {"name": "Shimron Hetmyer", "role": "Batsman", "country": "West Indies", "base_price": 8500000, "stats": "{\"matches\": 70, \"runs\": 1139, \"average\": 30.78, \"strike_rate\": 153.92, \"high_score\": 75, \"100s\": 0, \"50s\": 4, \"4s\": 71, \"6s\": 76, \"rating\": 7.0}"},
    {"name": "Abhinav Manohar", "role": "Batsman", "country": "India", "base_price": 2600000, "stats": "{\"matches\": 17, \"runs\": 222, \"average\": 18.5, \"strike_rate\": 136.2, \"high_score\": 42, \"100s\": 0, \"50s\": 0, \"4s\": 15, \"6s\": 13, \"rating\": 4.1}"},
    {"name": "Shahrukh Khan", "role": "Batsman", "country": "India", "base_price": 9000000, "stats": "{\"matches\": 43, \"runs\": 426, \"average\": 20.29, \"strike_rate\": 134.81, \"high_score\": 47, \"100s\": 0, \"50s\": 0, \"4s\": 27, \"6s\": 28, \"rating\": 4.9}"},
    {"name": "Priyam Garg", "role": "Batsman", "country": "India", "base_price": 2000000, "stats": "{\"matches\": 23, \"runs\": 251, \"average\": 15.69, \"strike_rate\": 115.67, \"high_score\": 51, \"100s\": 0, \"50s\": 1, \"4s\": 21, \"6s\": 8, \"rating\": 3.0}"},
    {"name": "Rinku Singh", "role": "Batsman", "country": "India", "base_price": 5500000, "stats": "{\"matches\": 41, \"runs\": 725, \"average\": 36.25, \"strike_rate\": 142.16, \"high_score\": 67, \"100s\": 0, \"50s\": 4, \"4s\": 50, \"6s\": 40, \"rating\": 7.0}"},
    {"name": "Tilak Varma", "role": "Batsman", "country": "India", "base_price": 17000000, "stats": "{\"matches\": 37, \"runs\": 740, \"average\": 38.95, \"strike_rate\": 144.53, \"high_score\": 84, \"100s\": 0, \"50s\": 3, \"4s\": 51, \"6s\": 45, \"rating\": 7.3}"},
    {"name": "Yashasvi Jaiswal", "role": "Batsman", "country": "India", "base_price": 4000000, "stats": "{\"matches\": 37, \"runs\": 1172, \"average\": 32.56, \"strike_rate\": 148.73, \"high_score\": 124, \"100s\": 1, \"50s\": 8, \"4s\": 149, \"6s\": 48, \"rating\": 8.1}"},
    {"name": "Ayush Badoni", "role": "Batsman", "country": "India", "base_price": 2000000, "stats": "{\"matches\": 44, \"runs\": 644, \"average\": 21.47, \"strike_rate\": 130.1, \"high_score\": 59, \"100s\": 0, \"50s\": 2, \"4s\": 41, \"6s\": 31, \"rating\": 3.7}"},
    {"name": "Mahipal Lomror", "role": "Batsman", "country": "India", "base_price": 9500000, "stats": "{\"matches\": 43, \"runs\": 549, \"average\": 18.3, \"strike_rate\": 135.22, \"high_score\": 54, \"100s\": 0, \"50s\": 1, \"4s\": 34, \"6s\": 32, \"rating\": 4.0}"},
    {"name": "Jitesh Sharma", "role": "Wicketkeeper", "country": "India", "base_price": 2000000, "stats": "{\"matches\": 42, \"runs\": 742, \"average\": 22.48, \"strike_rate\": 151.74, \"high_score\": 49, \"100s\": 0, \"50s\": 0, \"4s\": 54, \"6s\": 46, \"rating\": 3.2}"},
    {"name": "Tim David", "role": "Batsman", "country": "Australia", "base_price": 8250000, "stats": "{\"matches\": 40, \"runs\": 681, \"average\": 29.61, \"strike_rate\": 172.41, \"high_score\": 46, \"100s\": 0, \"50s\": 0, \"4s\": 39, \"6s\": 49, \"rating\": 3.7}"},
    {"name": "Evin Lewis", "role": "Batsman", "country": "West Indies", "base_price": 2000000, "stats": "{\"matches\": 27, \"runs\": 654, \"average\": 27.25, \"strike_rate\": 137.11, \"high_score\": 65, \"100s\": 0, \"50s\": 4, \"4s\": 62, \"6s\": 36, \"rating\": 6.5}"},
    {"name": "KL Rahul", "role": "Wicketkeeper", "country": "India", "base_price": 17000000, "stats": "{\"matches\": 132, \"runs\": 4683, \"average\": 47.83, \"strike_rate\": 134.62, \"high_score\": 132, \"100s\": 4, \"50s\": 37, \"4s\": 355, \"6s\": 164, \"rating\": 8.5}"},
    {"name": "Sanju Samson", "role": "Wicketkeeper", "country": "India", "base_price": 14000000, "stats": "{\"matches\": 166, \"runs\": 4273, \"average\": 29.88, \"strike_rate\": 137.94, \"high_score\": 119, \"100s\": 3, \"50s\": 24, \"4s\": 310, \"6s\": 196, \"rating\": 8.0}"},
    {"name": "Rishabh Pant", "role": "Wicketkeeper", "country": "India", "base_price": 16000000, "stats": "{\"matches\": 112, \"runs\": 3284, \"average\": 35.31, \"strike_rate\": 148.64, \"high_score\": 128, \"100s\": 1, \"50s\": 18, \"4s\": 286, \"6s\": 140, \"rating\": 7.9}"},
    {"name": "Suryakumar Yadav", "role": "Batsman", "country": "India", "base_price": 8000000, "stats": "{\"matches\": 153, \"runs\": 3600, \"average\": 31.86, \"strike_rate\": 146.52, \"high_score\": 103, \"100s\": 2, \"50s\": 24, \"4s\": 361, \"6s\": 126, \"rating\": 7.8}"},
    {"name": "Shreyas Iyer", "role": "Batsman", "country": "India", "base_price": 12250000, "stats": "{\"matches\": 116, \"runs\": 3073, \"average\": 31.04, \"strike_rate\": 126.83, \"high_score\": 96, \"100s\": 0, \"50s\": 21, \"4s\": 266, \"6s\": 94, \"rating\": 7.4}"},
    {"name": "Prabhsimran Singh", "role": "Wicketkeeper", "country": "India", "base_price": 600000, "stats": "{\"matches\": 20, \"runs\": 334, \"average\": 17.58, \"strike_rate\": 136.89, \"high_score\": 103, \"100s\": 1, \"50s\": 1, \"4s\": 35, \"6s\": 17, \"rating\": 4.5}"},
    {"name": "Sai Sudharsan", "role": "Batsman", "country": "India", "base_price": 200000, "stats": "{\"matches\": 21, \"runs\": 757, \"average\": 39.84, \"strike_rate\": 134.46, \"high_score\": 96, \"100s\": 0, \"50s\": 5, \"4s\": 71, \"6s\": 22, \"rating\": 7.0}"},
    {"name": "Ruturaj Gaikwad", "role": "Batsman", "country": "India", "base_price": 6000000, "stats": "{\"matches\": 63, \"runs\": 2307, \"average\": 41.2, \"strike_rate\": 136.21, \"high_score\": 101, \"100s\": 1, \"50s\": 18, \"4s\": 208, \"6s\": 85, \"rating\": 8.3}"},
    {"name": "Devon Conway", "role": "Wicketkeeper", "country": "New Zealand", "base_price": 1000000, "stats": "{\"matches\": 23, \"runs\": 924, \"average\": 48.63, \"strike_rate\": 141.28, \"high_score\": 92, \"100s\": 0, \"50s\": 9, \"4s\": 99, \"6s\": 32, \"rating\": 8.1}"},
    {"name": "Heinrich Klaasen", "role": "Wicketkeeper", "country": "South Africa", "base_price": 5250000, "stats": "{\"matches\": 31, \"runs\": 776, \"average\": 43.11, \"strike_rate\": 174.38, \"high_score\": 104, \"100s\": 1, \"50s\": 4, \"4s\": 44, \"6s\": 55, \"rating\": 7.7}"},
    {"name": "Harry Brook", "role": "Batsman", "country": "England", "base_price": 13250000, "stats": "{\"matches\": 23, \"runs\": 372, \"average\": 21.88, \"strike_rate\": 135.27, \"high_score\": 100, \"100s\": 1, \"50s\": 0, \"4s\": 40, \"6s\": 12, \"rating\": 5.5}"},
    {"name": "Aiden Markram", "role": "Batsman", "country": "South Africa", "base_price": 2600000, "stats": "{\"matches\": 50, \"runs\": 1133, \"average\": 31.47, \"strike_rate\": 133.14, \"high_score\": 58, \"100s\": 0, \"50s\": 5, \"4s\": 86, \"6s\": 45, \"rating\": 6.9}"},
    {"name": "Rovman Powell", "role": "Batsman", "country": "West Indies", "base_price": 2800000, "stats": "{\"matches\": 29, \"runs\": 329, \"average\": 18.28, \"strike_rate\": 146.22, \"high_score\": 67, \"100s\": 0, \"50s\": 1, \"4s\": 14, \"6s\": 26, \"rating\": 4.8}"},
    {"name": "Jason Roy", "role": "Batsman", "country": "England", "base_price": 2800000, "stats": "{\"matches\": 21, \"runs\": 614, \"average\": 32.32, \"strike_rate\": 143.46, \"high_score\": 91, \"100s\": 0, \"50s\": 5, \"4s\": 78, \"6s\": 24, \"rating\": 6.7}"},
    {"name": "Rahmanullah Gurbaz", "role": "Wicketkeeper", "country": "Afghanistan", "base_price": 500000, "stats": "{\"matches\": 11, \"runs\": 227, \"average\": 20.64, \"strike_rate\": 133.53, \"high_score\": 81, \"100s\": 0, \"50s\": 2, \"4s\": 15, \"6s\": 15, \"rating\": 5.2}"},
    {"name": "Yuzvendra Chahal", "role": "Bowler", "country": "India", "base_price": 6500000, "stats": "{\"matches\": 161, \"wickets\": 205, \"average\": 22.61, \"economy\": 7.86, \"strike_rate\": 17.26, \"4w\": 6, \"5w\": 1, \"rating\": 8.7}"},
    {"name": "Bhuvneshwar Kumar", "role": "Bowler", "country": "India", "base_price": 4200000, "stats": "{\"matches\": 177, \"wickets\": 182, \"average\": 27.19, \"economy\": 7.56, \"strike_rate\": 21.58, \"4w\": 2, \"5w\": 2, \"rating\": 7.5}"},
    {"name": "Jasprit Bumrah", "role": "Bowler", "country": "India", "base_price": 12000000, "stats": "{\"matches\": 133, \"wickets\": 165, \"average\": 22.51, \"economy\": 7.3, \"strike_rate\": 18.5, \"4w\": 2, \"5w\": 1, \"rating\": 8.9}"},
    {"name": "Umesh Yadav", "role": "Bowler", "country": "India", "base_price": 2000000, "stats": "{\"matches\": 148, \"wickets\": 144, \"average\": 30.13, \"economy\": 8.68, \"strike_rate\": 20.83, \"4w\": 3, \"5w\": 0, \"rating\": 6.8}"},
    {"name": "Mohammed Shami", "role": "Bowler", "country": "India", "base_price": 6250000, "stats": "{\"matches\": 122, \"wickets\": 136, \"average\": 26.85, \"economy\": 8.45, \"strike_rate\": 19.06, \"4w\": 2, \"5w\": 0, \"rating\": 8.0}"},
    {"name": "Kagiso Rabada", "role": "Bowler", "country": "South Africa", "base_price": 9250000, "stats": "{\"matches\": 78, \"wickets\": 115, \"average\": 18.91, \"economy\": 8.35, \"strike_rate\": 13.58, \"4w\": 6, \"5w\": 0, \"rating\": 8.8}"},
    {"name": "Trent Boult", "role": "Bowler", "country": "New Zealand", "base_price": 8000000, "stats": "{\"matches\": 99, \"wickets\": 114, \"average\": 25.83, \"economy\": 8.27, \"strike_rate\": 18.74, \"4w\": 1, \"5w\": 0, \"rating\": 8.2}"},
    {"name": "Mohit Sharma", "role": "Bowler", "country": "India", "base_price": 5000000, "stats": "{\"matches\": 110, \"wickets\": 119, \"average\": 22.95, \"economy\": 8.41, \"strike_rate\": 16.37, \"4w\": 2, \"5w\": 1, \"rating\": 7.8}"},
    {"name": "Harshal Patel", "role": "Bowler", "country": "India", "base_price": 10750000, "stats": "{\"matches\": 102, \"wickets\": 114, \"average\": 24.16, \"economy\": 8.6, \"strike_rate\": 16.86, \"4w\": 2, \"5w\": 1, \"rating\": 7.7}"},
    {"name": "Avesh Khan", "role": "Bowler", "country": "India", "base_price": 10000000, "stats": "{\"matches\": 58, \"wickets\": 58, \"average\": 26.33, \"economy\": 8.64, \"strike_rate\": 18.28, \"4w\": 1, \"5w\": 0, \"rating\": 6.5}"},
    {"name": "Arshdeep Singh", "role": "Bowler", "country": "India", "base_price": 4000000, "stats": "{\"matches\": 61, \"wickets\": 64, \"average\": 27.53, \"economy\": 8.74, \"strike_rate\": 18.89, \"4w\": 1, \"5w\": 1, \"rating\": 7.0}"},
    {"name": "Prasidh Krishna", "role": "Bowler", "country": "India", "base_price": 10000000, "stats": "{\"matches\": 51, \"wickets\": 49, \"average\": 34.9, \"economy\": 8.92, \"strike_rate\": 23.47, \"4w\": 1, \"5w\": 0, \"rating\": 5.9}"},
    {"name": "Mukesh Kumar", "role": "Bowler", "country": "India", "base_price": 5500000, "stats": "{\"matches\": 20, \"wickets\": 17, \"average\": 32.76, \"economy\": 9.72, \"strike_rate\": 20.24, \"4w\": 0, \"5w\": 0, \"rating\": 5.2}"},
    {"name": "Tushar Deshpande", "role": "Bowler", "country": "India", "base_price": 2000000, "stats": "{\"matches\": 29, \"wickets\": 25, \"average\": 32.68, \"economy\": 10.13, \"strike_rate\": 19.36, \"4w\": 0, \"5w\": 0, \"rating\": 4.8}"},
    {"name": "Deepak Chahar", "role": "Bowler", "country": "India", "base_price": 14000000, "stats": "{\"matches\": 83, \"wickets\": 74, \"average\": 28.97, \"economy\": 7.96, \"strike_rate\": 21.84, \"4w\": 2, \"5w\": 0, \"rating\": 7.1}"},
    {"name": "Varun Chakravarthy", "role": "Bowler", "country": "India", "base_price": 8000000, "stats": "{\"matches\": 70, \"wickets\": 66, \"average\": 26.65, \"economy\": 7.53, \"strike_rate\": 21.24, \"4w\": 1, \"5w\": 1, \"rating\": 7.3}"},
    {"name": "Kuldeep Yadav", "role": "Bowler", "country": "India", "base_price": 2000000, "stats": "{\"matches\": 85, \"wickets\": 75, \"average\": 28.53, \"economy\": 8.37, \"strike_rate\": 20.45, \"4w\": 2, \"5w\": 0, \"rating\": 7.2}"},
    {"name": "Ravi Bishnoi", "role": "Bowler", "country": "India", "base_price": 4000000, "stats": "{\"matches\": 62, \"wickets\": 58, \"average\": 28.1, \"economy\": 7.82, \"strike_rate\": 21.55, \"4w\": 1, \"5w\": 0, \"rating\": 6.9}"},
    {"name": "Mayank Markande", "role": "Bowler", "country": "India", "base_price": 5000000, "stats": "{\"matches\": 36, \"wickets\": 33, \"average\": 25.42, \"economy\": 8.16, \"strike_rate\": 18.67, \"4w\": 1, \"5w\": 0, \"rating\": 6.8}"},
    {"name": "Noor Ahmad", "role": "Bowler", "country": "Afghanistan", "base_price": 3000000, "stats": "{\"matches\": 23, \"wickets\": 22, \"average\": 25.09, \"economy\": 7.57, \"strike_rate\": 19.86, \"4w\": 0, \"5w\": 0, \"rating\": 6.7}"},
    {"name": "Matheesha Pathirana", "role": "Bowler", "country": "Sri Lanka", "base_price": 2000000, "stats": "{\"matches\": 18, \"wickets\": 21, \"average\": 19.33, \"economy\": 7.73, \"strike_rate\": 15.0, \"4w\": 0, \"5w\": 0, \"rating\": 7.6}"},
    {"name": "Anrich Nortje", "role": "Bowler", "country": "South Africa", "base_price": 6500000, "stats": "{\"matches\": 43, \"wickets\": 53, \"average\": 24.57, \"economy\": 8.32, \"strike_rate\": 17.72, \"4w\": 0, \"5w\": 0, \"rating\": 7.9}"},
    {"name": "Jofra Archer", "role": "Bowler", "country": "England", "base_price": 8000000, "stats": "{\"matches\": 40, \"wickets\": 48, \"average\": 21.33, \"economy\": 7.13, \"strike_rate\": 17.92, \"4w\": 0, \"5w\": 0, \"rating\": 8.4}"},
    {"name": "Lockie Ferguson", "role": "Bowler", "country": "New Zealand", "base_price": 10000000, "stats": "{\"matches\": 38, \"wickets\": 37, \"average\": 34.03, \"economy\": 8.96, \"strike_rate\": 22.78, \"4w\": 1, \"5w\": 0, \"rating\": 6.2}"},
    {"name": "Josh Hazlewood", "role": "Bowler", "country": "Australia", "base_price": 7750000, "stats": "{\"matches\": 27, \"wickets\": 35, \"average\": 22.2, \"economy\": 8.06, \"strike_rate\": 16.51, \"4w\": 1, \"5w\": 0, \"rating\": 8.0}"},
    {"name": "Mark Wood", "role": "Bowler", "country": "England", "base_price": 7500000, "stats": "{\"matches\": 7, \"wickets\": 11, \"average\": 23.0, \"economy\": 10.38, \"strike_rate\": 13.27, \"4w\": 0, \"5w\": 1, \"rating\": 7.0}"},
    {"name": "Alzarri Joseph", "role": "Bowler", "country": "West Indies", "base_price": 2400000, "stats": "{\"matches\": 19, \"wickets\": 20, \"average\": 29.85, \"economy\": 9.19, \"strike_rate\": 19.5, \"4w\": 0, \"5w\": 1, \"rating\": 6.4}"},
    {"name": "Jason Behrendorff", "role": "Bowler", "country": "Australia", "base_price": 750000, "stats": "{\"matches\": 12, \"wickets\": 14, \"average\": 27.64, \"economy\": 8.7, \"strike_rate\": 19.07, \"4w\": 0, \"5w\": 0, \"rating\": 6.3}"},
    {"name": "Fazalhaq Farooqi", "role": "Bowler", "country": "Afghanistan", "base_price": 500000, "stats": "{\"matches\": 7, \"wickets\": 6, \"average\": 38.83, \"economy\": 9.14, \"strike_rate\": 25.5, \"4w\": 1, \"5w\": 0, \"rating\": 5.4}"},
    {"name": "Adam Zampa", "role": "Bowler", "country": "Australia", "base_price": 1500000, "stats": "{\"matches\": 20, \"wickets\": 21, \"average\": 20.9, \"economy\": 7.7, \"strike_rate\": 16.29, \"4w\": 0, \"5w\": 0, \"rating\": 7.5}"},
    {"name": "Shardul Thakur", "role": "Bowler", "country": "India", "base_price": 10750000, "stats": "{\"matches\": 92, \"wickets\": 92, \"average\": 30.65, \"economy\": 9.16, \"strike_rate\": 20.08, \"4w\": 1, \"5w\": 0, \"rating\": 6.3}"},
    {"name": "Nathan Ellis", "role": "Bowler", "country": "Australia", "base_price": 2000000, "stats": "{\"matches\": 12, \"wickets\": 13, \"average\": 26.0, \"economy\": 8.76, \"strike_rate\": 17.85, \"4w\": 1, \"5w\": 0, \"rating\": 6.4}"},
    {"name": "Mustafizur Rahman", "role": "Bowler", "country": "Bangladesh", "base_price": 2000000, "stats": "{\"matches\": 48, \"wickets\": 47, \"average\": 30.7, \"economy\": 7.93, \"strike_rate\": 23.23, \"4w\": 1, \"5w\": 0, \"rating\": 6.8}"},
    {"name": "Umran Malik", "role": "Bowler", "country": "India", "base_price": 4000000, "stats": "{\"matches\": 25, \"wickets\": 29, \"average\": 29.31, \"economy\": 9.32, \"strike_rate\": 18.86, \"4w\": 1, \"5w\": 1, \"rating\": 6.6}"},
    {"name": "Khaleel Ahmed", "role": "Bowler", "country": "India", "base_price": 5250000, "stats": "{\"matches\": 44, \"wickets\": 57, \"average\": 24.79, \"economy\": 8.44, \"strike_rate\": 17.61, \"4w\": 0, \"5w\": 0, \"rating\": 7.4}"},
    {"name": "Chetan Sakariya", "role": "Bowler", "country": "India", "base_price": 4200000, "stats": "{\"matches\": 20, \"wickets\": 20, \"average\": 29.95, \"economy\": 8.44, \"strike_rate\": 21.3, \"4w\": 0, \"5w\": 0, \"rating\": 3.9}"},
    {"name": "Marco Jansen", "role": "Bowler", "country": "South Africa", "base_price": 4200000, "stats": "{\"matches\": 21, \"wickets\": 22, \"average\": 36.14, \"economy\": 9.61, \"strike_rate\": 22.57, \"4w\": 0, \"5w\": 0, \"rating\": 3.4}"},
    {"name": "Mujeeb Ur Rahman", "role": "Bowler", "country": "Afghanistan", "base_price": 2000000, "stats": "{\"matches\": 20, \"wickets\": 20, \"average\": 31.0, \"economy\": 8.34, \"strike_rate\": 22.3, \"4w\": 0, \"5w\": 0, \"rating\": 3.8}"},
    {"name": "Riley Meredith", "role": "Bowler", "country": "Australia", "base_price": 1000000, "stats": "{\"matches\": 19, \"wickets\": 18, \"average\": 33.33, \"economy\": 9.71, \"strike_rate\": 20.6, \"4w\": 0, \"5w\": 0, \"rating\": 3.1}"},
    {"name": "Jaydev Unadkat", "role": "Bowler", "country": "India", "base_price": 500000, "stats": "{\"matches\": 94, \"wickets\": 91, \"average\": 30.63, \"economy\": 8.8, \"strike_rate\": 20.88, \"4w\": 0, \"5w\": 2, \"rating\": 6.2}"},
    {"name": "Sandeep Sharma", "role": "Bowler", "country": "India", "base_price": 500000, "stats": "{\"matches\": 122, \"wickets\": 132, \"average\": 27.23, \"economy\": 7.86, \"strike_rate\": 20.78, \"4w\": 2, \"5w\": 1, \"rating\": 7.4}"},
    {"name": "Jayant Yadav", "role": "Bowler", "country": "India", "base_price": 1700000, "stats": "{\"matches\": 20, \"wickets\": 8, \"average\": 54.75, \"economy\": 7.1, \"strike_rate\": 46.25, \"4w\": 0, \"5w\": 0, \"rating\": 2.5}"},
    {"name": "Venkatesh Iyer", "role": "All-Rounder", "country": "India", "base_price": 8000000, "stats": "{\"matches\": 50, \"runs\": 956, \"average\": 23.32, \"strike_rate\": 131.14, \"high_score\": 104, \"100s\": 1, \"50s\": 7, \"4s\": 84, \"6s\": 41, \"rating\": 6.0}"},
    {"name": "Ravichandran Ashwin", "role": "All-Rounder", "country": "India", "base_price": 5000000, "stats": "{\"matches\": 212, \"runs\": 745, \"wickets\": 180, \"batting_rating\": 3, \"bowling_rating\": 7, \"overall_rating\": 5.0}"},
    {"name": "Sunil Narine", "role": "All-Rounder", "country": "West Indies", "base_price": 6000000, "stats": "{\"matches\": 177, \"runs\": 1046, \"wickets\": 180, \"batting_rating\": 5, \"bowling_rating\": 9, \"overall_rating\": 7.0}"},
    {"name": "Ravindra Jadeja", "role": "All-Rounder", "country": "India", "base_price": 16000000, "stats": "{\"matches\": 240, \"runs\": 2942, \"wickets\": 159, \"batting_rating\": 5, \"bowling_rating\": 7, \"overall_rating\": 6.0}"},
    {"name": "Rashid Khan", "role": "All-Rounder", "country": "Afghanistan", "base_price": 15000000, "stats": "{\"matches\": 120, \"runs\": 443, \"wickets\": 148, \"batting_rating\": 3, \"bowling_rating\": 7, \"overall_rating\": 5.0}"},
    {"name": "Axar Patel", "role": "All-Rounder", "country": "India", "base_price": 9000000, "stats": "{\"matches\": 147, \"runs\": 1499, \"wickets\": 117, \"batting_rating\": 4, \"bowling_rating\": 6, \"overall_rating\": 5.0}"},
    {"name": "Andre Russell", "role": "All-Rounder", "country": "West Indies", "base_price": 12000000, "stats": "{\"matches\": 122, \"runs\": 2471, \"wickets\": 106, \"batting_rating\": 6, \"bowling_rating\": 7, \"overall_rating\": 6.5}"},
    {"name": "Krunal Pandya", "role": "All-Rounder", "country": "India", "base_price": 8250000, "stats": "{\"matches\": 124, \"runs\": 1544, \"wickets\": 72, \"batting_rating\": 4, \"bowling_rating\": 5, \"overall_rating\": 4.5}"},
    {"name": "Hardik Pandya", "role": "All-Rounder", "country": "India", "base_price": 15000000, "stats": "{\"matches\": 133, \"runs\": 2465, \"wickets\": 60, \"batting_rating\": 5, \"bowling_rating\": 5, \"overall_rating\": 5.0}"},
    {"name": "Sam Curran", "role": "All-Rounder", "country": "England", "base_price": 18500000, "stats": "{\"matches\": 61, \"runs\": 895, \"wickets\": 58, \"batting_rating\": 4, \"bowling_rating\": 5, \"overall_rating\": 4.5}"},
    {"name": "Marcus Stoinis", "role": "All-Rounder", "country": "Australia", "base_price": 9200000, "stats": "{\"matches\": 90, \"runs\": 1478, \"wickets\": 40, \"batting_rating\": 5, \"bowling_rating\": 5, \"overall_rating\": 5.0}"},
    {"name": "Glenn Maxwell", "role": "All-Rounder", "country": "Australia", "base_price": 11000000, "stats": "{\"matches\": 133, \"runs\": 2719, \"wickets\": 34, \"batting_rating\": 5, \"bowling_rating\": 4, \"overall_rating\": 4.5}"},
    {"name": "Mitchell Marsh", "role": "All-Rounder", "country": "Australia", "base_price": 6500000, "stats": "{\"matches\": 42, \"runs\": 822, \"wickets\": 36, \"batting_rating\": 4, \"bowling_rating\": 6, \"overall_rating\": 5.0}"},
    {"name": "Moeen Ali", "role": "All-Rounder", "country": "England", "base_price": 8000000, "stats": "{\"matches\": 59, \"runs\": 1034, \"wickets\": 33, \"batting_rating\": 4, \"bowling_rating\": 5, \"overall_rating\": 4.5}"},
    {"name": "Rahul Tewatia", "role": "All-Rounder", "country": "India", "base_price": 9000000, "stats": "{\"matches\": 97, \"runs\": 1019, \"wickets\": 32, \"batting_rating\": 4, \"bowling_rating\": 4, \"overall_rating\": 4.0}"},
    {"name": "Ben Stokes", "role": "All-Rounder", "country": "England", "base_price": 16250000, "stats": "{\"matches\": 45, \"runs\": 935, \"wickets\": 28, \"batting_rating\": 4, \"bowling_rating\": 4, \"overall_rating\": 4.0}"},
    {"name": "Shahbaz Ahmed", "role": "All-Rounder", "country": "India", "base_price": 2400000, "stats": "{\"matches\": 39, \"runs\": 329, \"wickets\": 14, \"batting_rating\": 3, \"bowling_rating\": 4, \"overall_rating\": 3.5}"},
    {"name": "Cameron Green", "role": "All-Rounder", "country": "Australia", "base_price": 17500000, "stats": "{\"matches\": 24, \"runs\": 501, \"wickets\": 11, \"batting_rating\": 5, \"bowling_rating\": 4, \"overall_rating\": 4.5}"},
    {"name": "Abhishek Sharma", "role": "All-Rounder", "country": "India", "base_price": 6500000, "stats": "{\"matches\": 61, \"runs\": 893, \"wickets\": 11, \"batting_rating\": 4, \"bowling_rating\": 4, \"overall_rating\": 4.0}"},
    {"name": "Deepak Hooda", "role": "All-Rounder", "country": "India", "base_price": 5750000, "stats": "{\"matches\": 116, \"runs\": 1399, \"wickets\": 10, \"batting_rating\": 4, \"bowling_rating\": 3, \"overall_rating\": 3.5}"},
    {"name": "Washington Sundar", "role": "All-Rounder", "country": "India", "base_price": 8750000, "stats": "{\"matches\": 58, \"runs\": 378, \"wickets\": 36, \"batting_rating\": 3, \"bowling_rating\": 5, \"overall_rating\": 4.0}"},
    {"name": "Vijay Shankar", "role": "All-Rounder", "country": "India", "base_price": 1400000, "stats": "{\"matches\": 65, \"runs\": 1032, \"wickets\": 9, \"batting_rating\": 4, \"bowling_rating\": 3, \"overall_rating\": 3.5}"},
    {"name": "Riyan Parag", "role": "All-Rounder", "country": "India", "base_price": 3800000, "stats": "{\"matches\": 68, \"runs\": 727, \"wickets\": 4, \"batting_rating\": 3, \"bowling_rating\": 3, \"overall_rating\": 3.0}"},
    {"name": "Liam Livingstone", "role": "All-Rounder", "country": "England", "base_price": 11500000, "stats": "{\"matches\": 42, \"runs\": 828, \"wickets\": 8, \"batting_rating\": 5, \"bowling_rating\": 3, \"overall_rating\": 4.0}"},
    {"name": "Odean Smith", "role": "All-Rounder", "country": "West Indies", "base_price": 6000000, "stats": "{\"matches\": 19, \"runs\": 143, \"wickets\": 7, \"batting_rating\": 3, \"bowling_rating\": 3, \"overall_rating\": 3.0}"},
    {"name": "Romario Shepherd", "role": "All-Rounder", "country": "West Indies", "base_price": 7750000, "stats": "{\"matches\": 7, \"runs\": 58, \"wickets\": 3, \"batting_rating\": 3, \"bowling_rating\": 3, \"overall_rating\": 3.0}"},
    {"name": "Shivam Dube", "role": "All-Rounder", "country": "India", "base_price": 4000000, "stats": "{\"matches\": 60, \"runs\": 1106, \"wickets\": 4, \"batting_rating\": 5, \"bowling_rating\": 2, \"overall_rating\": 3.5}"},
    {"name": "Irfan Pathan", "role": "All-Rounder", "country": "India", "base_price": 2000000, "stats": "{\"matches\": 103, \"runs\": 1139, \"wickets\": 80, \"batting_rating\": 4, \"bowling_rating\": 6, \"overall_rating\": 5.0}"},
    {"name": "Moises Henriques", "role": "All-Rounder", "country": "Australia", "base_price": 2000000, "stats": "{\"matches\": 62, \"runs\": 1000, \"wickets\": 42, \"batting_rating\": 4, \"bowling_rating\": 5, \"overall_rating\": 4.5}"},
    {"name": "Jacques Kallis", "role": "All-Rounder", "country": "South Africa", "base_price": 2000000, "stats": "{\"matches\": 98, \"runs\": 2427, \"wickets\": 65, \"batting_rating\": 7, \"bowling_rating\": 6, \"overall_rating\": 6.5}"},
    {"name": "Shane Watson", "role": "All-Rounder", "country": "Australia", "base_price": 2000000, "stats": "{\"matches\": 145, \"runs\": 3874, \"wickets\": 92, \"batting_rating\": 7, \"bowling_rating\": 6, \"overall_rating\": 6.5}"},
    {"name": "Dwayne Bravo", "role": "All-Rounder", "country": "West Indies", "base_price": 2000000, "stats": "{\"matches\": 161, \"runs\": 1560, \"wickets\": 183, \"batting_rating\": 4, \"bowling_rating\": 8, \"overall_rating\": 6.0}"},
    {"name": "Kieron Pollard", "role": "All-Rounder", "country": "West Indies", "base_price": 2000000, "stats": "{\"matches\": 189, \"runs\": 3412, \"wickets\": 69, \"batting_rating\": 6, \"bowling_rating\": 5, \"overall_rating\": 5.5}"},
    {"name": "Albie Morkel", "role": "All-Rounder", "country": "South Africa", "base_price": 2000000, "stats": "{\"matches\": 91, \"runs\": 974, \"wickets\": 85, \"batting_rating\": 4, \"bowling_rating\": 6, \"overall_rating\": 5.0}"},
    {"name": "Andrew Symonds", "role": "All-Rounder", "country": "Australia", "base_price": 2000000, "stats": "{\"matches\": 39, \"runs\": 974, \"wickets\": 20, \"batting_rating\": 5, \"bowling_rating\": 4, \"overall_rating\": 4.5}"},
    {"name": "Stuart Binny", "role": "All-Rounder", "country": "India", "base_price": 2000000, "stats": "{\"matches\": 95, \"runs\": 880, \"wickets\": 22, \"batting_rating\": 3, \"bowling_rating\": 4, \"overall_rating\": 3.5}"},
    {"name": "James Faulkner", "role": "All-Rounder", "country": "Australia", "base_price": 2000000, "stats": "{\"matches\": 60, \"runs\": 527, \"wickets\": 59, \"batting_rating\": 4, \"bowling_rating\": 6, \"overall_rating\": 5.0}"},
    {"name": "Chris Woakes", "role": "All-Rounder", "country": "England", "base_price": 1500000, "stats": "{\"matches\": 21, \"runs\": 78, \"wickets\": 30, \"batting_rating\": 2, \"bowling_rating\": 6, \"overall_rating\": 4.0}"}
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
  ('22222222-aaaa-2222-2222-222222222222', 'csk_a@ipl.com', 'team', 'Chennai Super Kings', auction_a_id),
  ('33333333-aaaa-3333-3333-333333333333', 'mi_a@ipl.com', 'team', 'Mumbai Indians', auction_a_id),
  ('44444444-aaaa-4444-4444-444444444444', 'rcb_a@ipl.com', 'team', 'Royal Challengers Bangalore', auction_a_id),
  ('55555555-aaaa-5555-5555-555555555555', 'gt_a@ipl.com', 'team', 'Gujarat Titans', auction_a_id),
  ('66666666-aaaa-6666-6666-666666666666', 'kkr_a@ipl.com', 'team', 'Kolkata Knight Riders', auction_a_id),
  ('77777777-aaaa-7777-7777-777777777777', 'srh_a@ipl.com', 'team', 'Sunrisers Hyderabad', auction_a_id),
  ('88888888-aaaa-8888-8888-888888888888', 'dc_a@ipl.com', 'team', 'Delhi Capitals', auction_a_id),
  ('99999999-aaaa-9999-9999-999999999999', 'pbks_a@ipl.com', 'team', 'Punjab Kings', auction_a_id),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'lsg_a@ipl.com', 'team', 'Lucknow Super Giants', auction_a_id),
  ('bbbbbbbb-aaaa-bbbb-bbbb-bbbbbbbbbbbb', 'rr_a@ipl.com', 'team', 'Rajasthan Royals', auction_a_id);
  
  -- AUCTION B USERS
  INSERT INTO public.user_profiles (id, email, role, team_name, auction_event_id) VALUES
  ('11111111-bbbb-1111-1111-111111111111', 'admin_b@ipl.com', 'admin', NULL, auction_b_id),
  ('22222222-bbbb-2222-2222-222222222222', 'csk_b@ipl.com', 'team', 'Chennai Super Kings', auction_b_id),
  ('33333333-bbbb-3333-3333-333333333333', 'mi_b@ipl.com', 'team', 'Mumbai Indians', auction_b_id),
  ('44444444-bbbb-4444-4444-444444444444', 'rcb_b@ipl.com', 'team', 'Royal Challengers Bangalore', auction_b_id),
  ('55555555-bbbb-5555-5555-555555555555', 'gt_b@ipl.com', 'team', 'Gujarat Titans', auction_b_id),
  ('66666666-bbbb-6666-6666-666666666666', 'kkr_b@ipl.com', 'team', 'Kolkata Knight Riders', auction_b_id),
  ('77777777-bbbb-7777-7777-777777777777', 'srh_b@ipl.com', 'team', 'Sunrisers Hyderabad', auction_b_id),
  ('88888888-bbbb-8888-8888-888888888888', 'dc_b@ipl.com', 'team', 'Delhi Capitals', auction_b_id),
  ('99999999-bbbb-9999-9999-999999999999', 'pbks_b@ipl.com', 'team', 'Punjab Kings', auction_b_id),
  ('aaaaaaaa-bbbb-aaaa-aaaa-aaaaaaaaaaaa', 'lsg_b@ipl.com', 'team', 'Lucknow Super Giants', auction_b_id),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'rr_b@ipl.com', 'team', 'Rajasthan Royals', auction_b_id);

  -- AUCTION C USERS
  INSERT INTO public.user_profiles (id, email, role, team_name, auction_event_id) VALUES
  ('11111111-cccc-1111-1111-111111111111', 'admin_c@ipl.com', 'admin', NULL, auction_c_id),
  ('22222222-cccc-2222-2222-222222222222', 'csk_c@ipl.com', 'team', 'Chennai Super Kings', auction_c_id),
  ('33333333-cccc-3333-3333-333333333333', 'mi_c@ipl.com', 'team', 'Mumbai Indians', auction_c_id),
  ('44444444-cccc-4444-4444-444444444444', 'rcb_c@ipl.com', 'team', 'Royal Challengers Bangalore', auction_c_id),
  ('55555555-cccc-5555-5555-555555555555', 'gt_c@ipl.com', 'team', 'Gujarat Titans', auction_c_id),
  ('66666666-cccc-6666-6666-666666666666', 'kkr_c@ipl.com', 'team', 'Kolkata Knight Riders', auction_c_id),
  ('77777777-cccc-7777-7777-777777777777', 'srh_c@ipl.com', 'team', 'Sunrisers Hyderabad', auction_c_id),
  ('88888888-cccc-8888-8888-888888888888', 'dc_c@ipl.com', 'team', 'Delhi Capitals', auction_c_id),
  ('99999999-cccc-9999-9999-999999999999', 'pbks_c@ipl.com', 'team', 'Punjab Kings', auction_c_id),
  ('aaaaaaaa-cccc-aaaa-aaaa-aaaaaaaaaaaa', 'lsg_c@ipl.com', 'team', 'Lucknow Super Giants', auction_c_id),
  ('bbbbbbbb-cccc-bbbb-bbbb-bbbbbbbbbbbb', 'rr_c@ipl.com', 'team', 'Rajasthan Royals', auction_c_id);
  
  -- AUCTION D USERS
  INSERT INTO public.user_profiles (id, email, role, team_name, auction_event_id) VALUES
  ('11111111-dddd-1111-1111-111111111111', 'admin_d@ipl.com', 'admin', NULL, auction_d_id),
  ('22222222-dddd-2222-2222-222222222222', 'csk_d@ipl.com', 'team', 'Chennai Super Kings', auction_d_id),
  ('33333333-dddd-3333-3333-333333333333', 'mi_d@ipl.com', 'team', 'Mumbai Indians', auction_d_id),
  ('44444444-dddd-4444-4444-444444444444', 'rcb_d@ipl.com', 'team', 'Royal Challengers Bangalore', auction_d_id),
  ('55555555-dddd-5555-5555-555555555555', 'gt_d@ipl.com', 'team', 'Gujarat Titans', auction_d_id),
  ('66666666-dddd-6666-6666-666666666666', 'kkr_d@ipl.com', 'team', 'Kolkata Knight Riders', auction_d_id),
  ('77777777-dddd-7777-7777-777777777777', 'srh_d@ipl.com', 'team', 'Sunrisers Hyderabad', auction_d_id),
  ('88888888-dddd-8888-8888-888888888888', 'dc_d@ipl.com', 'team', 'Delhi Capitals', auction_d_id),
  ('99999999-dddd-9999-9999-999999999999', 'pbks_d@ipl.com', 'team', 'Punjab Kings', auction_d_id),
  ('aaaaaaaa-dddd-aaaa-aaaa-aaaaaaaaaaaa', 'lsg_d@ipl.com', 'team', 'Lucknow Super Giants', auction_d_id),
  ('bbbbbbbb-dddd-bbbb-bbbb-bbbbbbbbbbbb', 'rr_d@ipl.com', 'team', 'Rajasthan Royals', auction_d_id);

END $$;

