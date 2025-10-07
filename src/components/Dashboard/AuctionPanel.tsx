import React, { useState } from 'react';
import { Play, SkipForward, Trophy, Shuffle, Eye } from 'lucide-react';
import { Player, Team, Auction } from '../../types';
import { supabase } from '../../lib/supabase';
import toast from 'react-hot-toast';

interface AuctionPanelProps {
  players: Player[];
  teams: Team[];
  onUpdate: () => void;
  auctionEventId: string; // ADDED: The ID of the current auction event is now required.
}

export function AuctionPanel({ players, teams, onUpdate, auctionEventId }: AuctionPanelProps) {
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
      toast.error('No more players available for auction.');
      return;
    }
    const randomIndex = Math.floor(Math.random() * unsoldPlayers.length);
    const randomPlayer = unsoldPlayers[randomIndex];
    setSelectedPlayer(randomPlayer);
    setShowPlayerDetails(true);
    toast.success(`Selected for auction: ${randomPlayer.name}`);
  };

  const startAuction = async (player: Player) => {
    if (currentPlayer) {
      toast.error('An auction is already in progress.');
      return;
    }
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('auctions')
        .insert({
          player_id: player.id,
          current_price: player.base_price,
          is_active: true,
          auction_event_id: auctionEventId, // CRITICAL FIX: Pass the auction_event_id to the database.
        })
        .select()
        .single();

      if (error) throw new Error(error.message);
      if (!data) throw new Error('Failed to create auction. Check RLS policies.');

      setCurrentAuction(data);
      setCurrentPlayer(player);
      setCurrentBid(player.base_price);
      setShowPlayerDetails(false);
      toast.success(`Auction LIVE for ${player.name}!`);
    } catch (err: any) {
      console.error('Error starting auction:', err);
      toast.error(`Auction failed: ${err.message || 'Unknown error'}`);
    } finally {
      setLoading(false);
    }
  };

  const updateBid = (amount: number) => {
    if (!currentPlayer) return;
    const newBid = currentBid + amount;
    setCurrentBid(Math.max(newBid, currentPlayer.base_price));
  };

  const soldPlayer = async () => {
    const team = teams.find(t => t.id === selectedTeamId);
    if (!currentAuction || !currentPlayer || !team) {
      toast.error('Please select a valid team for the winning bid.');
      return;
    }
    if (team.purse_remaining < currentBid) {
      toast.error(`${team.name} has insufficient funds.`);
      return;
    }
    setLoading(true);
    try {
      const { error } = await supabase.rpc('sell_player', {
        p_id: currentPlayer.id,
        a_id: currentAuction.id,
        t_id: team.id,
        sell_price: currentBid
      });

      if (error) throw error;

      toast.success(`${currentPlayer.name} sold to ${team.name} for ₹${currentBid.toLocaleString()}`);
      resetAuction();
      onUpdate();
    } catch (error: any) {
      console.error('Error selling player:', error);
      toast.error(`Transaction failed: ${error.message}`);
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
        .update({ is_active: false })
        .eq('id', currentAuction.id);
      toast.info(`${currentPlayer.name} went unsold.`);
      resetAuction();
    } catch (error: any) {
      console.error('Error marking player unsold:', error);
      toast.error('Could not mark player as unsold.');
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
      {!currentPlayer && (
        <div className="bg-white rounded-xl shadow-lg p-6 border-2 border-yellow-500">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-bold text-gray-900">Select Player for Auction</h3>
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
            <div className="bg-gray-50 rounded-lg p-4 mt-4 animate-fade-in">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="h-48 bg-gradient-to-br from-gray-100 to-gray-200 rounded-lg flex items-center justify-center p-4">
                  <img
                    src={selectedPlayer.photo_url}
                    alt={selectedPlayer.name}
                    className="max-w-full max-h-full object-contain"
                  />
                </div>
                <div className="space-y-3 flex flex-col justify-between">
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
                      className="bg-gray-500 hover:bg-gray-600 text-white font-bold py-2 px-4 rounded-lg transition-colors flex items-center justify-center space-x-2"
                    >
                      <Eye className="h-4 w-4" />
                      <span>Hide</span>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      )}
      {currentPlayer ? (
        <div className="bg-gradient-to-r from-yellow-400 to-yellow-500 rounded-2xl p-8 shadow-2xl text-black">
            <div className="grid grid-cols-1 lg:grid-cols-5 gap-8">
                <div className="lg:col-span-2 space-y-4">
                    <div className="h-96 bg-gradient-to-br from-black/20 to-black/30 rounded-2xl shadow-2xl flex items-center justify-center p-6 border-4 border-white/30">
                        <img src={currentPlayer.photo_url} alt={currentPlayer.name} className="max-w-full max-h-full object-contain" />
                    </div>

                    <div className="bg-black/30 backdrop-blur-sm rounded-xl p-4 border-2 border-white/30">
                        <h4 className="text-lg font-bold mb-3 text-white">Career Statistics</h4>
                        <div className="grid grid-cols-2 gap-3">
                            <div className="bg-white/20 rounded-lg p-3">
                                <p className="text-xs opacity-80">Matches</p>
                                <p className="text-2xl font-bold">{currentPlayer.stats.matches || 0}</p>
                            </div>
                            {currentPlayer.stats.runs && (
                                <>
                                    <div className="bg-white/20 rounded-lg p-3">
                                        <p className="text-xs opacity-80">Runs</p>
                                        <p className="text-2xl font-bold">{currentPlayer.stats.runs}</p>
                                    </div>
                                    <div className="bg-white/20 rounded-lg p-3">
                                        <p className="text-xs opacity-80">Average</p>
                                        <p className="text-2xl font-bold">{currentPlayer.stats.average || '-'}</p>
                                    </div>
                                    <div className="bg-white/20 rounded-lg p-3">
                                        <p className="text-xs opacity-80">Strike Rate</p>
                                        <p className="text-2xl font-bold">{currentPlayer.stats.strike_rate || '-'}</p>
                                    </div>
                                    <div className="bg-white/20 rounded-lg p-3">
                                        <p className="text-xs opacity-80">50s</p>
                                        <p className="text-2xl font-bold">{currentPlayer.stats['50s'] || 0}</p>
                                    </div>
                                    <div className="bg-white/20 rounded-lg p-3">
                                        <p className="text-xs opacity-80">100s</p>
                                        <p className="text-2xl font-bold">{currentPlayer.stats['100s'] || 0}</p>
                                    </div>
                                    <div className="bg-white/20 rounded-lg p-3">
                                        <p className="text-xs opacity-80">High Score</p>
                                        <p className="text-2xl font-bold">{currentPlayer.stats.high_score || '-'}</p>
                                    </div>
                                    {currentPlayer.stats.rating && (
                                        <div className="bg-white/20 rounded-lg p-3">
                                            <p className="text-xs opacity-80">Rating</p>
                                            <p className="text-2xl font-bold">{currentPlayer.stats.rating}/10</p>
                                        </div>
                                    )}
                                </>
                            )}
                            {currentPlayer.stats.wickets && (
                                <>
                                    <div className="bg-white/20 rounded-lg p-3">
                                        <p className="text-xs opacity-80">Wickets</p>
                                        <p className="text-2xl font-bold">{currentPlayer.stats.wickets}</p>
                                    </div>
                                    <div className="bg-white/20 rounded-lg p-3">
                                        <p className="text-xs opacity-80">Economy</p>
                                        <p className="text-2xl font-bold">{currentPlayer.stats.economy || '-'}</p>
                                    </div>
                                    <div className="bg-white/20 rounded-lg p-3">
                                        <p className="text-xs opacity-80">Average</p>
                                        <p className="text-2xl font-bold">{currentPlayer.stats.average || '-'}</p>
                                    </div>
                                    <div className="bg-white/20 rounded-lg p-3">
                                        <p className="text-xs opacity-80">Strike Rate</p>
                                        <p className="text-2xl font-bold">{currentPlayer.stats.strike_rate || '-'}</p>
                                    </div>
                                    <div className="bg-white/20 rounded-lg p-3">
                                        <p className="text-xs opacity-80">4W</p>
                                        <p className="text-2xl font-bold">{currentPlayer.stats['4w'] || 0}</p>
                                    </div>
                                    <div className="bg-white/20 rounded-lg p-3">
                                        <p className="text-xs opacity-80">5W</p>
                                        <p className="text-2xl font-bold">{currentPlayer.stats['5w'] || 0}</p>
                                    </div>
                                    {currentPlayer.stats.rating && (
                                        <div className="bg-white/20 rounded-lg p-3">
                                            <p className="text-xs opacity-80">Rating</p>
                                            <p className="text-2xl font-bold">{currentPlayer.stats.rating}/10</p>
                                        </div>
                                    )}
                                </>
                            )}
                            {currentPlayer.stats.batting_rating && (
                                <>
                                    <div className="bg-white/20 rounded-lg p-3">
                                        <p className="text-xs opacity-80">Runs</p>
                                        <p className="text-2xl font-bold">{currentPlayer.stats.runs || 0}</p>
                                    </div>
                                    <div className="bg-white/20 rounded-lg p-3">
                                        <p className="text-xs opacity-80">Wickets</p>
                                        <p className="text-2xl font-bold">{currentPlayer.stats.wickets || 0}</p>
                                    </div>
                                    <div className="bg-white/20 rounded-lg p-3">
                                        <p className="text-xs opacity-80">Bat Rating</p>
                                        <p className="text-2xl font-bold">{currentPlayer.stats.batting_rating}/10</p>
                                    </div>
                                    <div className="bg-white/20 rounded-lg p-3">
                                        <p className="text-xs opacity-80">Bowl Rating</p>
                                        <p className="text-2xl font-bold">{currentPlayer.stats.bowling_rating}/10</p>
                                    </div>
                                    <div className="bg-white/20 rounded-lg p-3 col-span-2">
                                        <p className="text-xs opacity-80">Overall Rating</p>
                                        <p className="text-2xl font-bold">{currentPlayer.stats.overall_rating}/10</p>
                                    </div>
                                </>
                            )}
                        </div>
                    </div>
                </div>

                <div className="lg:col-span-3 space-y-5">
                    <div>
                        <h3 className="text-5xl font-black mb-2">{currentPlayer.name}</h3>
                        <p className="text-2xl opacity-80 mb-1">{currentPlayer.role} • {currentPlayer.country}</p>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                        <div className="bg-black/20 rounded-xl p-4 border-2 border-white/20">
                            <p className="text-sm opacity-80">Base Price</p>
                            <p className="text-3xl font-bold">₹{(currentPlayer.base_price / 10000000).toFixed(2)}Cr</p>
                        </div>
                        <div className="bg-white/30 backdrop-blur-sm rounded-xl p-4 border-2 border-white/50">
                            <p className="text-sm opacity-80">Current Bid</p>
                            <p className="text-5xl font-black">₹{(currentBid / 10000000).toFixed(2)}Cr</p>
                        </div>
                    </div>

                    <div>
                        <p className="text-sm font-bold mb-2 opacity-80">BID INCREMENT</p>
                        <div className="grid grid-cols-4 gap-3">
                            <button onClick={() => updateBid(500000)} className="bid-btn">+5L</button>
                            <button onClick={() => updateBid(1000000)} className="bid-btn">+10L</button>
                            <button onClick={() => updateBid(2500000)} className="bid-btn">+25L</button>
                            <button onClick={() => updateBid(5000000)} className="bid-btn">+50L</button>
                        </div>
                    </div>

                    <div className="space-y-4 pt-3">
                        <div>
                            <label className="text-sm font-bold mb-2 block opacity-80">SELECT WINNING TEAM</label>
                            <select
                                value={selectedTeamId}
                                onChange={(e) => setSelectedTeamId(e.target.value)}
                                className="w-full px-5 py-4 rounded-xl bg-white/30 backdrop-blur-sm border-2 border-white/40 text-black font-bold placeholder-black/60 focus:ring-4 focus:ring-white/50 text-lg"
                            >
                                <option value="">-- Select Team --</option>
                                {teams.map(team => (
                                    <option key={team.id} value={team.id} className="text-black font-semibold">
                                        {team.name} (₹{(team.purse_remaining / 10000000).toFixed(2)}Cr)
                                    </option>
                                ))}
                            </select>
                        </div>

                        <div className="grid grid-cols-2 gap-4">
                            <button
                                onClick={soldPlayer}
                                disabled={loading || !selectedTeamId}
                                className="action-btn bg-green-600 hover:bg-green-700 text-xl py-5"
                            >
                                <Trophy className="h-6 w-6" />
                                <span>SOLD</span>
                            </button>
                            <button
                                onClick={unsoldPlayer}
                                disabled={loading}
                                className="action-btn bg-red-600 hover:bg-red-700 text-xl py-5"
                            >
                                <SkipForward className="h-6 w-6" />
                                <span>UNSOLD</span>
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
      ) : (
        <div className="bg-gray-100 rounded-2xl p-8 text-center">
            <h3 className="text-xl font-semibold text-gray-600 mb-2">Auction is Idle</h3>
            <p className="text-gray-500">Select a player to begin the auction.</p>
        </div>
      )}
      <div className="space-y-4">
        <h3 className="text-xl font-bold text-gray-900">Available Players ({unsoldPlayers.length})</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {unsoldPlayers.slice(0, 6).map(player => (
            <div key={player.id} className="bg-white rounded-lg shadow p-3 hover:shadow-lg transition-shadow">
              <div className="flex items-center space-x-3">
                <div className="w-12 h-12 rounded-full bg-gradient-to-br from-gray-100 to-gray-200 flex items-center justify-center p-1 overflow-hidden flex-shrink-0">
                  <img src={player.photo_url} alt={player.name} className="w-full h-full object-contain" />
                </div>
                <div className="flex-1">
                  <h4 className="font-medium text-gray-900">{player.name}</h4>
                  <p className="text-sm text-gray-500">{player.role}</p>
                </div>
                <button
                  onClick={() => startAuction(player)}
                  disabled={loading || !!currentPlayer}
                  className="bg-yellow-500 hover:bg-yellow-600 text-black text-sm font-medium px-3 py-1 rounded-lg transition-colors disabled:opacity-50"
                >
                  Start
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
      <style jsx>{`
        .bid-btn { background-color: rgba(255, 255, 255, 0.2); padding: 0.5rem 1rem; border-radius: 0.5rem; transition: background-color 0.2s; font-weight: 600; flex-grow: 1; }
        .bid-btn:hover { background-color: rgba(255, 255, 255, 0.4); }
        .action-btn { flex: 1; color: white; font-weight: bold; padding: 0.75rem 1rem; border-radius: 0.5rem; transition: background-color 0.2s; display: flex; align-items: center; justify-content: center; gap: 0.5rem; }
        .action-btn:disabled { opacity: 0.5; cursor: not-allowed; }
        .animate-fade-in { animation: fadeIn 0.5s ease-in-out; }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(-10px); } to { opacity: 1; transform: translateY(0); } }
      `}</style>
    </div>
  );
}
