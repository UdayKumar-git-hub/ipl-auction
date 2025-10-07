# IPL Auction Admin Setup Guide

## Multi-Venue Admin Accounts

This IPL auction system supports **4 simultaneous auction venues**, each with its own admin login.

### 🎯 Admin Login Credentials

Use these credentials to login at different venues:

#### **Venue 1 Admin**
- **Email:** `venue1@ipl.admin`
- **Password:** `IPLVenue1@2024`

#### **Venue 2 Admin**
- **Email:** `venue2@ipl.admin`
- **Password:** `IPLVenue2@2024`

#### **Venue 3 Admin**
- **Email:** `venue3@ipl.admin`
- **Password:** `IPLVenue3@2024`

#### **Venue 4 Admin**
- **Email:** `venue4@ipl.admin`
- **Password:** `IPLVenue4@2024`

---

## 🚀 Quick Setup Instructions

### Option 1: Auto-Create via Script (Recommended)

1. Ensure you have the Supabase service role key in your `.env` file:
   ```
   SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
   ```

2. Run the admin creation script:
   ```bash
   npm run create-admins
   ```

3. All 4 admin accounts will be created automatically.

### Option 2: Manual Sign-Up

If you don't have the service role key, sign up manually for each admin:

1. Go to the login page
2. Click "Sign Up" (if available) or use the sign-up endpoint
3. Create each account with the emails and passwords listed above

### Option 3: Via Supabase Dashboard

1. Open your Supabase project dashboard
2. Go to **Authentication** → **Users**
3. Click **Add User** → **Create new user**
4. Enter each admin email and password from the list above
5. Confirm each user's email (toggle "Auto Confirm User")

---

## 🏟️ How Multiple Venues Work

- Each admin can log in from a different location/device
- All admins share the same player pool and teams
- Each venue can conduct auctions independently
- Players are marked as sold globally once purchased
- Real-time updates sync across all venues

---

## 🔐 Security Notes

- Change default passwords after first login (feature can be added)
- Each admin has the same permissions
- All auctions are logged in the database
- Session management prevents duplicate logins (optional feature)

---

## 📱 Usage Example

**Scenario:** IPL Auction at 4 Different Cities

1. **Mumbai Venue** - Admin logs in with `venue1@ipl.admin`
2. **Delhi Venue** - Admin logs in with `venue2@ipl.admin`
3. **Bangalore Venue** - Admin logs in with `venue3@ipl.admin`
4. **Kolkata Venue** - Admin logs in with `venue4@ipl.admin`

Each venue can:
- Select and auction players
- View available players
- Track team budgets
- Mark players as sold/unsold

---

## 🛠️ Troubleshooting

**Issue:** "User already exists" error
- **Solution:** User is already created, just login with the credentials

**Issue:** "Invalid login credentials"
- **Solution:** Double-check email and password, ensure email is confirmed

**Issue:** Can't access admin features
- **Solution:** Ensure the user metadata has `role: admin` set

---

## 📞 Support

For issues or questions, check the application logs or database records in Supabase dashboard.
