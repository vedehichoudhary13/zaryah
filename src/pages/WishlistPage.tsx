import React from 'react';
import { motion } from 'framer-motion';
import { Heart, ShoppingBag, Trash2, ArrowRight } from 'lucide-react';
import { useWishlist } from '../hooks/useWishlist';
import { useCart } from '../contexts/CartContext';
import { Link } from 'react-router-dom';
import toast from 'react-hot-toast';

export const WishlistPage: React.FC = () => {
  const { wishlistItems, isLoading, removeFromWishlist } = useWishlist();
  const { addToCart } = useCart();

  const handleAddToCart = (item: any) => {
    addToCart({
      id: item.product.id,
      sellerId: '', // This would need to be included in the wishlist data
      sellerName: item.product.seller_name,
      name: item.product.name,
      price: item.product.price,
      image: item.product.image_url,
      description: '',
      city: '',
      instantDeliveryEligible: false,
      status: 'approved',
      category: '',
      tags: [],
      createdAt: ''
    });
    toast.success('Added to cart!');
  };

  const handleRemove = (productId: string) => {
    removeFromWishlist(productId);
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gradient-elegant flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blush-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-elegant pt-8">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center mb-12"
        >
          <div className="bg-blush-600 w-20 h-20 rounded-3xl flex items-center justify-center mx-auto mb-6">
            <Heart className="w-10 h-10 text-white fill-current" />
          </div>
          <h1 className="text-4xl md:text-5xl font-bold text-charcoal-800 mb-4">
            Your{' '}
            <span className="text-blush-600">
              Wishlist
            </span>
          </h1>
          <p className="text-lg md:text-xl text-charcoal-600 max-w-2xl mx-auto">
            Keep track of the handmade treasures that caught your eye
          </p>
        </motion.div>

        {wishlistItems.length === 0 ? (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="text-center py-16"
          >
            <div className="bg-blush-100 w-32 h-32 rounded-full flex items-center justify-center mx-auto mb-8">
              <Heart className="w-16 h-16 text-blush-600" />
            </div>
            <h3 className="text-2xl font-bold text-charcoal-800 mb-4">Your wishlist is empty</h3>
            <p className="text-charcoal-600 mb-8 max-w-md mx-auto">
              Start exploring our collection and save the items you love for later.
            </p>
            <Link
              to="/shop"
              className="inline-flex items-center space-x-2 bg-blush-600 hover:bg-blush-700 text-white px-8 py-3 rounded-xl font-semibold transition-all shadow-lg"
            >
              <span>Start Shopping</span>
              <ArrowRight className="w-5 h-5" />
            </Link>
          </motion.div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {wishlistItems.map((item, index) => (
              <motion.div
                key={item.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: index * 0.1 }}
                className="bg-cream-50 rounded-2xl shadow-lg border border-cream-200 overflow-hidden"
              >
                <div className="relative">
                  <img
                    src={item.product.image_url}
                    alt={item.product.name}
                    className="w-full h-48 object-cover"
                  />
                  <button
                    onClick={() => handleRemove(item.product_id)}
                    className="absolute top-4 right-4 bg-red-500 hover:bg-red-600 text-white p-2 rounded-full transition-colors shadow-lg"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
                
                <div className="p-6">
                  <h3 className="font-bold text-charcoal-800 mb-2 text-lg">
                    {item.product.name}
                  </h3>
                  <p className="text-charcoal-600 text-sm mb-2">
                    by {item.product.seller_name}
                  </p>
                  <p className="text-2xl font-bold text-blush-600 mb-4">
                    ₹{item.product.price.toLocaleString()}
                  </p>
                  
                  <div className="flex space-x-3">
                    <button
                      onClick={() => handleAddToCart(item)}
                      className="flex-1 bg-blush-600 hover:bg-blush-700 text-white py-3 px-4 rounded-xl font-semibold transition-all flex items-center justify-center space-x-2 shadow-lg"
                    >
                      <ShoppingBag className="w-4 h-4" />
                      <span>Add to Cart</span>
                    </button>
                    <Link
                      to={`/product/${item.product_id}`}
                      className="bg-cream-100 hover:bg-cream-200 text-charcoal-700 py-3 px-4 rounded-xl font-semibold transition-all"
                    >
                      View
                    </Link>
                  </div>
                  
                  <p className="text-xs text-charcoal-500 mt-3">
                    Added {new Date(item.created_at).toLocaleDateString()}
                  </p>
                </div>
              </motion.div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};