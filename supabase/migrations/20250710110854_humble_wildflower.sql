/*
  # Add Product Variants Support

  1. New Tables
    - `product_variants` - For size, color, material variations
    - `variant_options` - Predefined options like sizes, colors
    - `product_images` - Multiple images per product/variant
    
  2. Features
    - Support for product variations (size, color, material)
    - Multiple images per product
    - Variant-specific pricing and inventory
    
  3. Security
    - Enable RLS on all new tables
    - Add appropriate policies
*/

-- Create variant options table (predefined options like sizes, colors)
CREATE TABLE IF NOT EXISTS variant_options (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL, -- 'Size', 'Color', 'Material'
  values jsonb NOT NULL, -- ['S', 'M', 'L'] or ['Red', 'Blue', 'Green']
  created_at timestamptz DEFAULT now()
);

-- Create product variants table
CREATE TABLE IF NOT EXISTS product_variants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  variant_name text NOT NULL, -- 'Red - Large', 'Blue - Small'
  variant_options jsonb NOT NULL, -- {'color': 'Red', 'size': 'Large'}
  price_adjustment integer DEFAULT 0, -- Price difference from base product
  stock_quantity integer DEFAULT 0,
  sku text UNIQUE,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create product images table for multiple images
CREATE TABLE IF NOT EXISTS product_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  variant_id uuid REFERENCES product_variants(id) ON DELETE CASCADE,
  image_url text NOT NULL,
  alt_text text,
  sort_order integer DEFAULT 0,
  is_primary boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_product_variants_product_id ON product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_product_variants_active ON product_variants(is_active);
CREATE INDEX IF NOT EXISTS idx_product_images_product_id ON product_images(product_id);
CREATE INDEX IF NOT EXISTS idx_product_images_variant_id ON product_images(variant_id);
CREATE INDEX IF NOT EXISTS idx_product_images_primary ON product_images(is_primary);

-- Enable RLS
ALTER TABLE variant_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;

-- RLS Policies for variant_options
CREATE POLICY "Anyone can read variant options"
  ON variant_options FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Only admins can manage variant options"
  ON variant_options FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

-- RLS Policies for product_variants
CREATE POLICY "Anyone can read active product variants"
  ON product_variants FOR SELECT
  TO anon, authenticated
  USING (is_active = true);

CREATE POLICY "Sellers can manage their product variants"
  ON product_variants FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM products 
    WHERE products.id = product_variants.product_id 
    AND products.seller_id = auth.uid()
  ));

CREATE POLICY "Admins can manage all product variants"
  ON product_variants FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

-- RLS Policies for product_images
CREATE POLICY "Anyone can read product images"
  ON product_images FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Sellers can manage their product images"
  ON product_images FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM products 
    WHERE products.id = product_images.product_id 
    AND products.seller_id = auth.uid()
  ));

CREATE POLICY "Admins can manage all product images"
  ON product_images FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

-- Add triggers for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_product_variants_updated_at
    BEFORE UPDATE ON product_variants
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();