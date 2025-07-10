import { useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

export const useProductViews = () => {
  const { user } = useAuth();

  const trackProductView = async (productId: string) => {
    try {
      // Get user agent and IP (IP will be handled by server in production)
      const userAgent = navigator.userAgent;
      
      await supabase
        .from('product_views')
        .insert({
          product_id: productId,
          user_id: user?.id || null,
          user_agent: userAgent,
          ip_address: null // This would be set by the server in production
        });
    } catch (error) {
      // Silently fail - view tracking shouldn't break the user experience
      console.error('Error tracking product view:', error);
    }
  };

  const getProductViewCount = async (productId: string): Promise<number> => {
    try {
      const { count, error } = await supabase
        .from('product_views')
        .select('*', { count: 'exact', head: true })
        .eq('product_id', productId);

      if (error) throw error;
      return count || 0;
    } catch (error) {
      console.error('Error getting product view count:', error);
      return 0;
    }
  };

  const getUserViewHistory = async (): Promise<any[]> => {
    if (!user) return [];

    try {
      const { data, error } = await supabase
        .from('product_views')
        .select(`
          id,
          created_at,
          products (
            id,
            name,
            price,
            image_url,
            profiles!products_seller_id_fkey (name)
          )
        `)
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
        .limit(20);

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Error getting user view history:', error);
      return [];
    }
  };

  return {
    trackProductView,
    getProductViewCount,
    getUserViewHistory
  };
};