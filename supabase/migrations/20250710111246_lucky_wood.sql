/*
  # Fix Seller Registration and Approval Workflow

  1. Database Changes
    - Add seller approval status tracking
    - Add email verification fields
    - Update RLS policies for seller access

  2. Security
    - Sellers can only access dashboard after admin approval
    - Email notifications for approval status
*/

-- Add seller-specific fields to profiles table
DO $$
BEGIN
  -- Add approval_status column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'approval_status'
  ) THEN
    ALTER TABLE profiles ADD COLUMN approval_status text DEFAULT 'pending' CHECK (approval_status IN ('pending', 'approved', 'rejected'));
  END IF;

  -- Add approved_at column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'approved_at'
  ) THEN
    ALTER TABLE profiles ADD COLUMN approved_at timestamptz;
  END IF;

  -- Add approved_by column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'approved_by'
  ) THEN
    ALTER TABLE profiles ADD COLUMN approved_by uuid REFERENCES profiles(id);
  END IF;

  -- Add rejection_reason column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'rejection_reason'
  ) THEN
    ALTER TABLE profiles ADD COLUMN rejection_reason text;
  END IF;
END $$;

-- Update existing sellers to have proper approval status
UPDATE profiles 
SET approval_status = CASE 
  WHEN role = 'seller' AND is_verified = true THEN 'approved'
  WHEN role = 'seller' AND is_verified = false THEN 'pending'
  ELSE 'approved'
END
WHERE approval_status IS NULL;

-- Update RLS policies for seller access
DROP POLICY IF EXISTS "Sellers can insert own products" ON products;
DROP POLICY IF EXISTS "Sellers can update own products" ON products;

-- New policy: Only approved sellers can manage products
CREATE POLICY "Approved sellers can insert own products"
  ON products FOR INSERT
  TO authenticated
  WITH CHECK (
    (auth.uid() = seller_id) AND 
    (EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'seller' 
      AND profiles.approval_status = 'approved'
    ))
  );

CREATE POLICY "Approved sellers can update own products"
  ON products FOR UPDATE
  TO authenticated
  USING (
    (auth.uid() = seller_id) AND 
    (EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'seller' 
      AND profiles.approval_status = 'approved'
    ))
  );

-- Function to approve seller
CREATE OR REPLACE FUNCTION approve_seller(
  seller_id uuid,
  admin_id uuid
)
RETURNS boolean AS $$
BEGIN
  -- Check if admin has permission
  IF NOT EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = admin_id AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can approve sellers';
  END IF;

  -- Update seller status
  UPDATE profiles 
  SET 
    approval_status = 'approved',
    is_verified = true,
    approved_at = now(),
    approved_by = admin_id,
    updated_at = now()
  WHERE id = seller_id AND role = 'seller';

  -- Create notification for seller
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    seller_id,
    'system',
    'Seller Account Approved! 🎉',
    'Congratulations! Your seller account has been approved. You can now start listing your products and begin your journey with us.',
    jsonb_build_object(
      'approval_status', 'approved',
      'approved_at', now(),
      'dashboard_url', '/seller/dashboard'
    )
  );

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to reject seller
CREATE OR REPLACE FUNCTION reject_seller(
  seller_id uuid,
  admin_id uuid,
  reason text DEFAULT 'Application did not meet our requirements'
)
RETURNS boolean AS $$
BEGIN
  -- Check if admin has permission
  IF NOT EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = admin_id AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can reject sellers';
  END IF;

  -- Update seller status
  UPDATE profiles 
  SET 
    approval_status = 'rejected',
    is_verified = false,
    approved_at = now(),
    approved_by = admin_id,
    rejection_reason = reason,
    updated_at = now()
  WHERE id = seller_id AND role = 'seller';

  -- Create notification for seller
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    seller_id,
    'system',
    'Seller Application Update',
    'Thank you for your interest in joining our platform. Unfortunately, your application was not approved at this time. Reason: ' || reason,
    jsonb_build_object(
      'approval_status', 'rejected',
      'rejection_reason', reason
    )
  );

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add index for approval status
CREATE INDEX IF NOT EXISTS idx_profiles_approval_status ON profiles(approval_status);
CREATE INDEX IF NOT EXISTS idx_profiles_role_approval ON profiles(role, approval_status);