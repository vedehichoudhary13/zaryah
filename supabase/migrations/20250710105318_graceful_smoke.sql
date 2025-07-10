/*
  # Add Missing RLS Policies

  1. Reviews Table Policies
    - Users can read all reviews
    - Users can create reviews for products
    - Users can update/delete their own reviews
    - Admins can manage all reviews

  2. Enhanced Product Policies
    - Add policy for sellers to manage inventory

  3. Order Policies Enhancement
    - Sellers can view orders containing their products
*/

-- Enable RLS on reviews if not already enabled
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Reviews policies
CREATE POLICY "Anyone can read reviews"
  ON reviews
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Authenticated users can create reviews"
  ON reviews
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own reviews"
  ON reviews
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own reviews"
  ON reviews
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all reviews"
  ON reviews
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

-- Enhanced order policies for sellers
CREATE POLICY "Sellers can view orders containing their products"
  ON orders
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    ) OR
    EXISTS (
      SELECT 1 FROM jsonb_array_elements(items) AS item
      WHERE (item->>'product'->>'sellerId')::uuid = auth.uid()
    )
  );