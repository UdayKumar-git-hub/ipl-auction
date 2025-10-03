import React, { useState } from 'react';
import { X } from 'lucide-react';
import { Player } from '../../types';
import { supabase } from '../../lib/supabase';
import toast from 'react-hot-toast';

interface EditPlayerModalProps {
  player: Player;
  onClose: () => void;
  onSuccess: () => void;
}

export function EditPlayerModal({ player, onClose, onSuccess }: EditPlayerModalProps) {
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    name: player.name,
    role: player.role,
    country: player.country,
    base_price: player.base_price,
    photo_url: player.photo_url,
    stats: {
      matches: player.stats.matches || 0,
      runs: player.stats.runs || 0,
      wickets: player.stats.wickets || 0,
      average: player.stats.average || 0,
    }
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      const { error } = await supabase
        .from('players')
        .update({
          name: formData.name,
          role: formData.role,
          country: formData.country,
          base_price: formData.base_price,
          photo_url: formData.photo_url,
          stats: formData.stats
        })
        .eq('id', player.id);

      if (error) throw error;

      toast.success('Player updated successfully');
      onSuccess();
    } catch (error) {
      console.error('Error updating player:', error);
      toast.error('Error updating player');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
          <h2 className="text-2xl font-bold text-gray-900">Edit Player</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 transition-colors"
          >
            <X className="h-6 w-6" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Player Name *
              </label>
              <input
                type="text"
                required
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                className="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Role *
              </label>
              <select
                required
                value={formData.role}
                onChange={(e) => setFormData({ ...formData, role: e.target.value })}
                className="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
              >
                <option value="">Select Role</option>
                <option value="Batsman">Batsman</option>
                <option value="Bowler">Bowler</option>
                <option value="All-Rounder">All-Rounder</option>
                <option value="Wicketkeeper">Wicketkeeper</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Country *
              </label>
              <input
                type="text"
                required
                value={formData.country}
                onChange={(e) => setFormData({ ...formData, country: e.target.value })}
                className="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Base Price (₹) *
              </label>
              <input
                type="number"
                required
                min="0"
                step="100000"
                value={formData.base_price}
                onChange={(e) => setFormData({ ...formData, base_price: parseInt(e.target.value) })}
                className="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Photo URL *
            </label>
            <input
              type="url"
              required
              value={formData.photo_url}
              onChange={(e) => setFormData({ ...formData, photo_url: e.target.value })}
              className="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
              placeholder="https://example.com/player-photo.jpg"
            />
          </div>

          <div className="border-t pt-4">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Career Statistics</h3>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Matches
                </label>
                <input
                  type="number"
                  min="0"
                  value={formData.stats.matches}
                  onChange={(e) => setFormData({
                    ...formData,
                    stats: { ...formData.stats, matches: parseInt(e.target.value) || 0 }
                  })}
                  className="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Runs
                </label>
                <input
                  type="number"
                  min="0"
                  value={formData.stats.runs}
                  onChange={(e) => setFormData({
                    ...formData,
                    stats: { ...formData.stats, runs: parseInt(e.target.value) || 0 }
                  })}
                  className="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Wickets
                </label>
                <input
                  type="number"
                  min="0"
                  value={formData.stats.wickets}
                  onChange={(e) => setFormData({
                    ...formData,
                    stats: { ...formData.stats, wickets: parseInt(e.target.value) || 0 }
                  })}
                  className="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Average
                </label>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={formData.stats.average}
                  onChange={(e) => setFormData({
                    ...formData,
                    stats: { ...formData.stats, average: parseFloat(e.target.value) || 0 }
                  })}
                  className="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none"
                />
              </div>
            </div>
          </div>

          <div className="flex space-x-3 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-6 py-3 border-2 border-gray-300 rounded-lg font-medium text-gray-700 hover:bg-gray-50 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className="flex-1 px-6 py-3 bg-yellow-500 hover:bg-yellow-600 text-black font-bold rounded-lg transition-colors disabled:opacity-50"
            >
              {loading ? 'Updating...' : 'Update Player'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
