# Multi-Venue IPL Auction System - Login Credentials

## System Overview

The IPL Auction system now supports **4 independent auction venues**, each with:
- 1 Admin account
- 10 Team accounts
- 50 Players (independent pool per venue)
- Separate auction records

All data is isolated per venue using Row Level Security (RLS).

---

## 🏟️ VENUE 1: MUMBAI

### Admin Login
- **Email:** `mumbai@ipl.venue`
- **Password:** `Mumbai@2024`

### Team Logins (10 Teams)
| Team | Email | Password |
|------|-------|----------|
| CSK | mumbai.csk@ipl.team | mumbaiCSK@2024 |
| MI | mumbai.mi@ipl.team | mumbaiMI@2024 |
| RCB | mumbai.rcb@ipl.team | mumbaiRCB@2024 |
| GT | mumbai.gt@ipl.team | mumbaiGT@2024 |
| KKR | mumbai.kkr@ipl.team | mumbaiKKR@2024 |
| SRH | mumbai.srh@ipl.team | mumbaiSRH@2024 |
| DC | mumbai.dc@ipl.team | mumbaiDC@2024 |
| PBKS | mumbai.pbks@ipl.team | mumbaiPBKS@2024 |
| LSG | mumbai.lsg@ipl.team | mumbaiLSG@2024 |
| RR | mumbai.rr@ipl.team | mumbaiRR@2024 |

---

## 🏟️ VENUE 2: DELHI

### Admin Login
- **Email:** `delhi@ipl.venue`
- **Password:** `Delhi@2024`

### Team Logins (10 Teams)
| Team | Email | Password |
|------|-------|----------|
| CSK | delhi.csk@ipl.team | delhiCSK@2024 |
| MI | delhi.mi@ipl.team | delhiMI@2024 |
| RCB | delhi.rcb@ipl.team | delhiRCB@2024 |
| GT | delhi.gt@ipl.team | delhiGT@2024 |
| KKR | delhi.kkr@ipl.team | delhiKKR@2024 |
| SRH | delhi.srh@ipl.team | delhiSRH@2024 |
| DC | delhi.dc@ipl.team | delhiDC@2024 |
| PBKS | delhi.pbks@ipl.team | delhiPBKS@2024 |
| LSG | delhi.lsg@ipl.team | delhiLSG@2024 |
| RR | delhi.rr@ipl.team | delhiRR@2024 |

---

## 🏟️ VENUE 3: BANGALORE

### Admin Login
- **Email:** `bangalore@ipl.venue`
- **Password:** `Bangalore@2024`

### Team Logins (10 Teams)
| Team | Email | Password |
|------|-------|----------|
| CSK | bangalore.csk@ipl.team | bangaloreCSK@2024 |
| MI | bangalore.mi@ipl.team | bangaloreMI@2024 |
| RCB | bangalore.rcb@ipl.team | bangaloreRCB@2024 |
| GT | bangalore.gt@ipl.team | bangaloreGT@2024 |
| KKR | bangalore.kkr@ipl.team | bangaloreKKR@2024 |
| SRH | bangalore.srh@ipl.team | bangaloreSRH@2024 |
| DC | bangalore.dc@ipl.team | bangaloreDC@2024 |
| PBKS | bangalore.pbks@ipl.team | bangalorePBKS@2024 |
| LSG | bangalore.lsg@ipl.team | bangaloreLSG@2024 |
| RR | bangalore.rr@ipl.team | bangaloreRR@2024 |

---

## 🏟️ VENUE 4: KOLKATA

### Admin Login
- **Email:** `kolkata@ipl.venue`
- **Password:** `Kolkata@2024`

### Team Logins (10 Teams)
| Team | Email | Password |
|------|-------|----------|
| CSK | kolkata.csk@ipl.team | kolkataCSK@2024 |
| MI | kolkata.mi@ipl.team | kolkataMI@2024 |
| RCB | kolkata.rcb@ipl.team | kolkataRCB@2024 |
| GT | kolkata.gt@ipl.team | kolkataGT@2024 |
| KKR | kolkata.kkr@ipl.team | kolkataKKR@2024 |
| SRH | kolkata.srh@ipl.team | kolkataSRH@2024 |
| DC | kolkata.dc@ipl.team | kolkataDC@2024 |
| PBKS | kolkata.pbks@ipl.team | kolkataPBKS@2024 |
| LSG | kolkata.lsg@ipl.team | kolkataLSG@2024 |
| RR | kolkata.rr@ipl.team | kolkataRR@2024 |

---

## 📊 Database Structure

### Tables
- **venues** - 4 venues (Mumbai, Delhi, Bangalore, Kolkata)
- **teams** - 40 teams (10 per venue)
- **players** - 200 players (50 per venue)
- **auctions** - Venue-specific auction records
- **user_profiles** - Links auth users to venues and teams

### Row Level Security (RLS)
- Users can ONLY see data from their assigned venue
- Admins can manage players/teams in their venue only
- Teams can view only their venue's data
- Complete data isolation between venues

---

## 🚀 Quick Start

1. **Admin Access:**
   - Login with any venue admin credentials
   - Manage teams and players for that venue
   - Conduct auction for that venue

2. **Team Access:**
   - Login with team credentials
   - View players available in your venue
   - Participate in your venue's auction

3. **Testing Multi-Venue:**
   - Open 4 different browsers/incognito windows
   - Login to each venue's admin
   - Run simultaneous auctions
   - Data remains completely isolated

---

## 🔧 Technical Details

### Player Pool
Each venue has 50 players:
- 20 Batsmen
- 15 Bowlers
- 10 All-Rounders
- 5 Wicketkeepers

### Team Budget
- Total Purse: ₹100 Crores (1,000,000,000)
- Purse Remaining: Updates after each purchase

### Auction Features
- Random player selection with spinning animation
- Live bidding system
- Real-time team budget updates
- Player sold status tracking

---

## 📝 Notes

- All venues are completely independent
- No data sharing between venues
- Each venue can run auctions simultaneously
- RLS ensures data security and isolation
- User credentials are per-venue specific

---

## 🆘 Troubleshooting

**Cannot see players/teams:**
- Verify you're logged in with correct venue credentials
- Check that you're accessing your venue's data

**Auction not starting:**
- Ensure no other auction is active in your venue
- Verify admin permissions for your venue

**Login issues:**
- Double-check email and password
- Ensure using correct venue prefix

---

## 🎉 Summary

- **4 Venues** ✓
- **4 Admin Accounts** ✓
- **40 Team Accounts** (10 per venue) ✓
- **200 Players** (50 per venue) ✓
- **Complete Data Isolation** ✓
- **Simultaneous Auctions** ✓
