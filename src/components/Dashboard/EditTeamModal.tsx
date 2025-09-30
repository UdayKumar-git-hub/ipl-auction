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
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-xl shadow-2xl w-full max-w-2xl">
        <div className="flex items-center justify-between p-6 border-b">
          <h2 className="text-2xl font-bold text-gray-900">Edit Team</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 transition-colors"
          >
            <X className="h-6 w-6" />
          </button>
        </div>

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
      </div>
    </div>
  );
}