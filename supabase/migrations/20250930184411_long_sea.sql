/*
  # Complete IPL Auction Database Schema

  1. New Tables
    - `user_profiles` - User authentication and roles
    - `teams` - IPL team information with purse tracking
    - `players` - Complete player database with stats
    - `auctions` - Live auction tracking and history
    - `current_auction` - Single row table for current auction state

  2. Security
    - Enable RLS on all tables
    - Add policies for admin and team access
    - Secure data access based on user roles

  3. Sample Data
    - Pre-populate teams with IPL franchises
    - Add sample players for testing
    - Create demo user accounts
*/

-- Create user_profiles table
CREATE TABLE IF NOT EXISTS user_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE NOT NULL,
  role text NOT NULL CHECK (role IN ('admin', 'team')),
  team_name text,
  created_at timestamptz DEFAULT now()
);

-- Create teams table
CREATE TABLE IF NOT EXISTS teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  short_name text UNIQUE NOT NULL,
  logo_url text DEFAULT 'https://images.pexels.com/photos/274506/pexels-photo-274506.jpeg?auto=compress&cs=tinysrgb&w=200&h=200&fit=crop',
  purse_remaining bigint DEFAULT 1000000000,
  total_purse bigint DEFAULT 1000000000,
  players_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create players table
CREATE TABLE IF NOT EXISTS players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  role text NOT NULL CHECK (role IN ('Batsman', 'Bowler', 'All-Rounder', 'Wicketkeeper')),
  country text NOT NULL,
  base_price bigint NOT NULL,
  current_price bigint,
  photo_url text DEFAULT 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop',
  stats jsonb DEFAULT '{"matches": 0, "runs": 0, "wickets": 0, "average": 0}',
  team_id uuid REFERENCES teams(id),
  is_sold boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Create auctions table
CREATE TABLE IF NOT EXISTS auctions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid REFERENCES players(id) NOT NULL,
  current_price bigint NOT NULL,
  is_active boolean DEFAULT false,
  winning_team_id uuid REFERENCES teams(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create current_auction table for live auction state
CREATE TABLE IF NOT EXISTS current_auction (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid REFERENCES players(id),
  current_price bigint DEFAULT 0,
  is_active boolean DEFAULT false,
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE auctions ENABLE ROW LEVEL SECURITY;
ALTER TABLE current_auction ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_profiles
CREATE POLICY "Users can read own profile"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid()::text = id::text);

-- RLS Policies for teams (readable by all authenticated users)
CREATE POLICY "Teams are readable by authenticated users"
  ON teams
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Teams are manageable by admins"
  ON teams
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id::text = auth.uid()::text AND role = 'admin'
    )
  );

-- RLS Policies for players (readable by all, manageable by admins)
CREATE POLICY "Players are readable by authenticated users"
  ON players
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Players are manageable by admins"
  ON players
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id::text = auth.uid()::text AND role = 'admin'
    )
  );

-- RLS Policies for auctions
CREATE POLICY "Auctions are readable by authenticated users"
  ON auctions
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Auctions are manageable by admins"
  ON auctions
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id::text = auth.uid()::text AND role = 'admin'
    )
  );

-- RLS Policies for current_auction
CREATE POLICY "Current auction is readable by authenticated users"
  ON current_auction
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Current auction is manageable by admins"
  ON current_auction
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id::text = auth.uid()::text AND role = 'admin'
    )
  );

-- Insert IPL teams
INSERT INTO teams (name, short_name, logo_url, purse_remaining, total_purse) VALUES
('Chennai Super Kings', 'CSK', 'https://images.pexels.com/photos/274506/pexels-photo-274506.jpeg?auto=compress&cs=tinysrgb&w=200&h=200&fit=crop', 1000000000, 1000000000),
('Mumbai Indians', 'MI', 'https://images.pexels.com/photos/274506/pexels-photo-274506.jpeg?auto=compress&cs=tinysrgb&w=200&h=200&fit=crop', 1000000000, 1000000000),
('Royal Challengers Bangalore', 'RCB', 'https://images.pexels.com/photos/274506/pexels-photo-274506.jpeg?auto=compress&cs=tinysrgb&w=200&h=200&fit=crop', 1000000000, 1000000000),
('Gujarat Titans', 'GT', 'https://images.pexels.com/photos/274506/pexels-photo-274506.jpeg?auto=compress&cs=tinysrgb&w=200&h=200&fit=crop', 1000000000, 1000000000),
('Kolkata Knight Riders', 'KKR', 'https://images.pexels.com/photos/274506/pexels-photo-274506.jpeg?auto=compress&cs=tinysrgb&w=200&h=200&fit=crop', 1000000000, 1000000000),
('Sunrisers Hyderabad', 'SRH', 'https://images.pexels.com/photos/274506/pexels-photo-274506.jpeg?auto=compress&cs=tinysrgb&w=200&h=200&fit=crop', 1000000000, 1000000000),
('Delhi Capitals', 'DC', 'https://images.pexels.com/photos/274506/pexels-photo-274506.jpeg?auto=compress&cs=tinysrgb&w=200&h=200&fit=crop', 1000000000, 1000000000),
('Punjab Kings', 'PBKS', 'https://images.pexels.com/photos/274506/pexels-photo-274506.jpeg?auto=compress&cs=tinysrgb&w=200&h=200&fit=crop', 1000000000, 1000000000),
('Lucknow Super Giants', 'LSG', 'https://images.pexels.com/photos/274506/pexels-photo-274506.jpeg?auto=compress&cs=tinysrgb&w=200&h=200&fit=crop', 1000000000, 1000000000),
('Rajasthan Royals', 'RR', 'https://images.pexels.com/photos/274506/pexels-photo-274506.jpeg?auto=compress&cs=tinysrgb&w=200&h=200&fit=crop', 1000000000, 1000000000)
ON CONFLICT (name) DO NOTHING;

-- Insert sample players
INSERT INTO players (name, role, country, base_price, photo_url, stats) VALUES
('Virat Kohli', 'Batsman', 'India', 20000000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 237, "runs": 7263, "average": 37.25}'),
('Rohit Sharma', 'Batsman', 'India', 16000000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 243, "runs": 6211, "average": 31.17}'),
('MS Dhoni', 'Wicketkeeper', 'India', 12000000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 264, "runs": 5082, "average": 39.55}'),
('Jasprit Bumrah', 'Bowler', 'India', 12000000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 133, "wickets": 165, "average": 24.43}'),
('Hardik Pandya', 'All-Rounder', 'India', 15000000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 104, "runs": 1476, "wickets": 42, "average": 31.27}'),
('Ravindra Jadeja', 'All-Rounder', 'India', 16000000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 220, "runs": 2756, "wickets": 157, "average": 29.85}'),
('KL Rahul', 'Wicketkeeper', 'India', 17000000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 132, "runs": 4683, "average": 47.83}'),
('Yuzvendra Chahal', 'Bowler', 'India', 6500000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 142, "wickets": 187, "average": 22.51}'),
('Shikhar Dhawan', 'Batsman', 'India', 8200000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 206, "runs": 6617, "average": 35.15}'),
('Rishabh Pant', 'Wicketkeeper', 'India', 16000000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 98, "runs": 3284, "average": 35.31}'),
('David Warner', 'Batsman', 'Australia', 6250000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 184, "runs": 6397, "average": 41.59}'),
('Pat Cummins', 'Bowler', 'Australia', 20500000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 65, "wickets": 85, "average": 26.78}'),
('Glenn Maxwell', 'All-Rounder', 'Australia', 11000000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 129, "runs": 2771, "wickets": 32, "average": 26.22}'),
('Jos Buttler', 'Wicketkeeper', 'England', 10000000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 91, "runs": 3582, "average": 41.64}'),
('Ben Stokes', 'All-Rounder', 'England', 16250000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 43, "runs": 920, "wickets": 28, "average": 34.81}'),
('Kagiso Rabada', 'Bowler', 'South Africa', 9250000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 64, "wickets": 94, "average": 18.46}'),
('Quinton de Kock', 'Wicketkeeper', 'South Africa', 6750000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 77, "runs": 2256, "average": 31.33}'),
('Rashid Khan', 'Bowler', 'Afghanistan', 15000000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 76, "wickets": 93, "average": 20.64}'),
('Andre Russell', 'All-Rounder', 'West Indies', 12000000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 98, "runs": 2036, "wickets": 69, "average": 29.92}'),
('Sunil Narine', 'All-Rounder', 'West Indies', 6000000, 'https://images.pexels.com/photos/1618200/pexels-photo-1618200.jpeg?auto=compress&cs=tinysrgb&w=300&h=400&fit=crop', '{"matches": 162, "runs": 1025, "wickets": 180, "average": 26.52}')
ON CONFLICT DO NOTHING;

-- Insert demo user profiles
INSERT INTO user_profiles (id, email, role, team_name) VALUES
('11111111-1111-1111-1111-111111111111', 'admin@ipl.com', 'admin', NULL),
('22222222-2222-2222-2222-222222222222', 'csk@ipl.com', 'team', 'Chennai Super Kings'),
('33333333-3333-3333-3333-333333333333', 'mi@ipl.com', 'team', 'Mumbai Indians'),
('44444444-4444-4444-4444-444444444444', 'rcb@ipl.com', 'team', 'Royal Challengers Bangalore'),
('55555555-5555-5555-5555-555555555555', 'gt@ipl.com', 'team', 'Gujarat Titans'),
('66666666-6666-6666-6666-666666666666', 'kkr@ipl.com', 'team', 'Kolkata Knight Riders'),
('77777777-7777-7777-7777-777777777777', 'srh@ipl.com', 'team', 'Sunrisers Hyderabad'),
('88888888-8888-8888-8888-888888888888', 'dc@ipl.com', 'team', 'Delhi Capitals'),
('99999999-9999-9999-9999-999999999999', 'pbks@ipl.com', 'team', 'Punjab Kings'),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'lsg@ipl.com', 'team', 'Lucknow Super Giants'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'rr@ipl.com', 'team', 'Rajasthan Royals')
ON CONFLICT (email) DO NOTHING;

-- Initialize current_auction table with empty state
INSERT INTO current_auction (is_active) VALUES (false)
ON CONFLICT DO NOTHING;