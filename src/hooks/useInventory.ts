import { useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import toast from 'react-hot-toast';

interface InventoryMovement {
  id: string;
  product_id: string;
  movement_type: 'sale' | 'restock' | 'return' | 'adjustment';
  quantity: number;
  reason?: string;
  order_id?: string;
  created_at: string;
}

export const useInventory = () => {
  const { user } = useAuth();
  const [isLoading, setIsLoading] = useState(false);

  const addInventoryMovement = async (
    productId: string,
    movementType: 'sale' | 'restock' | 'return' | 'adjustment',
    quantity: number,
    reason?: string,
    orderId?: string
  ): Promise<boolean> => {
    if (!user) return false;

    setIsLoading(true);
    try {
      const { error } = await supabase
        .from('inventory_movements')
        .insert({
          product_id: productId,
          movement_type: movementType,
          quantity: Math.abs(quantity), // Ensure positive quantity
          reason,
          order_id: orderId,
          created_by: user.id
        });

      if (error) throw error;

      toast.success('Inventory updated successfully');
      return true;
    } catch (error) {
      console.error('Error adding inventory movement:', error);
      toast.error('Failed to update inventory');
      return false;
    } finally {
      setIsLoading(false);
    }
  };

  const getInventoryMovements = async (productId: string): Promise<InventoryMovement[]> => {
    try {
      const { data, error } = await supabase
        .from('inventory_movements')
        .select('*')
        .eq('product_id', productId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Error fetching inventory movements:', error);
      return [];
    }
  };

  const updateProductStock = async (productId: string, newStock: number): Promise<boolean> => {
    if (!user) return false;

    try {
      // Get current stock
      const { data: product, error: fetchError } = await supabase
        .from('products')
        .select('stock_quantity')
        .eq('id', productId)
        .single();

      if (fetchError) throw fetchError;

      const currentStock = product.stock_quantity || 0;
      const difference = newStock - currentStock;

      if (difference !== 0) {
        // Create inventory movement
        await addInventoryMovement(
          productId,
          'adjustment',
          Math.abs(difference),
          `Stock adjustment: ${currentStock} → ${newStock}`,
        );
      }

      return true;
    } catch (error) {
      console.error('Error updating product stock:', error);
      return false;
    }
  };

  const checkLowStock = async (sellerId: string): Promise<any[]> => {
    try {
      const { data, error } = await supabase
        .from('products')
        .select('id, name, stock_quantity, low_stock_threshold')
        .eq('seller_id', sellerId)
        .eq('track_inventory', true)
        .filter('stock_quantity', 'lte', 'low_stock_threshold');

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Error checking low stock:', error);
      return [];
    }
  };

  return {
    isLoading,
    addInventoryMovement,
    getInventoryMovements,
    updateProductStock,
    checkLowStock
  };
};