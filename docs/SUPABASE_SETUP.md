# Supabase Setup Guide for Acha Karo MVP

## Status: Tables Already Exist

The following tables have already been created in your Supabase project:
- `profiles`
- `deeds`
- `moderation_queue`
- `badges`
- `user_badges`
- `campaigns`
- `app_config`
- `invite_codes`
- `friendships`
- `assigned_deeds`
- `feedback`
- `notifications`

## Next Steps: Verify & Fix

Run these verification queries in the Supabase SQL Editor to check your current schema:

### 1. Check profiles table structure
```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles'
ORDER BY ordinal_position;
```

### 2. Check deeds table structure
```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'deeds'
ORDER BY ordinal_position;
```

### 3. Verify RLS is enabled on all tables
```sql
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('profiles', 'deeds', 'moderation_queue', 'user_badges', 'campaigns', 'friendships', 'assigned_deeds', 'feedback', 'notifications')
ORDER BY tablename;
```

### 4. Check existing RLS policies
```sql
SELECT tablename, policyname
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename;
```

## If RLS Policies Are Missing

Run these to add missing policies:

### profiles table RLS
```sql
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own_profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "users_update_own_profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "users_insert_own_profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);
```

### deeds table RLS
```sql
ALTER TABLE deeds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own_deeds" ON deeds
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_deeds" ON deeds
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "moderators_select_all_deeds" ON deeds
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND (auth.users.raw_user_meta_data->>'role' = 'moderator' OR auth.users.raw_user_meta_data->>'role' = 'owner')
    )
  );
```

### moderation_queue table RLS
```sql
ALTER TABLE moderation_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "moderators_select_moderation_queue" ON moderation_queue
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND (auth.users.raw_user_meta_data->>'role' = 'moderator' OR auth.users.raw_user_meta_data->>'role' = 'owner')
    )
  );

CREATE POLICY "moderators_update_moderation_queue" ON moderation_queue
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND (auth.users.raw_user_meta_data->>'role' = 'moderator' OR auth.users.raw_user_meta_data->>'role' = 'owner')
    )
  );
```

### campaigns table RLS
```sql
ALTER TABLE campaigns ENABLE ROW LEVEL SECURITY;

CREATE POLICY "everyone_select_campaigns" ON campaigns
  FOR SELECT USING (true);

CREATE POLICY "owners_update_campaigns" ON campaigns
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'owner'
    )
  );
```

### app_config table RLS
```sql
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "everyone_select_config" ON app_config
  FOR SELECT USING (true);
```

### user_badges table RLS
```sql
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own_badges" ON user_badges
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users_upsert_own_badges" ON user_badges
  FOR INSERT WITH CHECK (auth.uid() = user_id);
```

### invite_codes table RLS
```sql
ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_insert_invite_codes" ON invite_codes
  FOR INSERT WITH CHECK (auth.uid() = issued_by);

CREATE POLICY "users_select_invite_codes" ON invite_codes
  FOR SELECT USING (auth.uid() = issued_by OR auth.uid() = used_by);

CREATE POLICY "users_update_invite_codes" ON invite_codes
  FOR UPDATE USING (true);
```

### friendships table RLS
```sql
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_insert_friendships" ON friendships
  FOR INSERT WITH CHECK (auth.uid() = requester_id);

CREATE POLICY "users_select_friendships" ON friendships
  FOR SELECT USING (auth.uid() = requester_id OR auth.uid() = addressee_id);
```

### assigned_deeds table RLS
```sql
ALTER TABLE assigned_deeds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_insert_assigned_deeds" ON assigned_deeds
  FOR INSERT WITH CHECK (auth.uid() = assigner_id);

CREATE POLICY "users_select_assigned_deeds" ON assigned_deeds
  FOR SELECT USING (auth.uid() = assigner_id OR auth.uid() = assignee_id);

CREATE POLICY "users_update_assigned_deeds" ON assigned_deeds
  FOR UPDATE USING (auth.uid() = assignee_id);
```

### feedback table RLS
```sql
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_insert_feedback" ON feedback
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_select_feedback" ON feedback
  FOR SELECT USING (auth.uid() = user_id);
```

### notifications table RLS
```sql
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users_update_notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "anyone_insert_notifications" ON notifications
  FOR INSERT WITH CHECK (true);
```

## Storage Setup

### Create deed-photos bucket
1. Go to Supabase Dashboard → Storage
2. Create new bucket named `deed-photos`
3. Make it **private** (not public)
4. Add storage policies:

```sql
CREATE POLICY "Users can upload their own deed photos" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'deed-photos' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can view their own deed photos" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'deed-photos' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
```

## Required Indexes (Performance)

```sql
CREATE INDEX IF NOT EXISTS idx_deeds_user_id ON deeds(user_id);
CREATE INDEX IF NOT EXISTS idx_deeds_created_at ON deeds(created_at);
CREATE INDEX IF NOT EXISTS idx_deeds_status ON deeds(status);
CREATE INDEX IF NOT EXISTS idx_moderation_queue_deed_id ON moderation_queue(deed_id);
CREATE INDEX IF NOT EXISTS idx_moderation_queue_outcome ON moderation_queue(outcome);
CREATE INDEX IF NOT EXISTS idx_user_badges_user_id ON user_badges(user_id);
CREATE INDEX IF NOT EXISTS idx_friendships_requester_id ON friendships(requester_id);
CREATE INDEX IF NOT EXISTS idx_friendships_addressee_id ON friendships(addressee_id);
CREATE INDEX IF NOT EXISTS idx_assigned_deeds_assigner_id ON assigned_deeds(assigner_id);
CREATE INDEX IF NOT EXISTS idx_assigned_deeds_assignee_id ON assigned_deeds(assignee_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
```

## Optional: Public Views for Analytics

```sql
-- View for deed cities (approved deeds only)
CREATE OR REPLACE VIEW public_deed_cities AS
SELECT d.type, p.city
FROM deeds d
JOIN profiles p ON d.user_id = p.id
WHERE d.status = 'approved';
```

## Troubleshooting

### If you get "permission denied" errors on inserts:
- Check that RLS policies allow the operation
- Verify the user is authenticated before inserting
- Check that `auth.uid()` matches the user_id in your policy

### If deeds/profiles never save:
- Run the verification queries above
- Check RLS policies are actually created
- Test a manual INSERT to see the exact error

### If app can't read campaigns:
- Verify `campaigns` table has the `everyone_select_campaigns` policy
- Make sure `active` column exists on `campaigns` table

## Next Steps

1. ✅ Run verification queries above
2. ✅ Add any missing RLS policies
3. ✅ Create storage bucket
4. ✅ Add indexes
5. ✅ Proceed to Flutter app testing