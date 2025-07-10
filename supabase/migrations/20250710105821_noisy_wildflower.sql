/*
  # Fix User Role Registration Issues

  1. Updates
    - Ensure proper role handling in profiles table
    - Add constraints to validate roles
    - Update RLS policies for proper role-based access

  2. Security
    - Maintain existing RLS policies
    - Add role validation constraints
*/

-- Ensure the user_role enum exists with all required values
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('buyer', 'seller', 'admin');
    END IF;
END $$;

-- Update profiles table to ensure role column uses the enum
DO $$
BEGIN
    -- Check if role column exists and update it if needed
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'role'
    ) THEN
        -- Ensure the column uses the enum type
        ALTER TABLE profiles ALTER COLUMN role TYPE user_role USING role::user_role;
        
        -- Set default value
        ALTER TABLE profiles ALTER COLUMN role SET DEFAULT 'buyer'::user_role;
    END IF;
END $$;

-- Add constraint to ensure valid roles
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints 
        WHERE constraint_name = 'profiles_role_check'
    ) THEN
        ALTER TABLE profiles ADD CONSTRAINT profiles_role_check 
        CHECK (role IN ('buyer', 'seller', 'admin'));
    END IF;
END $$;

-- Update RLS policies to handle roles properly
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile"
  ON profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = id AND
    role IN ('buyer', 'seller', 'admin')
  );

-- Ensure sellers have proper verification requirements
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile"
  ON profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id AND
    -- Sellers must have required fields when verified
    (role != 'seller' OR (
      mobile IS NOT NULL AND 
      length(trim(mobile)) > 0 AND
      verification_doc IS NOT NULL AND 
      length(trim(verification_doc)) > 0
    ) OR is_verified = false)
  );

-- Function to handle new user registration
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  -- Only create profile if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = NEW.id) THEN
    INSERT INTO profiles (
      id, 
      name, 
      role, 
      city, 
      is_verified,
      business_name,
      description,
      mobile,
      verification_doc
    ) VALUES (
      NEW.id,
      COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
      COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'buyer'::user_role),
      COALESCE(NEW.raw_user_meta_data->>'city', 'Mumbai'),
      CASE 
        WHEN COALESCE((NEW.raw_user_meta_data->>'role')::text, 'buyer') IN ('buyer', 'admin') THEN true
        ELSE false
      END,
      NEW.raw_user_meta_data->>'business_name',
      NEW.raw_user_meta_data->>'description',
      NEW.raw_user_meta_data->>'mobile',
      NEW.raw_user_meta_data->>'verification_doc'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user registration
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Update existing users without proper roles (if any)
UPDATE profiles 
SET role = 'buyer'::user_role 
WHERE role IS NULL;

-- Ensure is_verified is properly set based on role
UPDATE profiles 
SET is_verified = true 
WHERE role IN ('buyer', 'admin') AND is_verified = false;

-- Ensure sellers without required fields are not verified
UPDATE profiles 
SET is_verified = false 
WHERE role = 'seller' AND (
  mobile IS NULL OR 
  length(trim(mobile)) = 0 OR 
  verification_doc IS NULL OR 
  length(trim(verification_doc)) = 0
);