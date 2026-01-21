# Swadisht - Database Setup Guide

## Overview
Swadisht is the food delivery service for Accesco Living. If you're seeing "Error loading restaurants" or "Error loading food items", this guide will help you set it up.

## Problem
The Swadisht app cannot load restaurant and food data because the Supabase database tables are not properly configured.

## Prerequisites
- Supabase account and project created
- Supabase URL and Anon Key (see `swadisht.js` lines 1-2)

## Solution

### Step 1: Create the Restaurants Table

Go to your Supabase Project → SQL Editor and run this SQL:

```sql
-- Create Restaurants Table
CREATE TABLE IF NOT EXISTS public.restraunts (
    restraunt_id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name text NOT NULL,
    location text NOT NULL,
    phone_number text,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now()
);

-- Add sample data
INSERT INTO public.restraunts (name, location, phone_number, is_active) VALUES
('Spice Palace', 'Downtown Mumbai', '+91-9876543210', true),
('Tandoor Kitchen', 'Bandra West', '+91-9876543211', true),
('Curry Corner', 'Andheri East', '+91-9876543212', true);

-- Create index for faster queries
CREATE INDEX idx_restraunts_active ON public.restraunts(is_active);
```

### Step 2: Create the Food Items Table

```sql
-- Create Food Items Table
CREATE TABLE IF NOT EXISTS public.food_items (
    food_id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    restraunt_id bigint NOT NULL REFERENCES public.restraunts(restraunt_id),
    name text NOT NULL,
    description text,
    price numeric NOT NULL,
    image_url text,
    is_available boolean DEFAULT true,
    category text,
    created_at timestamptz DEFAULT now(),
    FOREIGN KEY (restraunt_id) REFERENCES public.restraunts(restraunt_id)
);

-- Add sample food items
INSERT INTO public.food_items (restraunt_id, name, description, price, category, is_available) VALUES
(1, 'Butter Chicken', 'Creamy butter chicken with basmati rice', 350.00, 'Chicken', true),
(1, 'Paneer Tikka', 'Grilled paneer with vegetables', 280.00, 'Vegetarian', true),
(1, 'Biryani', 'Fragrant basmati rice with spices', 300.00, 'Rice', true),
(2, 'Tandoori Chicken', 'Traditional tandoori preparation', 400.00, 'Chicken', true),
(2, 'Dal Makhani', 'Creamy lentils with cream and butter', 250.00, 'Vegetarian', true),
(3, 'Aloo Gobi', 'Potato and cauliflower curry', 200.00, 'Vegetarian', true),
(3, 'Lamb Rogan Josh', 'Tender lamb in tomato-based gravy', 420.00, 'Meat', true);

-- Create indexes
CREATE INDEX idx_food_items_restraunt_id ON public.food_items(restraunt_id);
CREATE INDEX idx_food_items_available ON public.food_items(is_available);
CREATE INDEX idx_food_items_category ON public.food_items(category);
```

### Step 3: Create Orders Table (Optional but Recommended)

```sql
-- Create Orders Table
CREATE TABLE IF NOT EXISTS public.orders (
    order_id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id text NOT NULL,
    restraunt_id bigint NOT NULL REFERENCES public.restraunts(restraunt_id),
    order_status text DEFAULT 'pending',
    total_amount numeric NOT NULL,
    order_time timestamptz DEFAULT now(),
    created_at timestamptz DEFAULT now(),
    FOREIGN KEY (restraunt_id) REFERENCES public.restraunts(restraunt_id)
);

-- Create Order Items Table
CREATE TABLE IF NOT EXISTS public.order_items (
    order_item_id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    order_id bigint NOT NULL REFERENCES public.orders(order_id),
    food_id bigint NOT NULL REFERENCES public.food_items(food_id),
    quantity integer NOT NULL,
    price numeric NOT NULL,
    food_image_url text,
    created_at timestamptz DEFAULT now(),
    FOREIGN KEY (order_id) REFERENCES public.orders(order_id),
    FOREIGN KEY (food_id) REFERENCES public.food_items(food_id)
);

-- Create indexes
CREATE INDEX idx_orders_user_id ON public.orders(user_id);
CREATE INDEX idx_orders_restraunt_id ON public.orders(restraunt_id);
CREATE INDEX idx_orders_status ON public.orders(order_status);
CREATE INDEX idx_order_items_order_id ON public.order_items(order_id);
```

### Step 4: Disable RLS (For Development)

**Important**: For production, set up proper Row Level Security (RLS) policies instead.

For development/testing:
1. Go to Supabase Dashboard → Authentication → Policies
2. For each table (`restraunts`, `food_items`, `orders`, `order_items`):
   - Click on the table
   - Find the "RLS" toggle
   - Toggle it OFF (for development only)

### Step 5: Verify the Connection

1. Open `services/swadisht/index.html` in your browser
2. You should see the loading spinner briefly, then restaurants and food items should load
3. Check browser console (F12) for any errors
4. Try searching for dishes and adding items to cart

## Troubleshooting

### Issue: Still showing "Error loading restaurants"

**Solution:**
- Check that Supabase URL and Anon Key in `swadisht.js` (lines 1-2) are correct
- Verify the table names: should be `restraunts` (with one 'a') and `food_items`
- Check that RLS is disabled for development
- Open browser console (F12) and look for error messages
- Check Supabase logs for any auth errors

### Issue: Database connection timeout

**Solution:**
- Verify internet connection
- Check that Supabase project is active
- Try refreshing the page
- Clear browser cache (Ctrl+Shift+Delete or Cmd+Shift+Delete)

### Issue: CORS errors

**Solution:**
- The Supabase CDN link in `swadisht.js` should handle CORS automatically
- If using a custom setup, ensure CORS is enabled in Supabase settings

## File Changes Made

The following fixes have been applied to make Swadisht work:

1. **Script path fixed**: `swadisht.js` is now correctly referenced from `/services/swadisht/index.html`
2. **Image paths fixed**: Logo and other images now use correct relative paths
3. **Error handling improved**: Better error messages when data fails to load
4. **Fallback UI added**: Shows helpful message if no data is available

## Testing Checklist

- [ ] Restaurants load on page load
- [ ] Food items display from all restaurants
- [ ] Search functionality works
- [ ] Restaurant filter works
- [ ] Add to cart functionality works
- [ ] Cart updates correctly
- [ ] Order placement works (with valid User ID)

## Next Steps

1. Run the SQL commands above in your Supabase SQL Editor
2. Refresh the Swadisht page in your browser
3. Verify that restaurants and food items load
4. Test adding items to cart and placing an order
5. Check the orders table to see if the order was saved

## Support

If you encounter any issues:
1. Check browser console for errors (F12)
2. Review Supabase logs
3. Verify table names and column names match exactly
4. Ensure RLS is disabled (for development)
5. Clear browser cache and try again
