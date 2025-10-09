export interface User {
  id: string;
  email: string;
  role: 'admin' | 'team';
  team_name?: string;
}

export interface Player {
  id: string;
  name: string;
  role: 'Batsman' | 'Bowler' | 'All-Rounder' | 'Wicketkeeper';
  country: string;
  base_price: number;
  current_price?: number;
  photo_url: string;
  stats: {
    matches: number;
    runs?: number;
    wickets?: number;
    average?: number;
  };
  team_id?: string;
  is_sold: boolean;
  auction_event_id: string;
  created_at: string;
}

export interface Team {
  id: string;
  name: string;
  short_name: string;
  logo_url: string;
  purse_remaining: number;
  total_purse: number;
  players_count: number;
  created_at: string;
}

export interface Auction {
  id: string;
  player_id: string;
  current_price: number;
  is_active: boolean;
  winning_team_id?: string;
  created_at: string;
  updated_at: string;
}