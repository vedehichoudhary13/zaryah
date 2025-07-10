import React from 'react';
import { motion } from 'framer-motion';
import { Heart } from 'lucide-react';
import { useWishlist } from '../hooks/useWishlist';

interface WishlistButtonProps {
  productId: string;
  className?: string;
  size?: 'sm' | 'md' | 'lg';
}

export const WishlistButton: React.FC<WishlistButtonProps> = ({ 
  productId, 
  className = '',
  size = 'md'
}) => {
  const { isInWishlist, toggleWishlist } = useWishlist();
  const isLiked = isInWishlist(productId);

  const sizeClasses = {
    sm: 'w-8 h-8 p-1.5',
    md: 'w-10 h-10 p-2',
    lg: 'w-12 h-12 p-3'
  };

  const iconSizes = {
    sm: 'w-4 h-4',
    md: 'w-5 h-5',
    lg: 'w-6 h-6'
  };

  const handleClick = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    toggleWishlist(productId);
  };

  return (
    <motion.button
      whileHover={{ scale: 1.1 }}
      whileTap={{ scale: 0.9 }}
      onClick={handleClick}
      className={`${sizeClasses[size]} rounded-full transition-all shadow-soft border border-blush-200 ${
        isLiked 
          ? 'bg-blush-600 hover:bg-blush-700' 
          : 'bg-blush-100 hover:bg-blush-200'
      } ${className}`}
    >
      <Heart 
        className={`${iconSizes[size]} transition-colors ${
          isLiked ? 'text-white fill-current' : 'text-blush-600'
        }`} 
      />
    </motion.button>
  );
};