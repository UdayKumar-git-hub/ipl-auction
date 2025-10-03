import React, { useState, useEffect } from 'react';
import { Play, Pause, SkipForward, DollarSign, Trophy, User, Shuffle, Eye } from 'lucide-react';
import { Player, Team, Auction } from '../../types';
import { supabase } from '../../lib/supabase';
import toast from 'react-hot-toast';

interface AuctionPanelProps {
  players: Player[];
  teams: Team[];
  onUpdate: () => void;
}

export function AuctionPanel({ players, teams, onUpdate }: AuctionPanelProps) {
  const [currentAuction, setCurrentAuction] = useState<Auction | null>(null);
  const [currentPlayer, setCurrentPlayer] = useState<Player | null>(null);
  const [selectedPlayer, setSelectedPlayer] = useState<Player | null>(null);
  const [showPlayerDetails, setShowPlayerDetails] = useState(false);
  const [currentBid, setCurrentBid] = useState(0);
  const [selectedTeamId, setSelectedTeamId] = useState('');
  const [loading, setLoading] = useState(false);

  const unsoldPlayers = players.filter(p => !p.is_sold);

  const selectRandomPlayer = () => {
    if (unsoldPlayers.length === 0) {
      toast.error('No players available for selection');
      return;
    }
    
    const randomIndex = Math.floor(Math.random() * unsoldPlayers.length);
    const randomPlayer = unsoldPlayers[randomIndex];
    setSelectedPlayer(randomPlayer);
    setShowPlayerDetails(true);
    toast.success(`Random player selected: ${randomPlayer.name}`);
  };
  const startAuction = async (player: Player) => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('auctions')
        .insert({
          player_id: player.id,
          current_price: player.base_price,
          is_active: true
        })
        .select()
        .single();

      if (error) throw error;

      setCurrentAuction(data);
      setCurrentPlayer(player);
      setCurrentBid(player.base_price);
      setShowPlayerDetails(false);
      toast.success(`Auction started for ${player.name}`);
    } catch (error) {
      console.error('Error starting auction:', error);
      toast.error('Error starting auction');
    } finally {
      setLoading(false);
    }
  };

  const updateBid = (amount: number) => {
    setCurrentBid(prev => Math.max(prev + amount, currentPlayer?.base_price || 0));
  };

  const soldPlayer = async () => {
    if (!currentAuction || !currentPlayer || !selectedTeamId) {
      toast.error('Please select a team');
      return;
    }

    setLoading(true);
    try {
      // Update auction
      await supabase
        .from('auctions')
        .update({
          current_price: currentBid,
          winning_team_id: selectedTeamId,
          is_active: false
        })
        .eq('id', currentAuction.id);

      // Update player
      await supabase
        .from('players')
        .update({
          is_sold: true,
          current_price: currentBid,
          team_id: selectedTeamId
        })
        .eq('id', currentPlayer.id);

      // Update team purse
      const team = teams.find(t => t.id === selectedTeamId);
      if (team) {
        await supabase
          .from('teams')
          .update({
            purse_remaining: team.purse_remaining - currentBid,
            players_count: team.players_count + 1
          })
          .eq('id', selectedTeamId);
      }

      toast.success(`${currentPlayer.name} sold to ${team?.name} for ₹${currentBid.toLocaleString()}`);
      resetAuction();
      onUpdate();
    } catch (error) {
      console.error('Error selling player:', error);
      toast.error('Error selling player');
    } finally {
      setLoading(false);
    }
  };

  const unsoldPlayer = async () => {
    if (!currentAuction || !currentPlayer) return;

    setLoading(true);
    try {
      await supabase
        .from('auctions')
        .update({
          is_active: false
        })
        .eq('id', currentAuction.id);

      toast(`${currentPlayer.name} went unsold`);
      resetAuction();
    } catch (error) {
      console.error('Error marking player unsold:', error);
      toast.error('Error processing player');
    } finally {
      setLoading(false);
    }
  };

  const resetAuction = () => {
    setCurrentAuction(null);
    setCurrentPlayer(null);
    setCurrentBid(0);
    setSelectedTeamId('');
  };

  const getRoleColor = (role: string) => {
    switch (role) {
      case 'Batsman': return 'bg-blue-100 text-blue-800';
      case 'Bowler': return 'bg-red-100 text-red-800';
      case 'All-Rounder': return 'bg-green-100 text-green-800';
      case 'Wicketkeeper': return 'bg-purple-100 text-purple-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };
  return (
    <div className="space-y-8">
      <h2 className="text-2xl font-bold text-gray-900">Live Auction Control Panel</h2>

      {/* Random Player Selection */}
      <div className="bg-white rounded-xl shadow-lg p-6 border-2 border-yellow-500">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-bold text-gray-900">Random Player Selection</h3>
          <button
            onClick={selectRandomPlayer}
            disabled={loading || unsoldPlayers.length === 0}
            className="bg-yellow-500 hover:bg-yellow-600 text-black font-bold px-4 py-2 rounded-lg transition-colors disabled:opacity-50 flex items-center space-x-2"
          >
            <Shuffle className="h-4 w-4" />
            <span>Random Player</span>
          </button>
        </div>
        
        {selectedPlayer && showPlayerDetails && (
          <div className="bg-gray-50 rounded-lg p-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <img
                  src={selectedPlayer.photo_url}
                  alt={selectedPlayer.name}
                  className="w-full h-48 object-cover rounded-lg"
                />
              </div>
              <div className="space-y-3">
                <div>
                  <h4 className="text-xl font-bold text-gray-900">{selectedPlayer.name}</h4>
                  <div className="flex items-center space-x-2 mt-1">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${getRoleColor(selectedPlayer.role)}`}>
                      {selectedPlayer.role}
                    </span>
                    <span className="text-sm text-gray-600">{selectedPlayer.country}</span>
                  </div>
                </div>
                
                <div className="bg-white rounded-lg p-3">
                  <p className="text-sm text-gray-500">Base Price</p>
                  <p className="text-lg font-bold text-green-600">₹{selectedPlayer.base_price.toLocaleString()}</p>
                </div>
                
                <div className="bg-white rounded-lg p-3">
                  <p className="text-sm text-gray-500 mb-2">Career Stats</p>
                  <div className="grid grid-cols-2 gap-2 text-sm">
                    <div>
                      <span className="text-gray-500">Matches:</span>
                      <span className="font-medium ml-1">{selectedPlayer.stats.matches}</span>
                    </div>
                    {selectedPlayer.stats.runs && (
                      <div>
                        <span className="text-gray-500">Runs:</span>
                        <span className="font-medium ml-1">{selectedPlayer.stats.runs}</span>
                      </div>
                    )}
                    {selectedPlayer.stats.wickets && (
                      <div>
                        <span className="text-gray-500">Wickets:</span>
                        <span className="font-medium ml-1">{selectedPlayer.stats.wickets}</span>
                      </div>
                    )}
                    {selectedPlayer.stats.average && (
                      <div>
                        <span className="text-gray-500">Average:</span>
                        <span className="font-medium ml-1">{selectedPlayer.stats.average}</span>
                      </div>
                    )}
                  </div>
                </div>
                
                <div className="flex space-x-2">
                  <button
                    onClick={() => startAuction(selectedPlayer)}
                    disabled={loading || !!currentPlayer}
                    className="flex-1 bg-green-600 hover:bg-green-700 text-white font-bold py-2 px-4 rounded-lg transition-colors disabled:opacity-50 flex items-center justify-center space-x-2"
                  >
                    <Play className="h-4 w-4" />
                    <span>Start Auction</span>
                  </button>
                  <button
                    onClick={() => setShowPlayerDetails(false)}
                    className="flex-1 bg-gray-500 hover:bg-gray-600 text-white font-bold py-2 px-4 rounded-lg transition-colors flex items-center justify-center space-x-2"
                  >
                    <Eye className="h-4 w-4" />
                    <span>Hide Details</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
      {/* Current Auction Display */}
      {currentPlayer ? (
        <div className="bg-gradient-to-r from-yellow-400 to-yellow-500 rounded-2xl p-8 text-black">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <div>
              <img
                src={currentPlayer.photo_url}
                alt={currentPlayer.name}
                className="w-full h-64 object-cover rounded-xl"
              />
            </div>
            <div className="space-y-4">
              <div>
                <h3 className="text-3xl font-bold">{currentPlayer.name}</h3>
                <p className="text-xl opacity-80">{currentPlayer.role} • {currentPlayer.country}</p>
              </div>
              
              <div className="bg-black/20 rounded-lg p-4">
                <p className="text-sm opacity-80">Base Price</p>
                <p className="text-2xl font-bold">₹{currentPlayer.base_price.toLocaleString()}</p>
              </div>
              
              <div className="bg-white/20 rounded-lg p-4">
                <p className="text-sm opacity-80">Current Bid</p>
                <p className="text-4xl font-bold">₹{currentBid.toLocaleString()}</p>
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
                    disabled={loading || !selectedTeamId}
                    className="flex-1 bg-green-600 hover:bg-green-700 text-white font-bold py-3 px-4 rounded-lg transition-colors disabled:opacity-50 flex items-center justify-center space-x-2"
                  >
                    <Trophy className="h-5 w-5" />
                    <span>SOLD</span>
                  </button>
                  <button
                    onClick={unsoldPlayer}
                    disabled={loading}
                    className="flex-1 bg-red-600 hover:bg-red-700 text-white font-bold py-3 px-4 rounded-lg transition-colors disabled:opacity-50 flex items-center justify-center space-x-2"
                  >
                    <SkipForward className="h-5 w-5" />
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
          <p className="text-gray-500">Select a player to start the auction</p>
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
                  disabled={loading || !!currentPlayer}
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
  );
}