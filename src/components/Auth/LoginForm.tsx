import React, { useState } from 'react';
import { Trophy, User, Lock } from 'lucide-react';
import { useAuth } from '../../hooks/useAuth';
import toast from 'react-hot-toast'; // Assuming you use react-hot-toast for notifications

export function LoginForm() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const { signIn } = useAuth();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    // --- FIX: Added try...catch...finally block for robust error handling ---
    try {
      await signIn(email, password);
      // On success, the AuthProvider will redirect the user.
      // A success toast is optional here, as the redirect is clear feedback.
    } catch (error: any) {
      // On failure, show a user-friendly error message.
      console.error('Login failed:', error);
      toast.error(error.message || 'Invalid email or password. Please try again.');
    } finally {
      // This block ensures the loading state is reset even if an error occurs.
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-yellow-400 via-yellow-500 to-yellow-600 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-md border-4 border-black">
        <div className="text-center mb-8">
          <div className="bg-black rounded-full p-4 w-20 h-20 mx-auto mb-4">
            <Trophy className="h-12 w-12 text-yellow-500" />
          </div>
          <h1 className="text-3xl font-bold text-black mb-2">IPL Auction</h1>
          <p className="text-gray-600">Sign in to access the auction platform</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            {/* ACCESSIBILITY FIX: Added htmlFor to connect label with input */}
            <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-2">
              Email Address
            </label>
            <div className="relative">
              {/* ACCESSIBILITY FIX: Added aria-hidden for decorative icon */}
              <User className="absolute left-3 top-3 h-5 w-5 text-gray-400" aria-hidden="true" />
              <input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full pl-10 pr-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none transition-all"
                placeholder="Enter your email"
                required
              />
            </div>
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-2">
              Password
            </label>
            <div className="relative">
              <Lock className="absolute left-3 top-3 h-5 w-5 text-gray-400" aria-hidden="true" />
              <input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full pl-10 pr-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none transition-all"
                placeholder="Enter your password"
                required
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-black text-yellow-500 font-bold py-3 px-4 rounded-lg hover:bg-gray-800 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? 'Signing in...' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  );
}
