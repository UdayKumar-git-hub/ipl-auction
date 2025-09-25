import React, { useState, useEffect } from 'react';
import { Trophy, Users, DollarSign, TrendingUp } from 'lucide-react';
import { Player, Team } from '../../types';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../hooks/useAuth';
import toast from 'react-hot-toast';

export function TeamDashboard() {
  const { user } = useAuth();
  const [team, setTeam] = useState<Team | null>(null);
  const [players, setPlayers] = useState<Player[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (user?.team_name) {
      fetchTeamData();
    }
  }, [user]);

  const fetchTeamData = async () => {
    if (!user?.team_name) return;

    try {
      // Fetch team info
      const { data: teamData, error: teamError } = await supabase
        .from('teams')
        .select('*')
        .eq('name', user.team_name)
        .single();

      if (teamError) throw teamError;

      // Fetch team players
      const { data: playersData, error: playersError } = await supabase
        .from('players')
        .select('*')
        .eq('team_id', teamData.id)
        .eq('is_sold', true);

      if (playersError) throw playersError;

      setTeam(teamData);
      setPlayers(playersData || []);
    } catch (error) {
      console.error('Error fetching team data:', error);
      toast.error('Error loading team data');
    } finally {
      setLoading(false);
    }
  };

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
        <p className="text-gray-500">Please contact admin to set up your team</p>
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
      {/* Team Header */}
      <div className="bg-gradient-to-r from-yellow-500 to-yellow-600 rounded-2xl p-8 mb-8 text-black">
        <div className="flex items-center space-x-6">
          <img
            src={team.logo_url}
            alt={team.name}
            className="w-24 h-24 rounded-full object-cover bg-white p-2"
          />
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
              <p className="text-2xl font-bold text-gray-900">
                ₹{players.length > 0 ? ((totalSpent / players.length) / 1000000).toFixed(1) : 0}L
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Squad by Role */}
      <div className="space-y-8">
        {Object.entries(playersByRole).map(([role, rolePlayers]) => (
          <div key={role} className="bg-white rounded-xl shadow-lg p-6">
            <h2 className="text-xl font-bold text-gray-900 mb-4">
              {role}s ({rolePlayers.length})
            </h2>
            
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
                      <img
                        src={player.photo_url}
                        alt={player.name}
                        className="w-12 h-12 rounded-full object-cover"
                      />
                      <div className="flex-1">
                        <h3 className="font-medium text-gray-900">{player.name}</h3>
                        <p className="text-sm text-gray-500">{player.country}</p>
                        <p className="text-sm font-medium text-green-600">
                          ₹{player.current_price?.toLocaleString()}
                        </p>
                      </div>
                    </div>
                    
                    <div className="mt-3 pt-3 border-t border-gray-200">
                      <div className="grid grid-cols-2 gap-2 text-sm">
                        <div>
                          <span className="text-gray-500">Matches:</span>
                          <span className="font-medium ml-1">{player.stats.matches}</span>
                        </div>
                        {player.stats.runs && (
                          <div>
                            <span className="text-gray-500">Runs:</span>
                            <span className="font-medium ml-1">{player.stats.runs}</span>
                          </div>
                        )}
                        {player.stats.wickets && (
                          <div>
                            <span className="text-gray-500">Wickets:</span>
                            <span className="font-medium ml-1">{player.stats.wickets}</span>
                          </div>
                        )}
                        {player.stats.average && (
                          <div>
                            <span className="text-gray-500">Average:</span>
                            <span className="font-medium ml-1">{player.stats.average}</span>
                          </div>
                        )}
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
          <div 
            className="bg-gradient-to-r from-yellow-500 to-yellow-600 h-6 rounded-full" 
            style={{ width: `${(totalSpent / team.total_purse) * 100}%` }}
          ></div>
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