import React from 'react';
import { LogOut, Trophy, Users, Hammer } from 'lucide-react';
import { useAuth } from '../../hooks/useAuth';

export function Header() {
  const { user, signOut } = useAuth();

  return (
    <header className="bg-gradient-to-r from-yellow-500 to-yellow-600 shadow-lg border-b-4 border-black">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center py-4">
          <div className="flex items-center space-x-3">
            <div className="bg-black rounded-full p-2">
              <Trophy className="h-8 w-8 text-yellow-500" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-black">IPL Auction</h1>
              <p className="text-black/70 text-sm">2025 Season</p>
            </div>
          </div>

          <div className="flex items-center space-x-4">
            {user && (
              <>
                <div className="flex items-center space-x-2 bg-black/20 rounded-lg px-3 py-2">
                  <Users className="h-4 w-4 text-black" />
                  <span className="text-black font-medium">
                    {user.role === 'admin' ? 'Admin' : user.team_name}
                  </span>
                </div>
                <button
                  onClick={signOut}
                  className="flex items-center space-x-2 bg-black text-yellow-500 hover:bg-gray-800 px-4 py-2 rounded-lg transition-colors font-medium"
                >
                  <LogOut className="h-4 w-4" />
                  <span>Sign Out</span>
                </button>
              </>
            )}
          </div>
        </div>
      </div>
    </header>
  );
}