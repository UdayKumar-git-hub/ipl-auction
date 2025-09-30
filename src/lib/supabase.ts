import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://jdwjxystnzlhuvtaofrh.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impkd2p4eXN0bnpsaHV2dGFvZnJoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkyNTgxNDIsImV4cCI6MjA3NDgzNDE0Mn0.TwiRww2aoHlelWrKb56t3v65AAbHSrZclYNt2mmZyk4';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);