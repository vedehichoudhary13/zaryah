/*
  # Marketing and Engagement Features

  1. New Tables
    - `newsletters` - Newsletter subscriptions
    - `referral_codes` - User referral system
    - `loyalty_points` - Customer loyalty program
    - `flash_sales` - Time-limited sales
    - `product_bundles` - Product bundle offers
    - `user_preferences` - User shopping preferences
    
  2. Features
    - Newsletter management
    - Referral program
    - Loyalty points system
    - Flash sales and promotions
    - Product bundles
    - User preference tracking
    
  3. Security
    - Enable RLS on all new tables
    - Add appropriate policies
*/

-- Newsletter Subscriptions
CREATE TABLE IF NOT EXISTS newsletters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE NOT NULL,
  user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  is_subscribed boolean DEFAULT true,
  preferences jsonb DEFAULT '{}', -- email preferences
  subscribed_at timestamptz DEFAULT now(),
  unsubscribed_at timestamptz,
  source text DEFAULT 'website' -- 'website', 'checkout', 'popup'
);

-- Referral System
CREATE TABLE IF NOT EXISTS referral_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  code text UNIQUE NOT NULL,
  discount_type discount_type NOT NULL,
  discount_value numeric NOT NULL,
  usage_limit integer,
  used_count integer DEFAULT 0,
  referrer_reward_type text, -- 'points', 'discount', 'cash'
  referrer_reward_value numeric,
  is_active boolean DEFAULT true,
  expires_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Loyalty Points System
CREATE TABLE IF NOT EXISTS loyalty_points (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  points integer NOT NULL,
  transaction_type text NOT NULL, -- 'earned', 'redeemed', 'expired', 'adjusted'
  source text NOT NULL, -- 'purchase', 'referral', 'review', 'birthday', 'manual'
  order_id uuid REFERENCES orders(id) ON DELETE SET NULL,
  description text,
  expires_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Flash Sales
CREATE TABLE IF NOT EXISTS flash_sales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  discount_type discount_type NOT NULL,
  discount_value numeric NOT NULL,
  product_ids uuid[], -- specific products
  category_names text[], -- or entire categories
  min_order_amount integer,
  max_discount_amount integer,
  usage_limit integer,
  used_count integer DEFAULT 0,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  is_active boolean DEFAULT true,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now()
);

-- Product Bundles
CREATE TABLE IF NOT EXISTS product_bundles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  product_ids uuid[] NOT NULL, -- array of product IDs
  bundle_price integer NOT NULL, -- total bundle price in paise
  discount_amount integer NOT NULL, -- savings amount
  is_active boolean DEFAULT true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- User Shopping Preferences
CREATE TABLE IF NOT EXISTS user_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  preferred_categories text[],
  preferred_price_range jsonb, -- {'min': 100, 'max': 5000}
  preferred_delivery_type delivery_type DEFAULT 'standard',
  notification_preferences jsonb DEFAULT '{}',
  browsing_history jsonb DEFAULT '[]', -- recently viewed products
  search_history text[],
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id)
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_newsletters_email ON newsletters(email);
CREATE INDEX IF NOT EXISTS idx_newsletters_subscribed ON newsletters(is_subscribed);
CREATE INDEX IF NOT EXISTS idx_referral_codes_user ON referral_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON referral_codes(code);
CREATE INDEX IF NOT EXISTS idx_referral_codes_active ON referral_codes(is_active);
CREATE INDEX IF NOT EXISTS idx_loyalty_points_user ON loyalty_points(user_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_points_type ON loyalty_points(transaction_type);
CREATE INDEX IF NOT EXISTS idx_loyalty_points_created ON loyalty_points(created_at);
CREATE INDEX IF NOT EXISTS idx_flash_sales_active ON flash_sales(is_active);
CREATE INDEX IF NOT EXISTS idx_flash_sales_dates ON flash_sales(starts_at, ends_at);
CREATE INDEX IF NOT EXISTS idx_product_bundles_active ON product_bundles(is_active);
CREATE INDEX IF NOT EXISTS idx_user_preferences_user ON user_preferences(user_id);

-- Enable RLS
ALTER TABLE newsletters ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE loyalty_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE flash_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_bundles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

-- RLS Policies for newsletters
CREATE POLICY "Users can manage their own newsletter subscription"
  ON newsletters FOR ALL
  TO authenticated
  USING (user_id = auth.uid() OR email = auth.email());

CREATE POLICY "Admins can manage all newsletter subscriptions"
  ON newsletters FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

-- RLS Policies for referral_codes
CREATE POLICY "Users can read their own referral codes"
  ON referral_codes FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can create their own referral codes"
  ON referral_codes FOR INSERT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Anyone can read active referral codes for validation"
  ON referral_codes FOR SELECT
  TO anon, authenticated
  USING (is_active = true AND (expires_at IS NULL OR expires_at > now()));

CREATE POLICY "Admins can manage all referral codes"
  ON referral_codes FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

-- RLS Policies for loyalty_points
CREATE POLICY "Users can read their own loyalty points"
  ON loyalty_points FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "System can create loyalty points"
  ON loyalty_points FOR INSERT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can manage all loyalty points"
  ON loyalty_points FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

-- RLS Policies for flash_sales
CREATE POLICY "Anyone can read active flash sales"
  ON flash_sales FOR SELECT
  TO anon, authenticated
  USING (is_active = true AND starts_at <= now() AND ends_at >= now());

CREATE POLICY "Admins can manage flash sales"
  ON flash_sales FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

-- RLS Policies for product_bundles
CREATE POLICY "Anyone can read active product bundles"
  ON product_bundles FOR SELECT
  TO anon, authenticated
  USING (is_active = true AND (starts_at IS NULL OR starts_at <= now()) AND (ends_at IS NULL OR ends_at >= now()));

CREATE POLICY "Admins can manage product bundles"
  ON product_bundles FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

-- RLS Policies for user_preferences
CREATE POLICY "Users can manage their own preferences"
  ON user_preferences FOR ALL
  TO authenticated
  USING (user_id = auth.uid());

-- Add triggers for updated_at
CREATE TRIGGER update_product_bundles_updated_at
    BEFORE UPDATE ON product_bundles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_preferences_updated_at
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to calculate user's total loyalty points
CREATE OR REPLACE FUNCTION get_user_loyalty_balance(user_uuid uuid)
RETURNS integer AS $$
BEGIN
  RETURN COALESCE((
    SELECT SUM(
      CASE 
        WHEN transaction_type = 'earned' THEN points
        WHEN transaction_type = 'redeemed' THEN -points
        WHEN transaction_type = 'expired' THEN -points
        WHEN transaction_type = 'adjusted' THEN points
        ELSE 0
      END
    )
    FROM loyalty_points 
    WHERE user_id = user_uuid
    AND (expires_at IS NULL OR expires_at > now())
  ), 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;