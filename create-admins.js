// Script to create 4 admin users for multi-venue IPL auction
// Run this once: node create-admins.js

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load environment variables
dotenv.config({ path: join(__dirname, '.env') });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('❌ Missing environment variables. Please check .env file.');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseAnonKey);

const adminUsers = [
  {
    email: 'venue1@ipl.admin',
    password: 'IPLVenue1@2024',
    venue: '1',
    name: 'Venue 1 Admin'
  },
  {
    email: 'venue2@ipl.admin',
    password: 'IPLVenue2@2024',
    venue: '2',
    name: 'Venue 2 Admin'
  },
  {
    email: 'venue3@ipl.admin',
    password: 'IPLVenue3@2024',
    venue: '3',
    name: 'Venue 3 Admin'
  },
  {
    email: 'venue4@ipl.admin',
    password: 'IPLVenue4@2024',
    venue: '4',
    name: 'Venue 4 Admin'
  }
];

async function createAdminUsers() {
  console.log('🚀 Creating 4 admin users for multi-venue IPL auction...\n');
  console.log('⚠️  Note: Email confirmation is required. Check your inbox if enabled.\n');

  for (const user of adminUsers) {
    try {
      const { data, error } = await supabase.auth.signUp({
        email: user.email,
        password: user.password,
        options: {
          data: {
            name: user.name,
            venue: user.venue,
            role: 'admin'
          }
        }
      });

      if (error) {
        if (error.message.includes('already registered') || error.message.includes('User already registered')) {
          console.log(`ℹ️  ${user.name} (${user.email}) - Already exists`);
        } else {
          console.error(`❌ ${user.name} (${user.email}) - Error: ${error.message}`);
        }
      } else {
        console.log(`✅ ${user.name} created successfully`);
        console.log(`   📧 Email: ${user.email}`);
        console.log(`   🔑 Password: ${user.password}`);
        console.log(`   🏟️  Venue: ${user.venue}`);
        if (data?.user && !data.user.email_confirmed_at) {
          console.log(`   ⚠️  Email confirmation required`);
        }
        console.log('');
      }
    } catch (err) {
      console.error(`❌ Error creating ${user.name}:`, err);
    }

    // Add a small delay between requests
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  console.log('\n✨ Admin user creation process completed!\n');
  console.log('📋 LOGIN CREDENTIALS SUMMARY:');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  adminUsers.forEach((user, index) => {
    console.log(`\nVenue ${index + 1}:`);
    console.log(`  Email:    ${user.email}`);
    console.log(`  Password: ${user.password}`);
  });
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
}

createAdminUsers().catch(console.error);
