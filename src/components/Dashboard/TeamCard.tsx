import React, { useState } from 'react';
import { Edit, Trophy, Users, DollarSign } from 'lucide-react';
import { Team } from '../../types';

interface TeamCardProps {
  team: Team;
  onUpdate: () => void;
}

export function TeamCard({ team, onUpdate }: TeamCardProps) {
  const [loading, setLoading] = useState(false);

  const purseUsed = team.total_purse - team.purse_remaining;
  const pursePercentage = (purseUsed / team.total_purse) * 100;

  return (
    <div className="bg-white rounded-xl shadow-lg overflow-hidden hover:shadow-xl transition-shadow border-2 border-gray-200">
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

          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-2 text-sm text-gray-600">
              <Trophy className="h-4 w-4" />
              <span>Purse Used</span>
            </div>
            <span className="font-medium">₹{(purseUsed / 10000000).toFixed(1)}Cr</span>
          </div>

          <div className="w-full bg-gray-200 rounded-full h-3">
            <div 
              className="bg-gradient-to-r from-yellow-500 to-yellow-600 h-3 rounded-full transition-all duration-300" 
              style={{ width: `${Math.min(pursePercentage, 100)}%` }}
            ></div>
          </div>
          <div className="text-center text-sm text-gray-500">
            {pursePercentage.toFixed(1)}% of purse used
          </div>
        </div>

        <button className="w-full mt-4 flex items-center justify-center space-x-2 bg-yellow-500 hover:bg-yellow-600 text-black font-medium px-4 py-2 rounded-lg transition-colors">
          <Edit className="h-4 w-4" />
          <span>Manage Team</span>
        </button>
      </div>
    </div>
  );
}