import React, { useState } from 'react';
import { Trophy, User, Lock, Eye, EyeOff } from 'lucide-react';
import { useAuth } from '../hooks/useAuth';
import toast from 'react-hot-toast';

export function LoginForm() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  // UX ENHANCEMENT: State to toggle password visibility
  const [showPassword, setShowPassword] = useState(false);
  const { signIn } = useAuth();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      await signIn(email, password);
      // On success, the AuthProvider will handle redirection.
      // A success toast here is optional as the redirect provides clear feedback.
      toast.success('Login successful! Redirecting...');
    } catch (error) {
      // The `signIn` function in the auth hook should re-throw the error.
      // Supabase provides user-friendly error messages, so we can display them directly.
      const errorMessage = error instanceof Error ? error.message : 'Invalid email or password.';
      console.error('Login failed:', errorMessage);
      toast.error(errorMessage);
    } finally {
      // Ensures the loading state is always reset.
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-yellow-400 via-yellow-500 to-yellow-600 flex items-center justify-center p-4 font-sans">
      <div className="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-md border-4 border-black transform transition-all duration-500 hover:scale-105">
        <div className="text-center mb-8">
          <div className="bg-black rounded-full p-4 w-20 h-20 mx-auto mb-4 flex items-center justify-center">
            <Trophy className="h-12 w-12 text-yellow-500" />
          </div>
          <h1 className="text-3xl font-bold text-black mb-2">IPL Auction</h1>
          <p className="text-gray-600">Sign in to access the auction platform</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-2">
              Email Address
            </label>
            <div className="relative">
              <User className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400" aria-hidden="true" />
              <input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full pl-10 pr-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none transition-all"
                placeholder="e.g., admin@ipl.com"
                required
                autoComplete="email"
              />
            </div>
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-2">
              Password
            </label>
            <div className="relative">
              <Lock className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400" aria-hidden="true" />
              <input
                id="password"
                // UX ENHANCEMENT: Dynamically set input type
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full pl-10 pr-12 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none transition-all"
                placeholder="Enter your password"
                required
                autoComplete="current-password"
              />
              {/* UX ENHANCEMENT: Button to toggle password visibility */}
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-700"
                aria-label={showPassword ? 'Hide password' : 'Show password'}
              >
                {showPassword ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
              </button>
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-black text-yellow-500 font-bold py-3 px-4 rounded-lg hover:bg-gray-800 transition-transform transform hover:-translate-y-1 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-yellow-500 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
          >
            {loading ? 'Signing in...' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  );
}

