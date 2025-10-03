import React, { useState } from 'react';
import { Edit, Trash2, User, MapPin, DollarSign } from 'lucide-react';
import { Player } from '../../types';
import { supabase } from '../../lib/supabase';
import toast from 'react-hot-toast';
import { EditPlayerModal } from './EditPlayerModal';

interface PlayerCardProps {
  player: Player;
  onUpdate: () => void;
}

export function PlayerCard({ player, onUpdate }: PlayerCardProps) {
  const [loading, setLoading] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);

  const handleDelete = async () => {
    if (!confirm('Are you sure you want to delete this player?')) return;

    setLoading(true);
    try {
      const { error } = await supabase
        .from('players')
        .delete()
        .eq('id', player.id);

      if (error) throw error;

      toast.success('Player deleted successfully');
      onUpdate();
    } catch (error) {
      console.error('Error deleting player:', error);
      toast.error('Error deleting player');
    } finally {
      setLoading(false);
    }
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
    <div className="bg-white rounded-xl shadow-lg overflow-hidden hover:shadow-xl transition-shadow border-2 border-gray-200">
      <div className="relative">
        <img
          src={player.photo_url}
          alt={player.name}
          className="w-full h-48 object-cover"
        />
        <div className="absolute top-2 right-2">
          <span className={`px-2 py-1 rounded-full text-xs font-medium ${getRoleColor(player.role)}`}>
            {player.role}
          </span>
        </div>
        {player.is_sold && (
          <div className="absolute top-2 left-2">
            <span className="bg-green-500 text-white px-2 py-1 rounded-full text-xs font-medium">
              SOLD
            </span>
          </div>
        )}
      </div>

      <div className="p-4">
        <h3 className="text-lg font-bold text-gray-900 mb-2">{player.name}</h3>
        
        <div className="space-y-2 mb-4">
          <div className="flex items-center space-x-2 text-sm text-gray-600">
            <MapPin className="h-4 w-4" />
            <span>{player.country}</span>
          </div>
          <div className="flex items-center space-x-2 text-sm text-gray-600">
            <DollarSign className="h-4 w-4" />
            <span>Base: ₹{player.base_price.toLocaleString()}</span>
          </div>
          {player.is_sold && player.current_price && (
            <div className="flex items-center space-x-2 text-sm font-medium text-green-600">
              <DollarSign className="h-4 w-4" />
              <span>Sold: ₹{player.current_price.toLocaleString()}</span>
            </div>
          )}
        </div>

        <div className="bg-gray-50 rounded-lg p-3 mb-4">
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

        <div className="flex space-x-2">
          <button
            onClick={() => setShowEditModal(true)}
            className="flex-1 flex items-center justify-center space-x-1 bg-yellow-500 hover:bg-yellow-600 text-black font-medium px-3 py-2 rounded-lg transition-colors"
          >
            <Edit className="h-4 w-4" />
            <span>Edit</span>
          </button>
          <button
            onClick={handleDelete}
            disabled={loading}
            className="flex-1 flex items-center justify-center space-x-1 bg-red-500 hover:bg-red-600 text-white font-medium px-3 py-2 rounded-lg transition-colors disabled:opacity-50"
          >
            <Trash2 className="h-4 w-4" />
            <span>Delete</span>
          </button>
        </div>
      </div>

      {showEditModal && (
        <EditPlayerModal
          player={player}
          onClose={() => setShowEditModal(false)}
          onSuccess={() => {
            setShowEditModal(false);
            onUpdate();
          }}
        />
      )}
    </div>
  );
}