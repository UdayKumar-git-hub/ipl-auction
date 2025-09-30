import React, { useState, useEffect, useCallback } from 'react';
import { Trophy, Users, DollarSign, TrendingUp, Eye, Gavel } from 'lucide-react';
import { Player, Team } from '../../types';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../hooks/useAuth';
import toast from 'react-hot-toast';

export function TeamDashboard() {
  const { user } = useAuth();
  const [team, setTeam] = useState<Team | null>(null);
  const [players, setPlayers] = useState<Player[]>([]);
  const [currentAuctionPlayer, setCurrentAuctionPlayer] = useState<Player | null>(null);
  const [currentBid, setCurrentBid] = useState(0);
  const [loading, setLoading] = useState(true);

  const fetchTeamData = useCallback(async () => {
    if (!user?.team_name) {
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      
      // Fetch team data
      const { data: teamData, error: teamError } = await supabase
        .from('teams')
        .select('*')
        .eq('name', user.team_name)
        .single();

      if (teamError) {
        console.error('Team fetch error:', teamError);
        toast.error('Error loading team data');
        return;
      }

      setTeam(teamData);

      // Fetch team's players
      const { data: playersData, error: playersError } = await supabase
        .from('players')
        .select('*')
        .eq('team_id', teamData.id)
        .eq('is_sold', true);

      if (playersError) {
        console.error('Players fetch error:', playersError);
        toast.error('Error loading players data');
        return;
      }

      setPlayers(playersData || []);

    } catch (error: any) {
      console.error('Error fetching team data:', error);
      toast.error(`Error loading data: ${error.message}`);
    } finally {
      setLoading(false);
    }
  }, [user?.team_name]);

  const fetchCurrentAuction = useCallback(async () => {
    try {
      const { data: auctionData, error: auctionError } = await supabase
        .from('current_auction')
        .select(`
          *,
          players (
            id,
            name,
            role,
            country,
            base_price,
            photo_url,
            stats
          )
        `)
        .eq('is_active', true)
        .single();

      if (auctionError && auctionError.code !== 'PGRST116') {
        console.error('Current auction fetch error:', auctionError);
        return;
      }

      if (auctionData && auctionData.players) {
        setCurrentAuctionPlayer(auctionData.players as Player);
        setCurrentBid(auctionData.current_price || 0);
      } else {
        setCurrentAuctionPlayer(null);
        setCurrentBid(0);
      }
    } catch (error) {
      console.error('Error fetching current auction:', error);
    }
  }, []);

  useEffect(() => {
    fetchTeamData();
    fetchCurrentAuction();
  }, [fetchTeamData, fetchCurrentAuction]);

  // Real-time subscription for team updates
  useEffect(() => {
    if (!team?.id) return;

    const channel = supabase
      .channel(`team_dashboard_${team.id}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'players',
          filter: `team_id=eq.${team.id}`,
        },
        () => {
          fetchTeamData();
        }
      )
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'teams',
          filter: `id=eq.${team.id}`,
        },
        () => {
          fetchTeamData();
        }
      )
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'current_auction',
        },
        () => {
          fetchCurrentAuction();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [team?.id, fetchTeamData, fetchCurrentAuction]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-yellow-500"></div>
      </div>
    );
  }

  if (!team) {
    return (
      <div className="text-center py-12">
        <Trophy className="h-16 w-16 text-gray-400 mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-gray-600">Team not found</h3>
        <p className="text-gray-500">Please check your team setup or contact an admin.</p>
      </div>
    );
  }

  const playersByRole = {
    'Batsman': players.filter(p => p.role === 'Batsman'),
    'Bowler': players.filter(p => p.role === 'Bowler'),
    'All-Rounder': players.filter(p => p.role === 'All-Rounder'),
    'Wicketkeeper': players.filter(p => p.role === 'Wicketkeeper'),
  };

  const totalSpent = team.total_purse - team.purse_remaining;

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* Live Auction Display */}
      {currentAuctionPlayer && (
        <div className="bg-gradient-to-r from-red-500 to-red-600 rounded-2xl p-6 mb-8 text-white">
          <div className="flex items-center space-x-3 mb-4">
            <Gavel className="h-6 w-6 animate-bounce" />
            <h2 className="text-xl font-bold">LIVE AUCTION</h2>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <img
                src={currentAuctionPlayer.photo_url}
                alt={currentAuctionPlayer.name}
                className="w-full h-48 object-cover rounded-lg"
              />
            </div>
            <div className="space-y-3">
              <div>
                <h3 className="text-2xl font-bold">{currentAuctionPlayer.name}</h3>
                <p className="text-lg opacity-90">{currentAuctionPlayer.role} • {currentAuctionPlayer.country}</p>
              </div>
              <div className="bg-white/20 rounded-lg p-3">
                <p className="text-sm opacity-80">Base Price</p>
                <p className="text-lg font-bold">₹{currentAuctionPlayer.base_price.toLocaleString()}</p>
              </div>
              <div className="bg-white/30 rounded-lg p-3">
                <p className="text-sm opacity-80">Current Bid</p>
                <p className="text-2xl font-bold">₹{currentBid.toLocaleString()}</p>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Team Header */}
      <div className="bg-gradient-to-r from-yellow-500 to-yellow-600 rounded-2xl p-8 mb-8 text-black">
        <div className="flex items-center space-x-6">
          <img src={team.logo_url} alt={team.name} className="w-24 h-24 rounded-full object-cover bg-white p-2" />
          <div>
            <h1 className="text-4xl font-bold">{team.name}</h1>
            <p className="text-xl opacity-80">{team.short_name}</p>
          </div>
        </div>
      </div>

      {/* Stats Overview */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <div className="bg-white rounded-xl shadow-lg p-6 border-l-4 border-blue-500">
          <div className="flex items-center">
            <Users className="h-8 w-8 text-blue-600" />
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Squad Size</p>
              <p className="text-2xl font-bold text-gray-900">{players.length}/25</p>
            </div>
          </div>
        </div>
        <div className="bg-white rounded-xl shadow-lg p-6 border-l-4 border-green-500">
          <div className="flex items-center">
            <DollarSign className="h-8 w-8 text-green-600" />
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Purse Remaining</p>
              <p className="text-2xl font-bold text-gray-900">₹{(team.purse_remaining / 10000000).toFixed(1)}Cr</p>
            </div>
          </div>
        </div>
        <div className="bg-white rounded-xl shadow-lg p-6 border-l-4 border-yellow-500">
          <div className="flex items-center">
            <TrendingUp className="h-8 w-8 text-yellow-600" />
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Amount Spent</p>
              <p className="text-2xl font-bold text-gray-900">₹{(totalSpent / 10000000).toFixed(1)}Cr</p>
            </div>
          </div>
        </div>
        <div className="bg-white rounded-xl shadow-lg p-6 border-l-4 border-purple-500">
          <div className="flex items-center">
            <Trophy className="h-8 w-8 text-purple-600" />
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Avg Price</p>
              <p className="text-2xl font-bold text-gray-900">₹{players.length > 0 ? ((totalSpent / players.length) / 1000000).toFixed(1) : 0}L</p>
            </div>
          </div>
        </div>
      </div>

      {/* Squad by Role */}
      <div className="space-y-8">
        {Object.entries(playersByRole).map(([role, rolePlayers]) => (
          <div key={role} className="bg-white rounded-xl shadow-lg p-6">
            <h2 className="text-xl font-bold text-gray-900 mb-4">{role}s ({rolePlayers.length})</h2>
            {rolePlayers.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                <Users className="h-12 w-12 mx-auto mb-2 opacity-50" />
                <p>No {role.toLowerCase()}s acquired yet</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {rolePlayers.map(player => (
                  <div key={player.id} className="bg-gray-50 rounded-lg p-4 hover:bg-gray-100 transition-colors">
                    <div className="flex items-center space-x-3">
                      <img src={player.photo_url} alt={player.name} className="w-12 h-12 rounded-full object-cover" />
                      <div className="flex-1">
                        <h3 className="font-medium text-gray-900">{player.name}</h3>
                        <p className="text-sm text-gray-500">{player.country}</p>
                        <p className="text-sm font-medium text-green-600">₹{player.current_price?.toLocaleString()}</p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        ))}
      </div>

      {/* Purse Breakdown */}
      <div className="mt-8 bg-white rounded-xl shadow-lg p-6">
        <h2 className="text-xl font-bold text-gray-900 mb-4">Purse Analysis</h2>
        <div className="w-full bg-gray-200 rounded-full h-6 mb-4">
          <div className="bg-gradient-to-r from-yellow-500 to-yellow-600 h-6 rounded-full" style={{ width: `${(totalSpent / team.total_purse) * 100}%` }}></div>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-center">
          <div>
            <p className="text-sm text-gray-500">Total Purse</p>
            <p className="text-lg font-bold text-gray-900">₹{(team.total_purse / 10000000).toFixed(1)}Cr</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Amount Spent</p>
            <p className="text-lg font-bold text-red-600">₹{(totalSpent / 10000000).toFixed(1)}Cr</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Remaining</p>
            <p className="text-lg font-bold text-green-600">₹{(team.purse_remaining / 10000000).toFixed(1)}Cr</p>
          </div>
        </div>
      </div>
    </div>
  );
}