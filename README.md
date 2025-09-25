# IPL Auction Website

A modern, full-featured IPL Auction platform built with React, TypeScript, and Supabase. Features real-time bidding, comprehensive player management, and separate dashboards for administrators and team owners.

![IPL Auction Website](https://images.pexels.com/photos/274506/pexels-photo-274506.jpeg?auto=compress&cs=tinysrgb&w=1200&h=400&fit=crop)

## 🏏 Features

### Authentication System
- **Admin Login**: Full access to manage auctions, players, and teams
- **Team Login**: View-only access for team owners to track their squad and auction progress
- Secure role-based authentication with Supabase

### Admin Dashboard
- ✅ Add/Edit/Delete 160+ preloaded cricket players
- ✅ Update team purse values and squad information
- ✅ Assign/sell players to teams during auctions
- ✅ Real-time updates across all connected dashboards
- ✅ Reset auctions and start new seasons
- ✅ Live auction control panel with bidding system

### Team Dashboard (Viewer Mode)
- 📊 View complete squad list organized by player roles
- 💰 Track remaining purse and spending analytics
- 📈 Real-time auction progress monitoring
- 📋 Detailed player statistics and performance metrics
- 🎯 Squad composition analysis by role

### Live Auction System
- 🎲 **Random Player Selection**: Randomly pick players for auction
- 🏷️ Display current player with detailed information
- 💵 Dynamic bidding with customizable increment buttons
- 🏆 Assign players to teams with real-time purse updates
- 📱 Responsive auction interface for all devices

### Player Database
- 🗃️ 160+ preloaded cricket players with comprehensive data
- 🔍 Advanced search, filter, and sort functionality
- 📊 Player categorization: Batsmen, Bowlers, All-Rounders, Wicketkeepers
- 📸 Player photos and detailed career statistics
- 🌍 Country-wise player filtering

### Modern UI & Design
- 🎨 Yellow-black theme inspired by IPL branding
- 📱 Fully responsive design for all screen sizes
- 🎯 Clean, intuitive dashboard layouts
- 📊 Interactive cards, tables, and data visualization
- ⚡ Smooth animations and micro-interactions

## 🚀 Tech Stack

- **Frontend**: React 18 + TypeScript + Vite
- **Styling**: Tailwind CSS
- **Backend**: Supabase (PostgreSQL + Auth + Real-time)
- **Icons**: Lucide React
- **Routing**: React Router DOM
- **Notifications**: React Hot Toast
- **Charts**: Recharts
- **Animations**: Framer Motion

## 📦 Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd ipl-auction-website
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Set up environment variables**
   ```bash
   cp .env.example .env
   ```

4. **Connect to Supabase**
   - Click the "Connect to Supabase" button in the top right of the interface
   - This will automatically set up your database and populate the `.env` file

5. **Start the development server**
   ```bash
   npm run dev
   ```

## 🔧 Configuration

### Environment Variables
```env
VITE_SUPABASE_URL=your_supabase_project_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

### Demo Accounts
- **Admin**: `admin@ipl.com` / `admin123`
- **Team (CSK)**: `csk@ipl.com` / `team123`
- **Team (MI)**: `mi@ipl.com` / `team123`
- **Team (RCB)**: `rcb@ipl.com` / `team123`
- **Team (GT)**: `gt@ipl.com` / `team123`
- **Team (KKR)**: `kkr@ipl.com` / `team123`
- **Team (SRH)**: `srh@ipl.com` / `team123`
- **Team (DC)**: `dc@ipl.com` / `team123`
- **Team (PBKS)**: `pbks@ipl.com` / `team123`
- **Team (LSG)**: `lsg@ipl.com` / `team123`
- **Team (RR)**: `rr@ipl.com` / `team123`

## 🏗️ Database Schema

### Tables
- **user_profiles**: User authentication and role management
- **teams**: IPL team information and purse tracking
- **players**: Comprehensive player database with stats
- **auctions**: Live auction tracking and bidding history

### Key Features
- Row Level Security (RLS) enabled on all tables
- Real-time subscriptions for live updates
- Optimized queries for performance
- Data integrity with foreign key constraints

## 🎮 Usage

### For Administrators
1. **Login** with admin credentials
2. **Manage Players**: Add, edit, or remove players from the database
3. **Manage Teams**: Update team information and purse values
4. **Run Auctions**: Use the live auction panel to conduct player bidding
5. **Random Selection**: Use the random player feature for fair selection
6. **Track Progress**: Monitor all team activities in real-time

### For Team Owners
1. **Login** with team credentials
2. **View Squad**: See your current team composition
3. **Track Purse**: Monitor spending and remaining budget
4. **Follow Auctions**: Watch live auction progress
5. **Analyze Performance**: Review player statistics and team analytics

## 🔄 Real-time Features

- **Live Auction Updates**: All connected users see bidding in real-time
- **Purse Tracking**: Instant updates when players are sold
- **Squad Changes**: Real-time squad composition updates
- **Notification System**: Toast notifications for important events

## 📊 Player Categories

### Batsmen
- Top-order batsmen with high strike rates
- Middle-order anchors and finishers
- Aggressive power hitters

### Bowlers
- Fast bowlers with pace and swing
- Spin bowlers with variations
- Death-over specialists

### All-Rounders
- Batting all-rounders
- Bowling all-rounders
- Genuine all-rounders with balanced skills

### Wicketkeepers
- Wicketkeeper-batsmen
- Specialist wicketkeepers
- Finisher wicketkeepers

## 🎯 Auction Process

1. **Player Selection**: Admin selects or randomly picks a player
2. **Player Display**: Detailed player information is shown
3. **Bidding**: Teams can bid through the admin interface
4. **Price Updates**: Real-time bid amount updates
5. **Team Assignment**: Player is sold to the highest bidding team
6. **Purse Update**: Team purse is automatically updated
7. **Squad Update**: Player is added to the team's squad

## 🔒 Security Features

- **Role-based Access Control**: Separate permissions for admin and team users
- **Row Level Security**: Database-level security policies
- **Secure Authentication**: Supabase Auth with email/password
- **Data Validation**: Input validation and sanitization
- **Protected Routes**: Route-level authentication checks

## 📱 Responsive Design

- **Mobile First**: Optimized for mobile devices
- **Tablet Support**: Perfect layout for tablet viewing
- **Desktop Experience**: Full-featured desktop interface
- **Cross-browser**: Compatible with all modern browsers

## 🚀 Deployment

The application is ready for deployment on platforms like:
- **Vercel** (Recommended for React apps)
- **Netlify**
- **Railway**
- **Heroku**

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- IPL for inspiration and cricket data
- Supabase for the excellent backend platform
- React and TypeScript communities
- Tailwind CSS for the utility-first styling approach

## 📞 Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the documentation

---

**Built with ❤️ for cricket fans and auction enthusiasts**