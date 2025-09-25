import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://obmzxsxxhjhrnqwymsmd.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9ibXp4c3h4aGpocm5xd3ltc21kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg2OTE5MDMsImV4cCI6MjA3NDI2NzkwM30.WVDy67Txjotmfs_Hqkcg1WkTiDHXDZ6OH6nFNWXd_OY';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);