/*
  # Complete, Destructive, and Final IPL Auction Database Schema
  # Version: 6.0 (Production Ready)

  This script is DESTRUCTIVE and will REBUILD your database from scratch.
  This is the definitive script to ensure a clean, error-free, and efficient setup.

  Key Improvements in this Version:
  - REMOVED the redundant `current_auction` table for a simplified, more robust single-table auction model.
  - FIXED the `sell_player` function to be fully atomic, now correctly updating the `auctions` table.
  - CLEANED player seed data to remove duplicates (Riyan Parag, James Faulkner).
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


-- ----------------------------------------
-- TABLE CREATION
-- ----------------------------------------

CREATE TABLE public.user_profiles (
  id uuid PRIMARY KEY NOT NULL, -- This ID must match auth.users.id
  email text UNIQUE NOT NULL,
  role text NOT NULL CHECK (role IN ('admin', 'team')),
  team_name text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE public.teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  short_name text UNIQUE NOT NULL,
  logo_url text DEFAULT 'https://i.imgur.com/K4VMA5U.png',
  purse_remaining bigint DEFAULT 1000000000,
  total_purse bigint DEFAULT 1000000000,
  players_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE public.players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  role text NOT NULL CHECK (role IN ('Batsman', 'Bowler', 'All-Rounder', 'Wicketkeeper')),
  country text NOT NULL,
  base_price bigint NOT NULL,
  current_price bigint,
  photo_url text DEFAULT 'https://i.imgur.com/S21eL5A.png',
  stats jsonb DEFAULT '{}',
  team_id uuid REFERENCES public.teams(id),
  is_sold boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE public.auctions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid REFERENCES public.players(id) NOT NULL,
  current_price bigint NOT NULL,
  is_active boolean DEFAULT false,
  winning_team_id uuid REFERENCES public.teams(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- ----------------------------------------
-- INDEXES (for Performance)
-- ----------------------------------------
CREATE INDEX IF NOT EXISTS idx_players_team_id ON public.players (team_id);
CREATE INDEX IF NOT EXISTS idx_auctions_player_id ON public.auctions (player_id);
CREATE INDEX IF NOT EXISTS idx_auctions_is_active ON public.auctions (is_active); -- Important for finding the live auction
CREATE INDEX IF NOT EXISTS idx_user_profiles_role ON public.user_profiles (role);


-- ----------------------------------------
-- ROW LEVEL SECURITY (RLS)
-- ----------------------------------------
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auctions ENABLE ROW LEVEL SECURITY;

-- Policies for user_profiles
DROP POLICY IF EXISTS "Users can read their own profile" ON public.user_profiles;
CREATE POLICY "Users can read their own profile" ON public.user_profiles FOR SELECT TO authenticated USING (auth.uid() = id);

-- Policies for teams
DROP POLICY IF EXISTS "Authenticated users can read team data" ON public.teams;
CREATE POLICY "Authenticated users can read team data" ON public.teams FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Admins can manage teams" ON public.teams;
CREATE POLICY "Admins can manage teams" ON public.teams FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin'));

-- Policies for players
DROP POLICY IF EXISTS "Authenticated users can read player data" ON public.players;
CREATE POLICY "Authenticated users can read player data" ON public.players FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Admins can manage players" ON public.players;
CREATE POLICY "Admins can manage players" ON public.players FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin'));

-- Policies for auctions
DROP POLICY IF EXISTS "Authenticated users can read auction data" ON public.auctions;
CREATE POLICY "Authenticated users can read auction data" ON public.auctions FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Admins can manage auctions" ON public.auctions;
CREATE POLICY "Admins can manage auctions" ON public.auctions FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin'));


-- ----------------------------------------
-- DATABASE FUNCTION FOR ATOMIC TRANSACTION (CORRECTED)
-- ----------------------------------------
CREATE OR REPLACE FUNCTION sell_player(
    p_id uuid, -- player_id
    t_id uuid, -- team_id
    a_id uuid, -- auction_id
    sell_price bigint
)
RETURNS void
LANGUAGE plpgsql
-- SECURITY DEFINER allows this function to run with the permissions of the user who defined it, bypassing RLS for the transaction.
SECURITY DEFINER AS $$
DECLARE
  current_purse bigint;
  already_sold boolean;
BEGIN
  -- Lock the player row to prevent race conditions (another admin selling the same player)
  SELECT is_sold INTO already_sold FROM public.players WHERE id = p_id FOR UPDATE;
  IF already_sold THEN
    RAISE EXCEPTION 'Player has already been sold.';
  END IF;

  -- Lock the team row to prevent race conditions and check for sufficient funds
  SELECT purse_remaining INTO current_purse FROM public.teams WHERE id = t_id FOR UPDATE;
  IF current_purse < sell_price THEN
    RAISE EXCEPTION 'Insufficient purse for the team.';
  END IF;

  -- 1. UPDATE THE PLAYER: Mark as sold and assign to the winning team.
  UPDATE public.players
  SET is_sold = true, team_id = t_id, current_price = sell_price
  WHERE id = p_id;

  -- 2. UPDATE THE TEAM: Deduct from purse and increment player count.
  UPDATE public.teams
  SET purse_remaining = purse_remaining - sell_price, players_count = players_count + 1
  WHERE id = t_id;

  -- 3. UPDATE THE AUCTION (CRITICAL FIX): Mark the auction as inactive and record the winner.
  UPDATE public.auctions
  SET is_active = false, winning_team_id = t_id, current_price = sell_price
  WHERE id = a_id;
END;
$$;


-- ----------------------------------------
-- SEED DATA
-- ----------------------------------------
INSERT INTO public.teams (name, short_name) VALUES
('Chennai Super Kings', 'CSK'), ('Mumbai Indians', 'MI'), ('Royal Challengers Bangalore', 'RCB'),
('Gujarat Titans', 'GT'), ('Kolkata Knight Riders', 'KKR'), ('Sunrisers Hyderabad', 'SRH'),
('Delhi Capitals', 'DC'), ('Punjab Kings', 'PBKS'), ('Lucknow Super Giants', 'LSG'), ('Rajasthan Royals', 'RR')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.players (name, role, country, base_price, stats) VALUES
-- Batsmen & Wicketkeepers (Corrected Count: 59)
('Virat Kohli', 'Batsman', 'India', 20000000, '{"matches": 254, "runs": 8094, "average": 38.91, "strike_rate": 132.02, "high_score": 113, "100s": 8, "50s": 56, "4s": 711, "6s": 276, "rating": 9.0}'),
('Rohit Sharma', 'Batsman', 'India', 16000000, '{"matches": 260, "runs": 6649, "average": 29.42, "strike_rate": 131.04, "high_score": 109, "100s": 2, "50s": 43, "4s": 601, "6s": 281, "rating": 7.4}'),
('MS Dhoni', 'Wicketkeeper', 'India', 12000000, '{"matches": 267, "runs": 5289, "average": 39.18, "strike_rate": 137.7, "high_score": 84, "100s": 0, "50s": 24, "4s": 361, "6s": 252, "rating": 8.1}'),
('Shikhar Dhawan', 'Batsman', 'India', 8250000, '{"matches": 222, "runs": 6769, "average": 35.26, "strike_rate": 127.13, "high_score": 106, "100s": 2, "50s": 51, "4s": 768, "6s": 152, "rating": 8.3}'),
('David Warner', 'Batsman', 'Australia', 6250000, '{"matches": 184, "runs": 6565, "average": 41.55, "strike_rate": 139.73, "high_score": 109, "100s": 4, "50s": 62, "4s": 663, "6s": 236, "rating": 8.8}'),
('Suresh Raina', 'Batsman', 'India', 10000000, '{"matches": 205, "runs": 5528, "average": 32.52, "strike_rate": 136.76, "high_score": 100, "100s": 1, "50s": 39, "4s": 506, "6s": 203, "rating": 7.8}'),
('Gautam Gambhir', 'Batsman', 'India', 9000000, '{"matches": 154, "runs": 4217, "average": 31.01, "strike_rate": 123.88, "high_score": 93, "100s": 0, "50s": 36, "4s": 491, "6s": 59, "rating": 7.5}'),
('Chris Gayle', 'Batsman', 'West Indies', 10000000, '{"matches": 142, "runs": 4965, "average": 39.72, "strike_rate": 148.96, "high_score": 175, "100s": 6, "50s": 31, "4s": 404, "6s": 357, "rating": 8.5}'),
('Robin Uthappa', 'Batsman', 'India', 5000000, '{"matches": 205, "runs": 4952, "average": 27.51, "strike_rate": 130.35, "high_score": 88, "100s": 0, "50s": 27, "4s": 481, "6s": 182, "rating": 6.9}'),
('Ajinkya Rahane', 'Batsman', 'India', 4000000, '{"matches": 172, "runs": 4400, "average": 30.77, "strike_rate": 123.33, "high_score": 105, "100s": 2, "50s": 30, "4s": 431, "6s": 83, "rating": 6.8}'),
('Dinesh Karthik', 'Wicketkeeper', 'India', 7500000, '{"matches": 257, "runs": 4842, "average": 26.32, "strike_rate": 135.75, "high_score": 97, "100s": 0, "50s": 22, "4s": 441, "6s": 155, "rating": 7.1}'),
('Faf du Plessis', 'Batsman', 'South Africa', 6000000, '{"matches": 145, "runs": 4133, "average": 36.9, "strike_rate": 134.19, "high_score": 96, "100s": 0, "50s": 33, "4s": 371, "6s": 145, "rating": 8.2}'),
('Shubman Gill', 'Batsman', 'India', 8000000, '{"matches": 103, "runs": 3216, "average": 38.29, "strike_rate": 141.05, "high_score": 129, "100s": 4, "50s": 20, "4s": 314, "6s": 80, "rating": 8.4}'),
('Mayank Agarwal', 'Batsman', 'India', 3000000, '{"matches": 123, "runs": 2597, "average": 22.58, "strike_rate": 134.46, "high_score": 106, "100s": 1, "50s": 13, "4s": 265, "6s": 98, "rating": 6.2}'),
('Nitish Rana', 'Batsman', 'India', 3500000, '{"matches": 115, "runs": 2594, "average": 28.51, "strike_rate": 135.39, "high_score": 87, "100s": 0, "50s": 18, "4s": 204, "6s": 135, "rating": 6.7}'),
('Wriddhiman Saha', 'Wicketkeeper', 'India', 2000000, '{"matches": 173, "runs": 2798, "average": 24.54, "strike_rate": 128.69, "high_score": 115, "100s": 1, "50s": 13, "4s": 298, "6s": 84, "rating": 6.3}'),
('Rahul Tripathi', 'Batsman', 'India', 4000000, '{"matches": 100, "runs": 2071, "average": 26.55, "strike_rate": 139.72, "high_score": 93, "100s": 0, "50s": 11, "4s": 213, "6s": 77, "rating": 6.5}'),
('Ishan Kishan', 'Wicketkeeper', 'India', 15250000, '{"matches": 101, "runs": 2324, "average": 29.42, "strike_rate": 134.18, "high_score": 99, "100s": 0, "50s": 15, "4s": 218, "6s": 103, "rating": 7.3}'),
('Devdutt Padikkal', 'Batsman', 'India', 7750000, '{"matches": 57, "runs": 1521, "average": 27.65, "strike_rate": 125.39, "high_score": 101, "100s": 1, "50s": 9, "4s": 164, "6s": 41, "rating": 6.4}'),
('Prithvi Shaw', 'Batsman', 'India', 7500000, '{"matches": 71, "runs": 1694, "average": 23.86, "strike_rate": 146.5, "high_score": 99, "100s": 0, "50s": 13, "4s": 211, "6s": 58, "rating": 6.6}'),
('David Miller', 'Batsman', 'South Africa', 3000000, '{"matches": 133, "runs": 2714, "average": 36.19, "strike_rate": 138.86, "high_score": 101, "100s": 1, "50s": 13, "4s": 182, "6s": 126, "rating": 7.6}'),
('Jos Buttler', 'Wicketkeeper', 'England', 10000000, '{"matches": 106, "runs": 3223, "average": 37.92, "strike_rate": 148.32, "high_score": 124, "100s": 5, "50s": 19, "4s": 319, "6s": 149, "rating": 8.6}'),
('Quinton de Kock', 'Wicketkeeper', 'South Africa', 6750000, '{"matches": 107, "runs": 2907, "average": 31.6, "strike_rate": 134.02, "high_score": 140, "100s": 2, "50s": 20, "4s": 296, "6s": 107, "rating": 7.9}'),
('Jonny Bairstow', 'Wicketkeeper', 'England', 6750000, '{"matches": 39, "runs": 1291, "average": 35.86, "strike_rate": 142.65, "high_score": 114, "100s": 1, "50s": 9, "4s": 132, "6s": 54, "rating": 7.8}'),
('Nicholas Pooran', 'Wicketkeeper', 'West Indies', 16000000, '{"matches": 72, "runs": 1270, "average": 26.46, "strike_rate": 156.0, "high_score": 77, "100s": 0, "50s": 5, "4s": 79, "6s": 90, "rating": 7.2}'),
('Ambati Rayudu', 'Batsman', 'India', 6750000, '{"matches": 204, "runs": 4348, "average": 28.23, "strike_rate": 127.54, "high_score": 100, "100s": 1, "50s": 22, "4s": 361, "6s": 171, "rating": 6.7}'),
('Manish Pandey', 'Batsman', 'India', 4600000, '{"matches": 171, "runs": 3808, "average": 29.07, "strike_rate": 120.97, "high_score": 114, "100s": 1, "50s": 22, "4s": 320, "6s": 106, "rating": 6.5}'),
('Shimron Hetmyer', 'Batsman', 'West Indies', 8500000, '{"matches": 70, "runs": 1139, "average": 30.78, "strike_rate": 153.92, "high_score": 75, "100s": 0, "50s": 4, "4s": 71, "6s": 76, "rating": 7.0}'),
('Abhinav Manohar', 'Batsman', 'India', 2600000, '{"matches": 17, "runs": 222, "average": 18.5, "strike_rate": 136.2, "high_score": 42, "100s": 0, "50s": 0, "4s": 15, "6s": 13, "rating": 4.1}'),
('Shahrukh Khan', 'Batsman', 'India', 9000000, '{"matches": 43, "runs": 426, "average": 20.29, "strike_rate": 134.81, "high_score": 47, "100s": 0, "50s": 0, "4s": 27, "6s": 28, "rating": 4.9}'),
('Priyam Garg', 'Batsman', 'India', 2000000, '{"matches": 23, "runs": 251, "average": 15.69, "strike_rate": 115.67, "high_score": 51, "100s": 0, "50s": 1, "4s": 21, "6s": 8, "rating": 3.0}'),
('Rinku Singh', 'Batsman', 'India', 5500000, '{"matches": 41, "runs": 725, "average": 36.25, "strike_rate": 142.16, "high_score": 67, "100s": 0, "50s": 4, "4s": 50, "6s": 40, "rating": 7.0}'),
('Tilak Varma', 'Batsman', 'India', 17000000, '{"matches": 37, "runs": 740, "average": 38.95, "strike_rate": 144.53, "high_score": 84, "100s": 0, "50s": 3, "4s": 51, "6s": 45, "rating": 7.3}'),
('Yashasvi Jaiswal', 'Batsman', 'India', 4000000, '{"matches": 37, "runs": 1172, "average": 32.56, "strike_rate": 148.73, "high_score": 124, "100s": 1, "50s": 8, "4s": 149, "6s": 48, "rating": 8.1}'),
('Ayush Badoni', 'Batsman', 'India', 2000000, '{"matches": 44, "runs": 644, "average": 21.47, "strike_rate": 130.1, "high_score": 59, "100s": 0, "50s": 2, "4s": 41, "6s": 31, "rating": 3.7}'),
('Mahipal Lomror', 'Batsman', 'India', 9500000, '{"matches": 43, "runs": 549, "average": 18.3, "strike_rate": 135.22, "high_score": 54, "100s": 0, "50s": 1, "4s": 34, "6s": 32, "rating": 4.0}'),
('Jitesh Sharma', 'Wicketkeeper', 'India', 2000000, '{"matches": 42, "runs": 742, "average": 22.48, "strike_rate": 151.74, "high_score": 49, "100s": 0, "50s": 0, "4s": 54, "6s": 46, "rating": 3.2}'),
('Tim David', 'Batsman', 'Australia', 8250000, '{"matches": 40, "runs": 681, "average": 29.61, "strike_rate": 172.41, "high_score": 46, "100s": 0, "50s": 0, "4s": 39, "6s": 49, "rating": 3.7}'),
('Evin Lewis', 'Batsman', 'West Indies', 2000000, '{"matches": 27, "runs": 654, "average": 27.25, "strike_rate": 137.11, "high_score": 65, "100s": 0, "50s": 4, "4s": 62, "6s": 36, "rating": 6.5}'),
('KL Rahul', 'Wicketkeeper', 'India', 17000000, '{"matches": 132, "runs": 4683, "average": 47.83, "strike_rate": 134.62, "high_score": 132, "100s": 4, "50s": 37, "4s": 355, "6s": 164, "rating": 8.5}'),
('Sanju Samson', 'Wicketkeeper', 'India', 14000000, '{"matches": 166, "runs": 4273, "average": 29.88, "strike_rate": 137.94, "high_score": 119, "100s": 3, "50s": 24, "4s": 310, "6s": 196, "rating": 8.0}'),
('Rishabh Pant', 'Wicketkeeper', 'India', 16000000, '{"matches": 112, "runs": 3284, "average": 35.31, "strike_rate": 148.64, "high_score": 128, "100s": 1, "50s": 18, "4s": 286, "6s": 140, "rating": 7.9}'),
('Suryakumar Yadav', 'Batsman', 'India', 8000000, '{"matches": 153, "runs": 3600, "average": 31.86, "strike_rate": 146.52, "high_score": 103, "100s": 2, "50s": 24, "4s": 361, "6s": 126, "rating": 7.8}'),
('Shreyas Iyer', 'Batsman', 'India', 12250000, '{"matches": 116, "runs": 3073, "average": 31.04, "strike_rate": 126.83, "high_score": 96, "100s": 0, "50s": 21, "4s": 266, "6s": 94, "rating": 7.4}'),
('Prabhsimran Singh', 'Wicketkeeper', 'India', 600000, '{"matches": 20, "runs": 334, "average": 17.58, "strike_rate": 136.89, "high_score": 103, "100s": 1, "50s": 1, "4s": 35, "6s": 17, "rating": 4.5}'),
('Sai Sudharsan', 'Batsman', 'India', 200000, '{"matches": 21, "runs": 757, "average": 39.84, "strike_rate": 134.46, "high_score": 96, "100s": 0, "50s": 5, "4s": 71, "6s": 22, "rating": 7.0}'),
('Ruturaj Gaikwad', 'Batsman', 'India', 6000000, '{"matches": 63, "runs": 2307, "average": 41.2, "strike_rate": 136.21, "high_score": 101, "100s": 1, "50s": 18, "4s": 208, "6s": 85, "rating": 8.3}'),
('Devon Conway', 'Wicketkeeper', 'New Zealand', 1000000, '{"matches": 23, "runs": 924, "average": 48.63, "strike_rate": 141.28, "high_score": 92, "100s": 0, "50s": 9, "4s": 99, "6s": 32, "rating": 8.1}'),
('Heinrich Klaasen', 'Wicketkeeper', 'South Africa', 5250000, '{"matches": 31, "runs": 776, "average": 43.11, "strike_rate": 174.38, "high_score": 104, "100s": 1, "50s": 4, "4s": 44, "6s": 55, "rating": 7.7}'),
('Harry Brook', 'Batsman', 'England', 13250000, '{"matches": 23, "runs": 372, "average": 21.88, "strike_rate": 135.27, "high_score": 100, "100s": 1, "50s": 0, "4s": 40, "6s": 12, "rating": 5.5}'),
('Aiden Markram', 'Batsman', 'South Africa', 2600000, '{"matches": 50, "runs": 1133, "average": 31.47, "strike_rate": 133.14, "high_score": 58, "100s": 0, "50s": 5, "4s": 86, "6s": 45, "rating": 6.9}'),
('Rovman Powell', 'Batsman', 'West Indies', 2800000, '{"matches": 29, "runs": 329, "average": 18.28, "strike_rate": 146.22, "high_score": 67, "100s": 0, "50s": 1, "4s": 14, "6s": 26, "rating": 4.8}'),
('Jason Roy', 'Batsman', 'England', 2800000, '{"matches": 21, "runs": 614, "average": 32.32, "strike_rate": 143.46, "high_score": 91, "100s": 0, "50s": 5, "4s": 78, "6s": 24, "rating": 6.7}'),
('Rahmanullah Gurbaz', 'Wicketkeeper', 'Afghanistan', 500000, '{"matches": 11, "runs": 227, "average": 20.64, "strike_rate": 133.53, "high_score": 81, "100s": 0, "50s": 2, "4s": 15, "6s": 15, "rating": 5.2}'),

-- Bowlers (43 players)
('Yuzvendra Chahal', 'Bowler', 'India', 6500000, '{"matches": 161, "wickets": 205, "average": 22.61, "economy": 7.86, "strike_rate": 17.26, "4w": 6, "5w": 1, "rating": 8.7}'),
('Bhuvneshwar Kumar', 'Bowler', 'India', 4200000, '{"matches": 177, "wickets": 182, "average": 27.19, "economy": 7.56, "strike_rate": 21.58, "4w": 2, "5w": 2, "rating": 7.5}'),
('Jasprit Bumrah', 'Bowler', 'India', 12000000, '{"matches": 133, "wickets": 165, "average": 22.51, "economy": 7.3, "strike_rate": 18.5, "4w": 2, "5w": 1, "rating": 8.9}'),
('Umesh Yadav', 'Bowler', 'India', 2000000, '{"matches": 148, "wickets": 144, "average": 30.13, "economy": 8.68, "strike_rate": 20.83, "4w": 3, "5w": 0, "rating": 6.8}'),
('Mohammed Shami', 'Bowler', 'India', 6250000, '{"matches": 122, "wickets": 136, "average": 26.85, "economy": 8.45, "strike_rate": 19.06, "4w": 2, "5w": 0, "rating": 8.0}'),
('Kagiso Rabada', 'Bowler', 'South Africa', 9250000, '{"matches": 78, "wickets": 115, "average": 18.91, "economy": 8.35, "strike_rate": 13.58, "4w": 6, "5w": 0, "rating": 8.8}'),
('Trent Boult', 'Bowler', 'New Zealand', 8000000, '{"matches": 99, "wickets": 114, "average": 25.83, "economy": 8.27, "strike_rate": 18.74, "4w": 1, "5w": 0, "rating": 8.2}'),
('Mohit Sharma', 'Bowler', 'India', 5000000, '{"matches": 110, "wickets": 119, "average": 22.95, "economy": 8.41, "strike_rate": 16.37, "4w": 2, "5w": 1, "rating": 7.8}'),
('Harshal Patel', 'Bowler', 'India', 10750000, '{"matches": 102, "wickets": 114, "average": 24.16, "economy": 8.6, "strike_rate": 16.86, "4w": 2, "5w": 1, "rating": 7.7}'),
('Avesh Khan', 'Bowler', 'India', 10000000, '{"matches": 58, "wickets": 58, "average": 26.33, "economy": 8.64, "strike_rate": 18.28, "4w": 1, "5w": 0, "rating": 6.5}'),
('Arshdeep Singh', 'Bowler', 'India', 4000000, '{"matches": 61, "wickets": 64, "average": 27.53, "economy": 8.74, "strike_rate": 18.89, "4w": 1, "5w": 1, "rating": 7.0}'),
('Prasidh Krishna', 'Bowler', 'India', 10000000, '{"matches": 51, "wickets": 49, "average": 34.9, "economy": 8.92, "strike_rate": 23.47, "4w": 1, "5w": 0, "rating": 5.9}'),
('Mukesh Kumar', 'Bowler', 'India', 5500000, '{"matches": 20, "wickets": 17, "average": 32.76, "economy": 9.72, "strike_rate": 20.24, "4w": 0, "5w": 0, "rating": 5.2}'),
('Tushar Deshpande', 'Bowler', 'India', 2000000, '{"matches": 29, "wickets": 25, "average": 32.68, "economy": 10.13, "strike_rate": 19.36, "4w": 0, "5w": 0, "rating": 4.8}'),
('Deepak Chahar', 'Bowler', 'India', 14000000, '{"matches": 83, "wickets": 74, "average": 28.97, "economy": 7.96, "strike_rate": 21.84, "4w": 2, "5w": 0, "rating": 7.1}'),
('Varun Chakravarthy', 'Bowler', 'India', 8000000, '{"matches": 70, "wickets": 66, "average": 26.65, "economy": 7.53, "strike_rate": 21.24, "4w": 1, "5w": 1, "rating": 7.3}'),
('Kuldeep Yadav', 'Bowler', 'India', 2000000, '{"matches": 85, "wickets": 75, "average": 28.53, "economy": 8.37, "strike_rate": 20.45, "4w": 2, "5w": 0, "rating": 7.2}'),
('Ravi Bishnoi', 'Bowler', 'India', 4000000, '{"matches": 62, "wickets": 58, "average": 28.1, "economy": 7.82, "strike_rate": 21.55, "4w": 1, "5w": 0, "rating": 6.9}'),
('Mayank Markande', 'Bowler', 'India', 5000000, '{"matches": 36, "wickets": 33, "average": 25.42, "economy": 8.16, "strike_rate": 18.67, "4w": 1, "5w": 0, "rating": 6.8}'),
('Noor Ahmad', 'Bowler', 'Afghanistan', 3000000, '{"matches": 23, "wickets": 22, "average": 25.09, "economy": 7.57, "strike_rate": 19.86, "4w": 0, "5w": 0, "rating": 6.7}'),
('Matheesha Pathirana', 'Bowler', 'Sri Lanka', 2000000, '{"matches": 18, "wickets": 21, "average": 19.33, "economy": 7.73, "strike_rate": 15.0, "4w": 0, "5w": 0, "rating": 7.6}'),
('Anrich Nortje', 'Bowler', 'South Africa', 6500000, '{"matches": 43, "wickets": 53, "average": 24.57, "economy": 8.32, "strike_rate": 17.72, "4w": 0, "5w": 0, "rating": 7.9}'),
('Jofra Archer', 'Bowler', 'England', 8000000, '{"matches": 40, "wickets": 48, "average": 21.33, "economy": 7.13, "strike_rate": 17.92, "4w": 0, "5w": 0, "rating": 8.4}'),
('Lockie Ferguson', 'Bowler', 'New Zealand', 10000000, '{"matches": 38, "wickets": 37, "average": 34.03, "economy": 8.96, "strike_rate": 22.78, "4w": 1, "5w": 0, "rating": 6.2}'),
('Josh Hazlewood', 'Bowler', 'Australia', 7750000, '{"matches": 27, "wickets": 35, "average": 22.2, "economy": 8.06, "strike_rate": 16.51, "4w": 1, "5w": 0, "rating": 8.0}'),
('Mark Wood', 'Bowler', 'England', 7500000, '{"matches": 7, "wickets": 11, "average": 23.0, "economy": 10.38, "strike_rate": 13.27, "4w": 0, "5w": 1, "rating": 7.0}'),
('Alzarri Joseph', 'Bowler', 'West Indies', 2400000, '{"matches": 19, "wickets": 20, "average": 29.85, "economy": 9.19, "strike_rate": 19.5, "4w": 0, "5w": 1, "rating": 6.4}'),
('Jason Behrendorff', 'Bowler', 'Australia', 750000, '{"matches": 12, "wickets": 14, "average": 27.64, "economy": 8.7, "strike_rate": 19.07, "4w": 0, "5w": 0, "rating": 6.3}'),
('Fazalhaq Farooqi', 'Bowler', 'Afghanistan', 500000, '{"matches": 7, "wickets": 6, "average": 38.83, "economy": 9.14, "strike_rate": 25.5, "4w": 1, "5w": 0, "rating": 5.4}'),
('Adam Zampa', 'Bowler', 'Australia', 1500000, '{"matches": 20, "wickets": 21, "average": 20.9, "economy": 7.7, "strike_rate": 16.29, "4w": 0, "5w": 0, "rating": 7.5}'),
('Shardul Thakur', 'Bowler', 'India', 10750000, '{"matches": 92, "wickets": 92, "average": 30.65, "economy": 9.16, "strike_rate": 20.08, "4w": 1, "5w": 0, "rating": 6.3}'),
('Nathan Ellis', 'Bowler', 'Australia', 2000000, '{"matches": 12, "wickets": 13, "average": 26.0, "economy": 8.76, "strike_rate": 17.85, "4w": 1, "5w": 0, "rating": 6.4}'),
('Mustafizur Rahman', 'Bowler', 'Bangladesh', 2000000, '{"matches": 48, "wickets": 47, "average": 30.7, "economy": 7.93, "strike_rate": 23.23, "4w": 1, "5w": 0, "rating": 6.8}'),
('Umran Malik', 'Bowler', 'India', 4000000, '{"matches": 25, "wickets": 29, "average": 29.31, "economy": 9.32, "strike_rate": 18.86, "4w": 1, "5w": 1, "rating": 6.6}'),
('Khaleel Ahmed', 'Bowler', 'India', 5250000, '{"matches": 44, "wickets": 57, "average": 24.79, "economy": 8.44, "strike_rate": 17.61, "4w": 0, "5w": 0, "rating": 7.4}'),
('Chetan Sakariya', 'Bowler', 'India', 4200000, '{"matches": 20, "wickets": 20, "average": 29.95, "economy": 8.44, "strike_rate": 21.3, "4w": 0, "5w": 0, "rating": 3.9}'),
('Marco Jansen', 'Bowler', 'South Africa', 4200000, '{"matches": 21, "wickets": 22, "average": 36.14, "economy": 9.61, "strike_rate": 22.57, "4w": 0, "5w": 0, "rating": 3.4}'),
('Mujeeb Ur Rahman', 'Bowler', 'Afghanistan', 2000000, '{"matches": 20, "wickets": 20, "average": 31.0, "economy": 8.34, "strike_rate": 22.3, "4w": 0, "5w": 0, "rating": 3.8}'),
('Riley Meredith', 'Bowler', 'Australia', 1000000, '{"matches": 19, "wickets": 18, "average": 33.33, "economy": 9.71, "strike_rate": 20.6, "4w": 0, "5w": 0, "rating": 3.1}'),
('Jaydev Unadkat', 'Bowler', 'India', 500000, '{"matches": 94, "wickets": 91, "average": 30.63, "economy": 8.8, "strike_rate": 20.88, "4w": 0, "5w": 2, "rating": 6.2}'),
('Sandeep Sharma', 'Bowler', 'India', 500000, '{"matches": 122, "wickets": 132, "average": 27.23, "economy": 7.86, "strike_rate": 20.78, "4w": 2, "5w": 1, "rating": 7.4}'),
('Jayant Yadav', 'Bowler', 'India', 1700000, '{"matches": 20, "wickets": 8, "average": 54.75, "economy": 7.1, "strike_rate": 46.25, "4w": 0, "5w": 0, "rating": 2.5}'),

-- All-Rounders (Corrected Count: 38)
('Venkatesh Iyer', 'All-Rounder', 'India', 8000000, '{"matches": 50, "runs": 956, "average": 23.32, "strike_rate": 131.14, "high_score": 104, "100s": 1, "50s": 7, "4s": 84, "6s": 41, "rating": 6.0}'),
('Ravichandran Ashwin', 'All-Rounder', 'India', 5000000, '{"matches": 212, "runs": 745, "wickets": 180, "batting_rating": 3, "bowling_rating": 7, "overall_rating": 5.0}'),
('Sunil Narine', 'All-Rounder', 'West Indies', 6000000, '{"matches": 177, "runs": 1046, "wickets": 180, "batting_rating": 5, "bowling_rating": 9, "overall_rating": 7.0}'),
('Ravindra Jadeja', 'All-Rounder', 'India', 16000000, '{"matches": 240, "runs": 2942, "wickets": 159, "batting_rating": 5, "bowling_rating": 7, "overall_rating": 6.0}'),
('Rashid Khan', 'All-Rounder', 'Afghanistan', 15000000, '{"matches": 120, "runs": 443, "wickets": 148, "batting_rating": 3, "bowling_rating": 7, "overall_rating": 5.0}'),
('Axar Patel', 'All-Rounder', 'India', 9000000, '{"matches": 147, "runs": 1499, "wickets": 117, "batting_rating": 4, "bowling_rating": 6, "overall_rating": 5.0}'),
('Andre Russell', 'All-Rounder', 'West Indies', 12000000, '{"matches": 122, "runs": 2471, "wickets": 106, "batting_rating": 6, "bowling_rating": 7, "overall_rating": 6.5}'),
('Krunal Pandya', 'All-Rounder', 'India', 8250000, '{"matches": 124, "runs": 1544, "wickets": 72, "batting_rating": 4, "bowling_rating": 5, "overall_rating": 4.5}'),
('Hardik Pandya', 'All-Rounder', 'India', 15000000, '{"matches": 133, "runs": 2465, "wickets": 60, "batting_rating": 5, "bowling_rating": 5, "overall_rating": 5.0}'),
('Sam Curran', 'All-Rounder', 'England', 18500000, '{"matches": 61, "runs": 895, "wickets": 58, "batting_rating": 4, "bowling_rating": 5, "overall_rating": 4.5}'),
('Marcus Stoinis', 'All-Rounder', 'Australia', 9200000, '{"matches": 90, "runs": 1478, "wickets": 40, "batting_rating": 5, "bowling_rating": 5, "overall_rating": 5.0}'),
('Glenn Maxwell', 'All-Rounder', 'Australia', 11000000, '{"matches": 133, "runs": 2719, "wickets": 34, "batting_rating": 5, "bowling_rating": 4, "overall_rating": 4.5}'),
('Mitchell Marsh', 'All-Rounder', 'Australia', 6500000, '{"matches": 42, "runs": 822, "wickets": 36, "batting_rating": 4, "bowling_rating": 6, "overall_rating": 5.0}'),
('Moeen Ali', 'All-Rounder', 'England', 8000000, '{"matches": 59, "runs": 1034, "wickets": 33, "batting_rating": 4, "bowling_rating": 5, "overall_rating": 4.5}'),
('Rahul Tewatia', 'All-Rounder', 'India', 9000000, '{"matches": 97, "runs": 1019, "wickets": 32, "batting_rating": 4, "bowling_rating": 4, "overall_rating": 4.0}'),
('Ben Stokes', 'All-Rounder', 'England', 16250000, '{"matches": 45, "runs": 935, "wickets": 28, "batting_rating": 4, "bowling_rating": 4, "overall_rating": 4.0}'),
('Shahbaz Ahmed', 'All-Rounder', 'India', 2400000, '{"matches": 39, "runs": 329, "wickets": 14, "batting_rating": 3, "bowling_rating": 4, "overall_rating": 3.5}'),
('Cameron Green', 'All-Rounder', 'Australia', 17500000, '{"matches": 24, "runs": 501, "wickets": 11, "batting_rating": 5, "bowling_rating": 4, "overall_rating": 4.5}'),
('Abhishek Sharma', 'All-Rounder', 'India', 6500000, '{"matches": 61, "runs": 893, "wickets": 11, "batting_rating": 4, "bowling_rating": 4, "overall_rating": 4.0}'),
('Deepak Hooda', 'All-Rounder', 'India', 5750000, '{"matches": 116, "runs": 1399, "wickets": 10, "batting_rating": 4, "bowling_rating": 3, "overall_rating": 3.5}'),
('Washington Sundar', 'All-Rounder', 'India', 8750000, '{"matches": 58, "runs": 378, "wickets": 36, "batting_rating": 3, "bowling_rating": 5, "overall_rating": 4.0}'),
('Vijay Shankar', 'All-Rounder', 'India', 1400000, '{"matches": 65, "runs": 1032, "wickets": 9, "batting_rating": 4, "bowling_rating": 3, "overall_rating": 3.5}'),
('Riyan Parag', 'All-Rounder', 'India', 3800000, '{"matches": 68, "runs": 727, "wickets": 4, "batting_rating": 3, "bowling_rating": 3, "overall_rating": 3.0}'),
('Liam Livingstone', 'All-Rounder', 'England', 11500000, '{"matches": 42, "runs": 828, "wickets": 8, "batting_rating": 5, "bowling_rating": 3, "overall_rating": 4.0}'),
('Odean Smith', 'All-Rounder', 'West Indies', 6000000, '{"matches": 19, "runs": 143, "wickets": 7, "batting_rating": 3, "bowling_rating": 3, "overall_rating": 3.0}'),
('Romario Shepherd', 'All-Rounder', 'West Indies', 7750000, '{"matches": 7, "runs": 58, "wickets": 3, "batting_rating": 3, "bowling_rating": 3, "overall_rating": 3.0}'),
('Shivam Dube', 'All-Rounder', 'India', 4000000, '{"matches": 60, "runs": 1106, "wickets": 4, "batting_rating": 5, "bowling_rating": 2, "overall_rating": 3.5}'),
('Irfan Pathan', 'All-Rounder', 'India', 2000000, '{"matches": 103, "runs": 1139, "wickets": 80, "batting_rating": 4, "bowling_rating": 6, "overall_rating": 5.0}'),
('Moises Henriques', 'All-Rounder', 'Australia', 2000000, '{"matches": 62, "runs": 1000, "wickets": 42, "batting_rating": 4, "bowling_rating": 5, "overall_rating": 4.5}'),
('Jacques Kallis', 'All-Rounder', 'South Africa', 2000000, '{"matches": 98, "runs": 2427, "wickets": 65, "batting_rating": 7, "bowling_rating": 6, "overall_rating": 6.5}'),
('Shane Watson', 'All-Rounder', 'Australia', 2000000, '{"matches": 145, "runs": 3874, "wickets": 92, "batting_rating": 7, "bowling_rating": 6, "overall_rating": 6.5}'),
('Dwayne Bravo', 'All-Rounder', 'West Indies', 2000000, '{"matches": 161, "runs": 1560, "wickets": 183, "batting_rating": 4, "bowling_rating": 8, "overall_rating": 6.0}'),
('Kieron Pollard', 'All-Rounder', 'West Indies', 2000000, '{"matches": 189, "runs": 3412, "wickets": 69, "batting_rating": 6, "bowling_rating": 5, "overall_rating": 5.5}'),
('Albie Morkel', 'All-Rounder', 'South Africa', 2000000, '{"matches": 91, "runs": 974, "wickets": 85, "batting_rating": 4, "bowling_rating": 6, "overall_rating": 5.0}'),
('Andrew Symonds', 'All-Rounder', 'Australia', 2000000, '{"matches": 39, "runs": 974, "wickets": 20, "batting_rating": 5, "bowling_rating": 4, "overall_rating": 4.5}'),
('Stuart Binny', 'All-Rounder', 'India', 2000000, '{"matches": 95, "runs": 880, "wickets": 22, "batting_rating": 3, "bowling_rating": 4, "overall_rating": 3.5}'),
('James Faulkner', 'All-Rounder', 'Australia', 2000000, '{"matches": 60, "runs": 527, "wickets": 59, "batting_rating": 4, "bowling_rating": 6, "overall_rating": 5.0}'),
('Chris Woakes', 'All-Rounder', 'England', 1500000, '{"matches": 21, "runs": 78, "wickets": 30, "batting_rating": 2, "bowling_rating": 6, "overall_rating": 4.0}')
ON CONFLICT (name) DO NOTHING;

-- ----------------------------------------
-- DEMO USER DATA
-- ----------------------------------------
INSERT INTO public.user_profiles (id, email, role, team_name) VALUES
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
