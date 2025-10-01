import React, { useState, useEffect } from 'react';
import { Users, Trophy, DollarSign, Plus, Search, Play, Shuffle, Eye, Gavel } from 'lucide-react';
import { Player, Team } from '../../types';
import { supabase } from '../../lib/supabase';
import { PlayerCard } from './PlayerCard';
import { TeamCard } from './TeamCard';
import { AddPlayerModal } from './AddPlayerModal';
import { EditTeamModal } from './EditTeamModal';
import toast from 'react-hot-toast';

export function AdminDashboard() {
  const [activeTab, setActiveTab] = useState<'overview' | 'players' | 'teams' | 'auction'>('overview');
  const [players, setPlayers] = useState<Player[]>([]);
  const [teams, setTeams] = useState<Team[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [roleFilter, setRoleFilter] = useState<string>('all');
  const [showAddPlayer, setShowAddPlayer] = useState(false);
  const [showEditTeam, setShowEditTeam] = useState(false);
  const [selectedTeam, setSelectedTeam] = useState<Team | null>(null);
  
  // Auction state
  const [currentAuctionPlayer, setCurrentAuctionPlayer] = useState<Player | null>(null);
  const [currentBid, setCurrentBid] = useState(0);
  const [selectedTeamId, setSelectedTeamId] = useState('');
  const [auctionLoading, setAuctionLoading] = useState(false);

  useEffect(() => {
    fetchData();
    fetchCurrentAuction();
  }, []);

  const fetchData = async () => {
    try {
      setLoading(true);
      const [playersResponse, teamsResponse] = await Promise.all([
        supabase.from('players').select('*').order('name'),
        supabase.from('teams').select('*').order('name')
      ]);

      if (playersResponse.error) throw playersResponse.error;
      if (teamsResponse.error) throw teamsResponse.error;

      setPlayers(playersResponse.data || []);
      setTeams(teamsResponse.data || []);
    } catch (error) {
      console.error('Error fetching data:', error);
      toast.error('Error loading data');
    } finally {
      setLoading(false);
    }
  };

  const fetchCurrentAuction = async () => {
    try {
      const { data: auctionData, error } = await supabase
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

      if (error && error.code !== 'PGRST116') {
        console.error('Current auction fetch error:', error);
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
  };

  const selectRandomPlayer = () => {
    const unsoldPlayers = players.filter(p => !p.is_sold);
    if (unsoldPlayers.length === 0) {
      toast.error('No players available for selection');
      return;
    }
    
    const randomIndex = Math.floor(Math.random() * unsoldPlayers.length);
    const randomPlayer = unsoldPlayers[randomIndex];
    startAuction(randomPlayer);
  };

  const startAuction = async (player: Player) => {
    setAuctionLoading(true);
    try {
      // Update current_auction table
      const { error } = await supabase
        .from('current_auction')
        .upsert({
          id: '00000000-0000-0000-0000-000000000000', // Use a fixed ID for single row
          player_id: player.id,
          current_price: player.base_price,
          is_active: true,
          updated_at: new Date().toISOString()
        });

      if (error) throw error;

      setCurrentAuctionPlayer(player);
      setCurrentBid(player.base_price);
      setSelectedTeamId('');
      toast.success(`Auction started for ${player.name}`);
    } catch (error) {
      console.error('Error starting auction:', error);
      toast.error('Error starting auction');
    } finally {
      setAuctionLoading(false);
    }
  };

  const updateBid = async (amount: number) => {
    const newBid = Math.max(currentBid + amount, currentAuctionPlayer?.base_price || 0);
    setCurrentBid(newBid);

    try {
      await supabase
        .from('current_auction')
        .update({ current_price: newBid })
        .eq('is_active', true);
    } catch (error) {
      console.error('Error updating bid:', error);
    }
  };

  const soldPlayer = async () => {
    if (!currentAuctionPlayer || !selectedTeamId) {
      toast.error('Please select a team');
      return;
    }

    setAuctionLoading(true);
    try {
      const team = teams.find(t => t.id === selectedTeamId);
      if (!team) throw new Error('Team not found');

      if (team.purse_remaining < currentBid) {
        toast.error('Team does not have enough purse remaining');
        return;
      }

      // Update player
      await supabase
        .from('players')
        .update({
          is_sold: true,
          current_price: currentBid,
          team_id: selectedTeamId
        })
        .eq('id', currentAuctionPlayer.id);

      // Update team
      await supabase
        .from('teams')
        .update({
          purse_remaining: team.purse_remaining - currentBid,
          players_count: team.players_count + 1
        })
        .eq('id', selectedTeamId);

      // End auction
      await supabase
        .from('current_auction')
        .update({ is_active: false })
        .eq('is_active', true);

      toast.success(`${currentAuctionPlayer.name} sold to ${team.name} for ₹${currentBid.toLocaleString()}`);
      resetAuction();
      fetchData();
    } catch (error) {
      console.error('Error selling player:', error);
      toast.error('Error selling player');
    } finally {
      setAuctionLoading(false);
    }
  };

  const unsoldPlayer = async () => {
    if (!currentAuctionPlayer) return;

    setAuctionLoading(true);
    try {
      await supabase
        .from('current_auction')
        .update({ is_active: false })
        .eq('is_active', true);

      toast.info(`${currentAuctionPlayer.name} went unsold`);
      resetAuction();
    } catch (error) {
      console.error('Error marking player unsold:', error);
      toast.error('Error processing player');
    } finally {
      setAuctionLoading(false);
    }
  };

  const resetAuction = () => {
    setCurrentAuctionPlayer(null);
    setCurrentBid(0);
    setSelectedTeamId('');
  };

  const filteredPlayers = players.filter(player => {
    const matchesSearch = player.name.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesRole = roleFilter === 'all' || player.role === roleFilter;
    return matchesSearch && matchesRole;
  });

  const unsoldPlayers = players.filter(p => !p.is_sold);

  const filteredUnsoldPlayers = unsoldPlayers.filter(player =>
    player.name.toLowerCase().includes(playerSearchTerm.toLowerCase()) ||
    player.role.toLowerCase().includes(playerSearchTerm.toLowerCase()) ||
    player.country.toLowerCase().includes(playerSearchTerm.toLowerCase())
  );

  const stats = {
    totalPlayers: players.length,
    soldPlayers: players.filter(p => p.is_sold).length,
    totalTeams: teams.length,
    totalPurseSpent: teams.reduce((sum, team) => sum + (team.total_purse - team.purse_remaining), 0),
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-yellow-500"></div>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* Navigation Tabs */}
      <div className="mb-8">
        <div className="border-b border-gray-200">
          <nav className="-mb-px flex space-x-8">
            {[
              { key: 'overview', label: 'Overview', icon: Trophy },
              { key: 'players', label: 'Players', icon: Users },
              { key: 'teams', label: 'Teams', icon: Trophy },
              { key: 'auction', label: 'Live Auction', icon: Gavel },
            ].map(({ key, label, icon: Icon }) => (
              <button
                key={key}
                onClick={() => setActiveTab(key as any)}
                className={`flex items-center space-x-2 py-4 px-1 border-b-2 font-medium text-sm ${
                  activeTab === key
                    ? 'border-yellow-500 text-yellow-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                <Icon className="h-4 w-4" />
                <span>{label}</span>
              </button>
            ))}
          </nav>
        </div>
      </div>

      {/* Overview Tab */}
      {activeTab === 'overview' && (
        <div className="space-y-8">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div className="bg-white rounded-xl shadow-lg p-6 border-l-4 border-yellow-500">
              <div className="flex items-center">
                <Users className="h-8 w-8 text-yellow-600" />
                <div className="ml-4">
                  <p className="text-sm font-medium text-gray-600">Total Players</p>
                  <p className="text-2xl font-bold text-gray-900">{stats.totalPlayers}</p>
                </div>
              </div>
            </div>
            
            <div className="bg-white rounded-xl shadow-lg p-6 border-l-4 border-green-500">
              <div className="flex items-center">
                <Trophy className="h-8 w-8 text-green-600" />
                <div className="ml-4">
                  <p className="text-sm font-medium text-gray-600">Players Sold</p>
                  <p className="text-2xl font-bold text-gray-900">{stats.soldPlayers}</p>
                </div>
              </div>
            </div>
            
            <div className="bg-white rounded-xl shadow-lg p-6 border-l-4 border-blue-500">
              <div className="flex items-center">
                <Trophy className="h-8 w-8 text-blue-600" />
                <div className="ml-4">
                  <p className="text-sm font-medium text-gray-600">Teams</p>
                  <p className="text-2xl font-bold text-gray-900">{stats.totalTeams}</p>
                </div>
              </div>
            </div>
            
            <div className="bg-white rounded-xl shadow-lg p-6 border-l-4 border-red-500">
              <div className="flex items-center">
                <DollarSign className="h-8 w-8 text-red-600" />
                <div className="ml-4">
                  <p className="text-sm font-medium text-gray-600">Purse Spent</p>
                  <p className="text-2xl font-bold text-gray-900">₹{(stats.totalPurseSpent / 10000000).toFixed(1)}Cr</p>
                </div>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <div className="bg-white rounded-xl shadow-lg p-6">
              <h3 className="text-lg font-bold text-gray-900 mb-4">Recent Player Sales</h3>
              <div className="space-y-3">
                {players.filter(p => p.is_sold).slice(0, 5).map(player => (
                  <div key={player.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                    <div>
                      <p className="font-medium text-gray-900">{player.name}</p>
                      <p className="text-sm text-gray-500">{player.role}</p>
                    </div>
                    <div className="text-right">
                      <p className="font-bold text-green-600">₹{player.current_price?.toLocaleString()}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div className="bg-white rounded-xl shadow-lg p-6">
              <h3 className="text-lg font-bold text-gray-900 mb-4">Team Purse Status</h3>
              <div className="space-y-3">
                {teams.slice(0, 5).map(team => (
                  <div key={team.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                    <div>
                      <p className="font-medium text-gray-900">{team.short_name}</p>
                      <p className="text-sm text-gray-500">{team.players_count} players</p>
                    </div>
                    <div className="text-right">
                      <p className="font-bold text-blue-600">₹{(team.purse_remaining / 10000000).toFixed(1)}Cr</p>
                      <div className="w-20 bg-gray-200 rounded-full h-2">
                        <div 
                          className="bg-yellow-500 h-2 rounded-full" 
                          style={{ width: `${((team.total_purse - team.purse_remaining) / team.total_purse) * 100}%` }}
                        ></div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Players Tab */}
      {activeTab === 'players' && (
        <div className="space-y-6">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
            <h2 className="text-2xl font-bold text-gray-900">Player Management</h2>
            <button 
              onClick={() => setShowAddPlayer(true)}
              className="bg-yellow-500 hover:bg-yellow-600 text-black font-medium px-4 py-2 rounded-lg flex items-center space-x-2 transition-colors"
            >
              <Plus className="h-4 w-4" />
              <span>Add Player</span>
            </button>
          </div>

          <div className="flex flex-col sm:flex-row gap-4">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-3 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search players..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
              />
            </div>
            <select
              value={roleFilter}
              onChange={(e) => setRoleFilter(e.target.value)}
              className="px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
            >
              <option value="all">All Roles</option>
              <option value="Batsman">Batsman</option>
              <option value="Bowler">Bowler</option>
              <option value="All-Rounder">All-Rounder</option>
              <option value="Wicketkeeper">Wicketkeeper</option>
            </select>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredPlayers.map(player => (
              <PlayerCard key={player.id} player={player} onUpdate={fetchData} />
            ))}
          </div>
        </div>
      )}

      {/* Teams Tab */}
      {activeTab === 'teams' && (
        <div className="space-y-6">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
            <h2 className="text-2xl font-bold text-gray-900">Team Management</h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {teams.map(team => (
              <div key={team.id} className="bg-white rounded-xl shadow-lg overflow-hidden hover:shadow-xl transition-shadow border-2 border-gray-200">
                <div className="relative">
                  <img
                    src={team.logo_url}
                    alt={team.name}
                    className="w-full h-32 object-cover bg-gradient-to-r from-yellow-400 to-yellow-500"
                  />
                  <div className="absolute inset-0 bg-black/20"></div>
                  <div className="absolute bottom-4 left-4">
                    <h3 className="text-xl font-bold text-white">{team.short_name}</h3>
                  </div>
                </div>

                <div className="p-4">
                  <h4 className="text-lg font-semibold text-gray-900 mb-3">{team.name}</h4>
                  
                  <div className="space-y-3">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center space-x-2 text-sm text-gray-600">
                        <Users className="h-4 w-4" />
                        <span>Players</span>
                      </div>
                      <span className="font-medium">{team.players_count}/25</span>
                    </div>

                    <div className="flex items-center justify-between">
                      <div className="flex items-center space-x-2 text-sm text-gray-600">
                        <DollarSign className="h-4 w-4" />
                        <span>Purse Remaining</span>
                      </div>
                      <span className="font-medium">₹{(team.purse_remaining / 10000000).toFixed(1)}Cr</span>
                    </div>

                    <div className="w-full bg-gray-200 rounded-full h-3">
                      <div 
                        className="bg-gradient-to-r from-yellow-500 to-yellow-600 h-3 rounded-full transition-all duration-300" 
                        style={{ width: `${Math.min(((team.total_purse - team.purse_remaining) / team.total_purse) * 100, 100)}%` }}
                      ></div>
                    </div>
                  </div>

                  <button 
                    onClick={() => {
                      setSelectedTeam(team);
                      setShowEditTeam(true);
                    }}
                    className="w-full mt-4 bg-yellow-500 hover:bg-yellow-600 text-black font-medium px-4 py-2 rounded-lg transition-colors"
                  >
                    Manage Team
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Auction Tab */}
      {activeTab === 'auction' && (
        <div className="space-y-8">
          <h2 className="text-2xl font-bold text-gray-900">Live Auction Control Panel</h2>

          {/* Random Player Selection */}
          <div className="bg-white rounded-xl shadow-lg p-6 border-2 border-yellow-500">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-bold text-gray-900">Player Selection</h3>
              <div className="flex space-x-3">
                <button
                  onClick={() => setShowPlayerSearch(!showPlayerSearch)}
                  disabled={auctionLoading || !!currentAuctionPlayer}
                  className="bg-blue-500 hover:bg-blue-600 text-white font-bold px-4 py-2 rounded-lg transition-colors disabled:opacity-50 flex items-center space-x-2"
                >
                  <Search className="h-4 w-4" />
                  <span>Search Player</span>
                </button>
                <button
                  onClick={selectRandomPlayer}
                  disabled={auctionLoading || unsoldPlayers.length === 0 || !!currentAuctionPlayer}
                  className="bg-yellow-500 hover:bg-yellow-600 text-black font-bold px-4 py-2 rounded-lg transition-colors disabled:opacity-50 flex items-center space-x-2"
                >
                  <Shuffle className="h-4 w-4" />
                  <span>Random Player</span>
                </button>
              </div>
            </div>
            <p className="text-gray-600">Available players: {unsoldPlayers.length}</p>
            
            {/* Player Search Interface */}
            {showPlayerSearch && (
              <div className="mt-4 space-y-4">
                <div className="relative">
                  <Search className="absolute left-3 top-3 h-4 w-4 text-gray-400" />
                  <input
                    type="text"
                    placeholder="Search players by name, role, or country..."
                    value={playerSearchTerm}
                    onChange={(e) => setPlayerSearchTerm(e.target.value)}
                    className="w-full pl-10 pr-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
                  />
                </div>
                
                <div className="max-h-64 overflow-y-auto space-y-2">
                  {filteredUnsoldPlayers.slice(0, 10).map(player => (
                    <div key={player.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
                      <div className="flex items-center space-x-3">
                        <img
                          src={player.photo_url}
                          alt={player.name}
                          className="w-10 h-10 rounded-full object-cover"
                        />
                        <div>
                          <h4 className="font-medium text-gray-900">{player.name}</h4>
                          <p className="text-sm text-gray-500">{player.role} • {player.country}</p>
                          <p className="text-sm font-medium text-green-600">₹{player.base_price.toLocaleString()}</p>
                        </div>
                      </div>
                      <button
                        onClick={() => {
                          startAuction(player);
                          setShowPlayerSearch(false);
                          setPlayerSearchTerm('');
                        }}
                        disabled={auctionLoading}
                        className="bg-green-500 hover:bg-green-600 text-white font-medium px-3 py-1 rounded-lg transition-colors disabled:opacity-50"
                      >
                        Select
                      </button>
                    </div>
                  ))}
                  {filteredUnsoldPlayers.length === 0 && playerSearchTerm && (
                    <div className="text-center py-4 text-gray-500">
                      No players found matching "{playerSearchTerm}"
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>

          {/* Current Auction Display */}
          {currentAuctionPlayer ? (
            <div className="bg-gradient-to-r from-yellow-400 to-yellow-500 rounded-2xl p-8 text-black">
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
                <div>
                  <img
                    src={currentAuctionPlayer.photo_url}
                    alt={currentAuctionPlayer.name}
                    className="w-full h-64 object-cover rounded-xl"
                  />
                </div>
                <div className="space-y-4">
                  <div>
                    <h3 className="text-3xl font-bold">{currentAuctionPlayer.name}</h3>
                    <p className="text-xl opacity-80">{currentAuctionPlayer.role} • {currentAuctionPlayer.country}</p>
                  </div>
                  
                  <div className="bg-black/20 rounded-lg p-4">
                    <p className="text-sm opacity-80">Base Price</p>
                    <p className="text-2xl font-bold">₹{currentAuctionPlayer.base_price.toLocaleString()}</p>
                  </div>
                  
                  <div className="bg-white/20 rounded-lg p-4">
                    <p className="text-sm opacity-80">Current Bid</p>
                    <p className="text-4xl font-bold">₹{currentBid.toLocaleString()}</p>
                  </div>
                  
                  <div className="bg-white/10 rounded-lg p-4">
                    <p className="text-sm opacity-80 mb-2">Career Stats</p>
                    <div className="grid grid-cols-2 gap-2 text-sm">
                      <div>
                        <span className="opacity-80">Matches:</span>
                        <span className="font-medium ml-1">{currentAuctionPlayer.stats.matches}</span>
                      </div>
                      {currentAuctionPlayer.stats.runs && (
                        <div>
                          <span className="opacity-80">Runs:</span>
                          <span className="font-medium ml-1">{currentAuctionPlayer.stats.runs}</span>
                        </div>
                      )}
                      {currentAuctionPlayer.stats.wickets && (
                        <div>
                          <span className="opacity-80">Wickets:</span>
                          <span className="font-medium ml-1">{currentAuctionPlayer.stats.wickets}</span>
                        </div>
                      )}
                      {currentAuctionPlayer.stats.average && (
                        <div>
                          <span className="opacity-80">Average:</span>
                          <span className="font-medium ml-1">{currentAuctionPlayer.stats.average}</span>
                        </div>
                      )}
                    </div>
                  </div>

                  <div className="flex space-x-2">
                    <button onClick={() => updateBid(500000)} className="bg-white/20 hover:bg-white/30 px-4 py-2 rounded-lg transition-colors">+5L</button>
                    <button onClick={() => updateBid(1000000)} className="bg-white/20 hover:bg-white/30 px-4 py-2 rounded-lg transition-colors">+10L</button>
                    <button onClick={() => updateBid(2500000)} className="bg-white/20 hover:bg-white/30 px-4 py-2 rounded-lg transition-colors">+25L</button>
                    <button onClick={() => updateBid(5000000)} className="bg-white/20 hover:bg-white/30 px-4 py-2 rounded-lg transition-colors">+50L</button>
                  </div>

                  <div className="space-y-4">
                    <select
                      value={selectedTeamId}
                      onChange={(e) => setSelectedTeamId(e.target.value)}
                      className="w-full px-4 py-2 rounded-lg bg-white/20 border border-white/30 text-black placeholder-black/60"
                    >
                      <option value="">Select Team</option>
                      {teams.map(team => (
                        <option key={team.id} value={team.id} className="text-black">
                          {team.name} (₹{(team.purse_remaining / 10000000).toFixed(1)}Cr)
                        </option>
                      ))}
                    </select>

                    <div className="flex space-x-3">
                      <button
                        onClick={soldPlayer}
                        disabled={auctionLoading || !selectedTeamId}
                        className="flex-1 bg-green-600 hover:bg-green-700 text-white font-bold py-3 px-4 rounded-lg transition-colors disabled:opacity-50 flex items-center justify-center space-x-2"
                      >
                        <Trophy className="h-5 w-5" />
                        <span>SOLD</span>
                      </button>
                      <button
                        onClick={unsoldPlayer}
                        disabled={auctionLoading}
                        className="flex-1 bg-red-600 hover:bg-red-700 text-white font-bold py-3 px-4 rounded-lg transition-colors disabled:opacity-50 flex items-center justify-center space-x-2"
                      >
                        <Eye className="h-5 w-5" />
                        <span>UNSOLD</span>
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          ) : (
            <div className="bg-gray-100 rounded-2xl p-8 text-center">
              <Play className="h-16 w-16 text-gray-400 mx-auto mb-4" />
              <h3 className="text-xl font-semibold text-gray-600 mb-2">No Active Auction</h3>
              <p className="text-gray-500">Click "Random Player" to start an auction</p>
            </div>
          )}

          {/* Available Players */}
          <div className="space-y-4">
            <h3 className="text-xl font-bold text-gray-900">Available Players ({unsoldPlayers.length})</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {unsoldPlayers.slice(0, 12).map(player => (
                <div key={player.id} className="bg-white rounded-lg shadow-md p-4 hover:shadow-lg transition-shadow">
                  <div className="flex items-center space-x-3">
                    <img
                      src={player.photo_url}
                      alt={player.name}
                      className="w-12 h-12 rounded-full object-cover"
                    />
                    <div className="flex-1">
                      <h4 className="font-medium text-gray-900">{player.name}</h4>
                      <p className="text-sm text-gray-500">{player.role}</p>
                      <p className="text-sm font-medium text-green-600">₹{player.base_price.toLocaleString()}</p>
                    </div>
                    <button
                      onClick={() => startAuction(player)}
                      disabled={auctionLoading || !!currentAuctionPlayer}
                      className="bg-yellow-500 hover:bg-yellow-600 text-black font-medium px-3 py-1 rounded-lg transition-colors disabled:opacity-50"
                    >
                      Start
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Modals */}
      {showAddPlayer && (
        <AddPlayerModal
          onClose={() => setShowAddPlayer(false)}
          onSuccess={() => {
            setShowAddPlayer(false);
            fetchData();
          }}
        />
      )}

      {showEditTeam && selectedTeam && (
        <EditTeamModal
          team={selectedTeam}
          onClose={() => {
            setShowEditTeam(false);
            setSelectedTeam(null);
          }}
          onSuccess={() => {
            setShowEditTeam(false);
            setSelectedTeam(null);
            fetchData();
          }}
        />
      )}
    </div>
  );
}