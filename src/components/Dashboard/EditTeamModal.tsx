import React, { useState } from 'react';
import { X, DollarSign, Users, Trophy } from 'lucide-react';
import { Team } from '../../types';
import { supabase } from '../../lib/supabase';
import toast from 'react-hot-toast';

interface EditTeamModalProps {
  team: Team;
  onClose: () => void;
  onSuccess: () => void;
}

export function EditTeamModal({ team, onClose, onSuccess }: EditTeamModalProps) {
  const [formData, setFormData] = useState({
    name: team.name,
    short_name: team.short_name,
    logo_url: team.logo_url,
    purse_remaining: team.purse_remaining.toString(),
    total_purse: team.total_purse.toString()
  });
  const [loading, setLoading] = useState(false);

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

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50 overflow-y-auto">
      <div className="bg-white rounded-xl shadow-2xl w-full max-w-4xl my-8">
        <div className="flex items-center justify-between p-6 border-b">
          <h2 className="text-2xl font-bold text-gray-900">Manage Team - {team.name}</h2>
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

        {/* Team Details Tab */}
        {activeTab === 'details' && (
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
        )}

        {/* Players Tab */}
        {activeTab === 'players' && (
          <div className="p-6 space-y-6">
            {/* Current Team Players */}
            <div>
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Current Squad ({teamPlayers.length})</h3>
              {playersLoading ? (
                <div className="flex justify-center py-8">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-yellow-500"></div>
                </div>
              ) : teamPlayers.length === 0 ? (
                <div className="text-center py-8 text-gray-500">
                  <Users className="h-12 w-12 mx-auto mb-2 opacity-50" />
                  <p>No players in squad yet</p>
                </div>
              ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {teamPlayers.map(player => (
                    <div key={player.id} className="bg-gray-50 rounded-lg p-4 flex items-center justify-between">
                      <div className="flex items-center space-x-3">
                        <img src={player.photo_url} alt={player.name} className="w-12 h-12 rounded-full object-cover" />
                        <div>
                          <h4 className="font-medium text-gray-900">{player.name}</h4>
                          <p className="text-sm text-gray-500">{player.role} • {player.country}</p>
                          <p className="text-sm font-medium text-green-600">₹{player.current_price?.toLocaleString()}</p>
                        </div>
                      </div>
                      <button
                        onClick={() => removePlayerFromTeam(player)}
                        disabled={loading}
                        className="bg-red-500 hover:bg-red-600 text-white p-2 rounded-lg transition-colors disabled:opacity-50"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Add Players Section */}
            <div className="border-t pt-6">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-semibold text-gray-900">Add Players</h3>
                <button
                  onClick={() => setShowAddPlayer(!showAddPlayer)}
                  className="bg-yellow-500 hover:bg-yellow-600 text-black font-medium px-4 py-2 rounded-lg transition-colors flex items-center space-x-2"
                >
                  <Plus className="h-4 w-4" />
                  <span>Add Player</span>
                </button>
              </div>

              {showAddPlayer && (
                <div className="space-y-4">
                  <div className="relative">
                    <Search className="absolute left-3 top-3 h-4 w-4 text-gray-400" />
                    <input
                      type="text"
                      placeholder="Search available players..."
                      value={playerSearchTerm}
                      onChange={(e) => setPlayerSearchTerm(e.target.value)}
                      className="w-full pl-10 pr-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
                    />
                  </div>

                  <div className="max-h-60 overflow-y-auto space-y-2">
                    {availablePlayers
                      .filter(p => p.name.toLowerCase().includes(playerSearchTerm.toLowerCase()))
                      .slice(0, 10)
                      .map(player => (
                        <div key={player.id} className="bg-white border rounded-lg p-3 flex items-center justify-between">
                          <div className="flex items-center space-x-3">
                            <img src={player.photo_url} alt={player.name} className="w-10 h-10 rounded-full object-cover" />
                            <div>
                              <h4 className="font-medium text-gray-900">{player.name}</h4>
                              <p className="text-sm text-gray-500">{player.role} • {player.country}</p>
                              <p className="text-sm font-medium text-blue-600">₹{player.base_price.toLocaleString()}</p>
                            </div>
                          </div>
                          <button
                            onClick={() => addPlayerToTeam(player)}
                            disabled={loading || team.purse_remaining < player.base_price}
                            className="bg-green-500 hover:bg-green-600 text-white font-medium px-3 py-1 rounded-lg transition-colors disabled:opacity-50"
                          >
                            Add
                          </button>
                        </div>
                      ))}
                  </div>
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
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
      </div>
    </div>
  );
}