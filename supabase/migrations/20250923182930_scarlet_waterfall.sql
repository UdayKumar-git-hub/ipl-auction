/*
  # IPL Auction Database Schema

  1. New Tables
    - `user_profiles`
      - `id` (uuid, primary key, references auth.users)
      - `email` (text)
      - `role` (text, admin/team)
      - `team_name` (text, nullable)
      - `created_at` (timestamp)

    - `teams`
      - `id` (uuid, primary key)
      - `name` (text)
      - `short_name` (text)
      - `logo_url` (text)
      - `purse_remaining` (bigint)
      - `total_purse` (bigint)
      - `players_count` (integer)
      - `created_at` (timestamp)

    - `players`
      - `id` (uuid, primary key)
      - `name` (text)
      - `role` (text)
      - `country` (text)
      - `base_price` (bigint)
      - `current_price` (bigint, nullable)
      - `photo_url` (text)
      - `stats` (jsonb)
      - `team_id` (uuid, nullable, references teams)
      - `is_sold` (boolean)
      - `created_at` (timestamp)

    - `auctions`
      - `id` (uuid, primary key)
      - `player_id` (uuid, references players)
      - `current_price` (bigint)
      - `is_active` (boolean)
      - `winning_team_id` (uuid, nullable, references teams)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- User profiles table
CREATE TABLE IF NOT EXISTS user_profiles (
  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  email text NOT NULL,
  role text NOT NULL CHECK (role IN ('admin', 'team')),
  team_name text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- Teams table
CREATE TABLE IF NOT EXISTS teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  short_name text NOT NULL,
  logo_url text NOT NULL DEFAULT 'https://images.pexels.com/photos/274506/pexels-photo-274506.jpeg',
  purse_remaining bigint NOT NULL DEFAULT 1000000000,
  total_purse bigint NOT NULL DEFAULT 1000000000,
  players_count integer NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE teams ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read teams"
  ON teams
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only admins can modify teams"
  ON teams
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Players table
CREATE TABLE IF NOT EXISTS players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  role text NOT NULL CHECK (role IN ('Batsman', 'Bowler', 'All-Rounder', 'Wicketkeeper')),
  country text NOT NULL,
  base_price bigint NOT NULL,
  current_price bigint,
  photo_url text NOT NULL DEFAULT 'https://images.pexels.com/photos/163452/basketball-dunk-blue-game-163452.jpeg',
  stats jsonb NOT NULL DEFAULT '{"matches": 0}',
  team_id uuid REFERENCES teams(id) ON DELETE SET NULL,
  is_sold boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE players ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read players"
  ON players
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only admins can modify players"
  ON players
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Auctions table
CREATE TABLE IF NOT EXISTS auctions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  current_price bigint NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  winning_team_id uuid REFERENCES teams(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE auctions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read auctions"
  ON auctions
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only admins can modify auctions"
  ON auctions
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
