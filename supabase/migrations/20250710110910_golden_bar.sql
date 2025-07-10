/*
  # Advanced E-commerce Features

  1. New Tables
    - `product_collections` - Curated product collections
    - `collection_products` - Many-to-many relationship
    - `shipping_zones` - Different shipping rates by location
    - `tax_rates` - Tax configuration by location
    - `abandoned_carts` - Track abandoned shopping carts
    - `product_recommendations` - AI/manual product recommendations
    
  2. Features
    - Product collections and bundles
    - Advanced shipping and tax management
    - Cart abandonment tracking
    - Product recommendation system
    
  3. Security
    - Enable RLS on all new tables
    - Add appropriate policies
*/

-- Product Collections (Featured, Seasonal, etc.)
CREATE TABLE IF NOT EXISTS product_collections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  slug text UNIQUE NOT NULL,
  image_url text,
  is_active boolean DEFAULT true,
  is_featured boolean DEFAULT false,
  sort_order integer DEFAULT 0,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Many-to-many relationship between collections and products
CREATE TABLE IF NOT EXISTS collection_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  collection_id uuid NOT NULL REFERENCES product_collections(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  UNIQUE(collection_id, product_id)
);

-- Shipping Zones for different delivery rates
CREATE TABLE IF NOT EXISTS shipping_zones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  countries text[] DEFAULT ARRAY['India'],
  states text[],
  cities text[],
  postal_codes text[],
  standard_rate integer NOT NULL, -- in paise
  express_rate integer,
  free_shipping_threshold integer, -- minimum order for free shipping
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Tax Rates by location
CREATE TABLE IF NOT EXISTS tax_rates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  rate numeric(5,4) NOT NULL, -- e.g., 0.18 for 18% GST
  countries text[] DEFAULT ARRAY['India'],
  states text[],
  cities text[],
  product_categories text[], -- apply to specific categories
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Abandoned Cart Tracking
CREATE TABLE IF NOT EXISTS abandoned_carts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  session_id text, -- for anonymous users
  cart_data jsonb NOT NULL,
  total_amount integer NOT NULL,
  email text,
  phone text,
  recovery_email_sent boolean DEFAULT false,
  recovered boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Product Recommendations
CREATE TABLE IF NOT EXISTS product_recommendations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  recommended_product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  recommendation_type text NOT NULL, -- 'frequently_bought_together', 'similar', 'complementary'
  score numeric(3,2) DEFAULT 1.0, -- recommendation strength
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(product_id, recommended_product_id, recommendation_type)
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_product_collections_active ON product_collections(is_active);
CREATE INDEX IF NOT EXISTS idx_product_collections_featured ON product_collections(is_featured);
CREATE INDEX IF NOT EXISTS idx_collection_products_collection ON collection_products(collection_id);
CREATE INDEX IF NOT EXISTS idx_collection_products_product ON collection_products(product_id);
CREATE INDEX IF NOT EXISTS idx_shipping_zones_active ON shipping_zones(is_active);
CREATE INDEX IF NOT EXISTS idx_tax_rates_active ON tax_rates(is_active);
CREATE INDEX IF NOT EXISTS idx_abandoned_carts_user ON abandoned_carts(user_id);
CREATE INDEX IF NOT EXISTS idx_abandoned_carts_session ON abandoned_carts(session_id);
CREATE INDEX IF NOT EXISTS idx_abandoned_carts_created ON abandoned_carts(created_at);
CREATE INDEX IF NOT EXISTS idx_product_recommendations_product ON product_recommendations(product_id);
CREATE INDEX IF NOT EXISTS idx_product_recommendations_type ON product_recommendations(recommendation_type);

-- Enable RLS
ALTER TABLE product_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE collection_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipping_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE tax_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE abandoned_carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_recommendations ENABLE ROW LEVEL SECURITY;

-- RLS Policies for product_collections
CREATE POLICY "Anyone can read active collections"
  ON product_collections FOR SELECT
  TO anon, authenticated
  USING (is_active = true);

CREATE POLICY "Admins can manage collections"
  ON product_collections FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

-- RLS Policies for collection_products
CREATE POLICY "Anyone can read collection products"
  ON collection_products FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Admins can manage collection products"
  ON collection_products FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

-- RLS Policies for shipping_zones
CREATE POLICY "Anyone can read active shipping zones"
  ON shipping_zones FOR SELECT
  TO anon, authenticated
  USING (is_active = true);

CREATE POLICY "Admins can manage shipping zones"
  ON shipping_zones FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

-- RLS Policies for tax_rates
CREATE POLICY "Anyone can read active tax rates"
  ON tax_rates FOR SELECT
  TO anon, authenticated
  USING (is_active = true);

CREATE POLICY "Admins can manage tax rates"
  ON tax_rates FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

-- RLS Policies for abandoned_carts
CREATE POLICY "Users can read their own abandoned carts"
  ON abandoned_carts FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "System can create abandoned carts"
  ON abandoned_carts FOR INSERT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update their own abandoned carts"
  ON abandoned_carts FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Admins can read all abandoned carts"
  ON abandoned_carts FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

-- RLS Policies for product_recommendations
CREATE POLICY "Anyone can read product recommendations"
  ON product_recommendations FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Admins can manage product recommendations"
  ON product_recommendations FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

-- Add triggers for updated_at
CREATE TRIGGER update_product_collections_updated_at
    BEFORE UPDATE ON product_collections
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_abandoned_carts_updated_at
    BEFORE UPDATE ON abandoned_carts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();