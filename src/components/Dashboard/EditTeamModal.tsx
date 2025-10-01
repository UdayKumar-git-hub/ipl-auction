import React, { useState } from 'react';
import { X, DollarSign, Users, Trophy, Search, Plus, Trash2 } from 'lucide-react';
import { Team, Player } from '../../types';
import { supabase } from '../../lib/supabase';
import toast from 'react-hot-toast';

interface EditTeamModalProps {
  team: Team;
  onClose: () => void;
  onSuccess: () => void;
}

export function EditTeamModal({ team, onClose, onSuccess }: EditTeamModalProps) {
  const [activeTab, setActiveTab] = useState<'details' | 'players'>('details');
  const [formData, setFormData] = useState({
    name: team.name,
    short_name: team.short_name,
    logo_url: team.logo_url,
    purse_remaining: team.purse_remaining.toString(),
    total_purse: team.total_purse.toString()
  });
  const [teamPlayers, setTeamPlayers] = useState<Player[]>([]);
  const [availablePlayers, setAvailablePlayers] = useState<Player[]>([]);
  const [playerSearchTerm, setPlayerSearchTerm] = useState('');
  const [loading, setLoading] = useState(false);

  React.useEffect(() => {
    if (activeTab === 'players') {
      fetchPlayers();
    }
  }, [activeTab, team.id]);

  const fetchPlayers = async () => {
    try {
      // Fetch team players
      const { data: teamPlayersData, error: teamError } = await supabase
        .from('players')
        .select('*')
        .eq('team_id', team.id)
        .eq('is_sold', true);

      if (teamError) throw teamError;
      setTeamPlayers(teamPlayersData || []);

      // Fetch available players
      const { data: availablePlayersData, error: availableError } = await supabase
        .from('players')
        .select('*')
        .eq('is_sold', false);

      if (availableError) throw availableError;
      setAvailablePlayers(availablePlayersData || []);
    } catch (error) {
      console.error('Error fetching players:', error);
      toast.error('Error loading players');
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      const { error } = await supabase
        .from('teams')
        .update({
          name: formData.name,
          short_name: formData.short_name,
          logo_url: formData.logo_url,
          purse_remaining: parseInt(formData.purse_remaining),
          total_purse: parseInt(formData.total_purse)
        })
        .eq('id', team.id);

      if (error) throw error;

      toast.success('Team updated successfully');
      onSuccess();
    } catch (error) {
      console.error('Error updating team:', error);
      toast.error('Error updating team');
    } finally {
      setLoading(false);
    }
  };

  const resetPurse = async () => {
    if (!confirm('Are you sure you want to reset this team\'s purse to ₹100Cr?')) return;

    setLoading(true);
    try {
      const { error } = await supabase
        .from('teams')
        .update({
          purse_remaining: 1000000000,
          total_purse: 1000000000,
          players_count: 0
        })
        .eq('id', team.id);

      if (error) throw error;

      // Also reset all players from this team
      await supabase
        .from('players')
        .update({
          is_sold: false,
          current_price: null,
          team_id: null
        })
        .eq('team_id', team.id);

      toast.success('Team purse reset successfully');
      onSuccess();
    } catch (error) {
      console.error('Error resetting team:', error);
      toast.error('Error resetting team');
    } finally {
      setLoading(false);
    }
  };

  const addPlayerToTeam = async (player: Player) => {
    if (team.purse_remaining < player.base_price) {
      toast.error('Insufficient purse remaining');
      return;
    }

    setLoading(true);
    try {
      // Update player
      await supabase
        .from('players')
        .update({
          is_sold: true,
          current_price: player.base_price,
          team_id: team.id
        })
        .eq('id', player.id);

      // Update team
      await supabase
        .from('teams')
        .update({
          purse_remaining: team.purse_remaining - player.base_price,
          players_count: team.players_count + 1
        })
        .eq('id', team.id);

      toast.success(`${player.name} added to team`);
      fetchPlayers();
      onSuccess();
    } catch (error) {
      console.error('Error adding player:', error);
      toast.error('Error adding player');
    } finally {
      setLoading(false);
    }
  };

  const removePlayerFromTeam = async (player: Player) => {
    if (!confirm(`Remove ${player.name} from the team?`)) return;

    setLoading(true);
    try {
      // Update player
      await supabase
        .from('players')
        .update({
          is_sold: false,
          current_price: null,
          team_id: null
        })
        .eq('id', player.id);

      // Update team
      await supabase
        .from('teams')
        .update({
          purse_remaining: team.purse_remaining + (player.current_price || player.base_price),
          players_count: Math.max(0, team.players_count - 1)
        })
        .eq('id', team.id);

      toast.success(`${player.name} removed from team`);
      fetchPlayers();
      onSuccess();
    } catch (error) {
      console.error('Error removing player:', error);
      toast.error('Error removing player');
    } finally {
      setLoading(false);
    }
  };

  const filteredAvailablePlayers = availablePlayers.filter(player =>
    player.name.toLowerCase().includes(playerSearchTerm.toLowerCase()) ||
    player.role.toLowerCase().includes(playerSearchTerm.toLowerCase()) ||
    player.country.toLowerCase().includes(playerSearchTerm.toLowerCase())
  );

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-xl shadow-2xl w-full max-w-4xl max-h-[90vh] overflow-hidden">
        <div className="flex items-center justify-between p-6 border-b">
          <h2 className="text-2xl font-bold text-gray-900">Edit Team</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 transition-colors"
          >
            <X className="h-6 w-6" />
          </button>
        </div>

        {/* Tab Navigation */}
        <div className="border-b border-gray-200">
          <nav className="flex space-x-8 px-6">
            <button
              onClick={() => setActiveTab('details')}
              className={`py-4 px-1 border-b-2 font-medium text-sm ${
                activeTab === 'details'
                  ? 'border-yellow-500 text-yellow-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              Team Details
            </button>
            <button
              onClick={() => setActiveTab('players')}
              className={`py-4 px-1 border-b-2 font-medium text-sm ${
                activeTab === 'players'
                  ? 'border-yellow-500 text-yellow-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              Players ({teamPlayers.length})
            </button>
          </nav>
        </div>

        <div className="overflow-y-auto" style={{ maxHeight: 'calc(90vh - 200px)' }}>
          {activeTab === 'details' ? (
            <form onSubmit={handleSubmit} className="p-6 space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Team Name
                  </label>
                  <input
                    type="text"
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    className="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Short Name
                  </label>
                  <input
                    type="text"
                    value={formData.short_name}
                    onChange={(e) => setFormData({ ...formData, short_name: e.target.value })}
                    className="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
                    required
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Logo URL
                </label>
                <input
                  type="url"
                  value={formData.logo_url}
                  onChange={(e) => setFormData({ ...formData, logo_url: e.target.value })}
                  className="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
                />
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Purse Remaining (₹)
                  </label>
                  <div className="relative">
                    <DollarSign className="absolute left-3 top-3 h-4 w-4 text-gray-400" />
                    <input
                      type="number"
                      value={formData.purse_remaining}
                      onChange={(e) => setFormData({ ...formData, purse_remaining: e.target.value })}
                      className="w-full pl-10 pr-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
                      required
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Total Purse (₹)
                  </label>
                  <div className="relative">
                    <DollarSign className="absolute left-3 top-3 h-4 w-4 text-gray-400" />
                    <input
                      type="number"
                      value={formData.total_purse}
                      onChange={(e) => setFormData({ ...formData, total_purse: e.target.value })}
                      className="w-full pl-10 pr-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
                      required
                    />
                  </div>
                </div>
              </div>

              <div className="bg-gray-50 rounded-lg p-4">
                <h3 className="text-lg font-semibold text-gray-900 mb-2 flex items-center">
                  <Trophy className="h-5 w-5 mr-2" />
                  Team Statistics
                </h3>
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <span className="text-gray-500">Players Count:</span>
                    <span className="font-medium ml-2">{team.players_count}</span>
                  </div>
                  <div>
                    <span className="text-gray-500">Purse Used:</span>
                    <span className="font-medium ml-2">₹{((team.total_purse - team.purse_remaining) / 10000000).toFixed(1)}Cr</span>
                  </div>
                </div>
              </div>

              <div className="flex space-x-4 pt-6 border-t">
                <button
                  type="button"
                  onClick={onClose}
                  className="flex-1 px-4 py-2 border-2 border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={resetPurse}
                  disabled={loading}
                  className="flex-1 px-4 py-2 bg-red-500 hover:bg-red-600 text-white font-medium rounded-lg transition-colors disabled:opacity-50"
                >
                  Reset Purse
                </button>
                <button
                  type="submit"
                  disabled={loading}
                  className="flex-1 px-4 py-2 bg-yellow-500 hover:bg-yellow-600 text-black font-medium rounded-lg transition-colors disabled:opacity-50"
                >
                  {loading ? 'Updating...' : 'Update Team'}
                </button>
              </div>
            </form>
          ) : (
            <div className="p-6 space-y-6">
              {/* Current Squad */}
              <div>
                <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center">
                  <Users className="h-5 w-5 mr-2" />
                  Current Squad ({teamPlayers.length})
                </h3>
                {teamPlayers.length > 0 ? (
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
                    {teamPlayers.map((player) => (
                      <div key={player.id} className="bg-gray-50 rounded-lg p-4 flex items-center justify-between">
                        <div className="flex items-center space-x-3">
                          <img
                            src={player.photo_url || 'https://images.pexels.com/photos/163452/basketball-dunk-blue-game-163452.jpeg?auto=compress&cs=tinysrgb&w=100&h=100&fit=crop'}
                            alt={player.name}
                            className="w-12 h-12 rounded-full object-cover"
                          />
                          <div>
                            <h4 className="font-medium text-gray-900">{player.name}</h4>
                            <p className="text-sm text-gray-500">{player.role} • {player.country}</p>
                            <p className="text-sm font-medium text-green-600">₹{(player.current_price || player.base_price) / 10000000}Cr</p>
                          </div>
                        </div>
                        <button
                          onClick={() => removePlayerFromTeam(player)}
                          disabled={loading}
                          className="p-2 text-red-500 hover:bg-red-50 rounded-lg transition-colors disabled:opacity-50"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="text-gray-500 text-center py-8">No players in squad</p>
                )}
              </div>

              {/* Add Players */}
              <div className="border-t pt-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center">
                  <Plus className="h-5 w-5 mr-2" />
                  Add Players
                </h3>
                
                {/* Search */}
                <div className="relative mb-4">
                  <Search className="absolute left-3 top-3 h-4 w-4 text-gray-400" />
                  <input
                    type="text"
                    placeholder="Search players by name, role, or country..."
                    value={playerSearchTerm}
                    onChange={(e) => setPlayerSearchTerm(e.target.value)}
                    className="w-full pl-10 pr-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
                  />
                </div>

                {/* Available Players */}
                <div className="max-h-64 overflow-y-auto">
                  {filteredAvailablePlayers.length > 0 ? (
                    <div className="space-y-2">
                      {filteredAvailablePlayers.map((player) => (
                        <div key={player.id} className="bg-white border rounded-lg p-3 flex items-center justify-between">
                          <div className="flex items-center space-x-3">
                            <img
                              src={player.photo_url || 'https://images.pexels.com/photos/163452/basketball-dunk-blue-game-163452.jpeg?auto=compress&cs=tinysrgb&w=100&h=100&fit=crop'}
                              alt={player.name}
                              className="w-10 h-10 rounded-full object-cover"
                            />
                            <div>
                              <h4 className="font-medium text-gray-900">{player.name}</h4>
                              <p className="text-sm text-gray-500">{player.role} • {player.country}</p>
                              <p className="text-sm font-medium text-blue-600">₹{player.base_price / 10000000}Cr</p>
                            </div>
                          </div>
                          <button
                            onClick={() => addPlayerToTeam(player)}
                            disabled={loading || team.purse_remaining < player.base_price}
                            className="px-3 py-1 bg-yellow-500 hover:bg-yellow-600 text-black text-sm font-medium rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                          >
                            Add
                          </button>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-gray-500 text-center py-8">
                      {playerSearchTerm ? 'No players found matching your search' : 'No available players'}
                    </p>
                  )}
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}