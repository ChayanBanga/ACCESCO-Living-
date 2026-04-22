import '../models/product.dart';

class ProductsData {
  static final List<Product> groceryProducts = [
    // Rice & Grains (5 items)
    Product(id: 1, name: "Organic Basmati Rice", price: 180, description: "Premium quality basmati rice, 1kg pack", category: "grocery", emoji: "🌾", imageUrl: "https://images.unsplash.com/photo-1586201375761-83865001e31c?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8bG9uZyUyMGdyYWluJTIwcmljZXxlbnwwfHwwfHx8MA%3D%3D"),    
    Product(id: 2, name: "Brown Rice", price: 120, description: "Healthy brown rice, 1kg", category: "grocery", emoji: "🌾", imageUrl: "https://plus.unsplash.com/premium_photo-1671130295823-78f170465794?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MXx8YnJvd24lMjByaWNlfGVufDB8fDB8fHww"),
    Product(id: 3, name: "Quinoa", price: 280, description: "Organic quinoa, 500g", category: "grocery", emoji: "🌾", imageUrl: "https://images.unsplash.com/photo-1586201375799-47cd24c3f595?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8cXVpbm9hfGVufDB8fDB8fHww"),
    Product(id: 4, name: "Oats", price: 85, description: "Rolled oats, 500g", category: "grocery", emoji: "🌾", imageUrl: "https://images.unsplash.com/photo-1614373532018-92a75430a0da?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8b2F0c3xlbnwwfHwwfHx8MA%3D%3D"),
    Product(id: 5, name: "Wheat Flour", price: 45, description: "Stone ground atta, 1kg", category: "grocery", emoji: "🌾", imageUrl: "https://images.unsplash.com/photo-1627735483792-233bf632619b?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8d2hlYXQlMjBmbG91cnxlbnwwfHwwfHx8MA%3D%3D"),

    // Dairy (8 items)
    Product(id: 6, name: "Fresh Milk", price: 60, description: "Farm fresh full cream milk, 1L", category: "grocery", emoji: "🥛", imageUrl: "https://plus.unsplash.com/premium_photo-1694481100261-ab16523c4093?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8OXx8ZnJlYXNoJTIwbWlsa3xlbnwwfHwwfHx8MA%3D%3D"),
    Product(id: 7, name: "Curd/Yogurt", price: 40, description: "Fresh curd, 500g", category: "grocery", emoji: "🥛", imageUrl: "https://www.themealdb.com/images/ingredients/Yogurt.png"),
    Product(id: 8, name: "Fresh Paneer", price: 110, description: "Homemade cottage cheese, 250g", category: "grocery", emoji: "🧈", imageUrl: "https://www.themealdb.com/images/ingredients/Paneer.png"),
    Product(id: 9, name: "Butter", price: 95, description: "Fresh white butter, 200g", category: "grocery", emoji: "🧈", imageUrl: "https://www.themealdb.com/images/ingredients/Butter.png"),
    Product(id: 10, name: "Cheese Slices", price: 120, description: "Processed cheese, 200g", category: "grocery", emoji: "🧀", imageUrl: "https://www.themealdb.com/images/ingredients/Cheddar%20Cheese.png"),
    Product(id: 11, name: "Ghee", price: 450, description: "Pure cow ghee, 500ml", category: "grocery", emoji: "🧈", imageUrl: "https://images.unsplash.com/photo-1707425197195-240b7ad69047?q=80&w=789&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"),
    Product(id: 12, name: "Cream", price: 70, description: "Fresh cream, 250ml", category: "grocery", emoji: "🥛", imageUrl: "https://www.themealdb.com/images/ingredients/Double%20Cream.png"),
    Product(id: 13, name: "Buttermilk", price: 35, description: "Fresh buttermilk, 500ml", category: "grocery", emoji: "🥛", imageUrl: "https://www.themealdb.com/images/ingredients/Milk.png"),

    // Vegetables (10 items)
    Product(id: 14, name: "Tomatoes", price: 40, description: "Fresh red tomatoes, 500g", category: "grocery", emoji: "🍅", imageUrl: "https://www.themealdb.com/images/ingredients/Tomatoes.png"),
    Product(id: 15, name: "Onions", price: 35, description: "Fresh onions, 1kg", category: "grocery", emoji: "🧅", imageUrl: "https://www.themealdb.com/images/ingredients/Onions.png"),
    Product(id: 16, name: "Potatoes", price: 30, description: "Fresh potatoes, 1kg", category: "grocery", emoji: "🥔", imageUrl: "https://www.themealdb.com/images/ingredients/Potatoes.png"),
    Product(id: 17, name: "Carrots", price: 45, description: "Fresh carrots, 500g", category: "grocery", emoji: "🥕", imageUrl: "https://www.themealdb.com/images/ingredients/Carrots.png"),
    Product(id: 18, name: "Spinach", price: 25, description: "Fresh spinach, 250g", category: "grocery", emoji: "🥬", imageUrl: "https://www.themealdb.com/images/ingredients/Spinach.png"),
    Product(id: 19, name: "Broccoli", price: 60, description: "Fresh broccoli, 500g", category: "grocery", emoji: "🥦", imageUrl: "https://www.themealdb.com/images/ingredients/Broccoli.png"),
    Product(id: 20, name: "Cauliflower", price: 40, description: "Fresh cauliflower, 1 piece", category: "grocery", emoji: "🥦", imageUrl: "https://www.themealdb.com/images/ingredients/Cauliflower.png"),
    Product(id: 21, name: "Capsicum", price: 50, description: "Bell peppers mix, 500g", category: "grocery", emoji: "🫑", imageUrl: "https://www.themealdb.com/images/ingredients/Red%20Pepper.png"),
    Product(id: 22, name: "Green Beans", price: 55, description: "Fresh beans, 500g", category: "grocery", emoji: "🥒", imageUrl: "https://www.themealdb.com/images/ingredients/Green%20Beans.png"),
    Product(id: 23, name: "Mixed Vegetables", price: 80, description: "Seasonal vegetables mix, 1kg", category: "grocery", emoji: "🥕", imageUrl: "https://www.themealdb.com/images/ingredients/Mixed%20Vegetables.png"),

    // Fruits (8 items)
    Product(id: 24, name: "Apples", price: 120, description: "Fresh apples, 1kg", category: "grocery", emoji: "🍎", imageUrl: "https://www.themealdb.com/images/ingredients/Apple.png"),
    Product(id: 25, name: "Bananas", price: 50, description: "Fresh bananas, 1 dozen", category: "grocery", emoji: "🍌", imageUrl: "https://www.themealdb.com/images/ingredients/Banana.png"),
    Product(id: 26, name: "Oranges", price: 80, description: "Fresh oranges, 1kg", category: "grocery", emoji: "🍊", imageUrl: "https://www.themealdb.com/images/ingredients/Orange%20Zest.png"),
    Product(id: 27, name: "Mangoes", price: 150, description: "Alphonso mangoes, 1kg", category: "grocery", emoji: "🥭", imageUrl: "https://www.themealdb.com/images/ingredients/Mango.png"),
    Product(id: 28, name: "Grapes", price: 90, description: "Fresh grapes, 500g", category: "grocery", emoji: "🍇", imageUrl: "https://www.themealdb.com/images/ingredients/Grapes.png"),
    Product(id: 29, name: "Watermelon", price: 60, description: "Fresh watermelon, 2kg", category: "grocery", emoji: "🍉", imageUrl: "https://www.themealdb.com/images/ingredients/Watermelon.png"),
    Product(id: 30, name: "Pomegranate", price: 110, description: "Fresh pomegranate, 500g", category: "grocery", emoji: "🍎", imageUrl: "https://plus.unsplash.com/premium_photo-1668076515507-c5bc223c99a4?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MXx8cG9tZWdyYW5hdGV8ZW58MHx8MHx8fDA%3D"),
    Product(id: 31, name: "Papaya", price: 40, description: "Fresh papaya, 1kg", category: "grocery", emoji: "🍈", imageUrl: "https://www.themealdb.com/images/ingredients/Papaya.png"),

    // Pulses & Legumes (6 items)
    Product(id: 32, name: "Toor Dal", price: 140, description: "Premium toor dal, 1kg", category: "grocery", emoji: "🫘", imageUrl: "https://www.themealdb.com/images/ingredients/Lentils.png"),
    Product(id: 33, name: "Moong Dal", price: 130, description: "Yellow moong dal, 1kg", category: "grocery", emoji: "🫘", imageUrl: "https://www.themealdb.com/images/ingredients/Lentils.png"),
    Product(id: 34, name: "Chana Dal", price: 110, description: "Chana dal, 1kg", category: "grocery", emoji: "🫘", imageUrl: "https://www.themealdb.com/images/ingredients/Chickpeas.png"),
    Product(id: 35, name: "Masoor Dal", price: 100, description: "Red lentils, 1kg", category: "grocery", emoji: "🫘", imageUrl: "https://www.themealdb.com/images/ingredients/Lentils.png"),
    Product(id: 36, name: "Chickpeas", price: 90, description: "Kabuli chana, 500g", category: "grocery", emoji: "🫘", imageUrl: "https://www.themealdb.com/images/ingredients/Chickpeas.png"),
    Product(id: 37, name: "Kidney Beans", price: 120, description: "Rajma, 500g", category: "grocery", emoji: "🫘", imageUrl: "https://www.themealdb.com/images/ingredients/Kidney%20Beans.png"),

    // Eggs & Meat (4 items)
    Product(id: 38, name: "Eggs", price: 90, description: "Farm fresh eggs, 6 pieces", category: "grocery", emoji: "🥚", imageUrl: "https://www.themealdb.com/images/ingredients/Eggs.png"),
    Product(id: 39, name: "Brown Eggs", price: 110, description: "Organic brown eggs, 6 pieces", category: "grocery", emoji: "🥚", imageUrl: "https://www.themealdb.com/images/ingredients/Eggs.png"),
    Product(id: 40, name: "Chicken Breast", price: 240, description: "Fresh chicken breast, 500g", category: "grocery", emoji: "🍗", imageUrl: "https://www.themealdb.com/images/ingredients/Chicken%20Breast.png"),
    Product(id: 41, name: "Fish Fillet", price: 320, description: "Fresh fish fillet, 500g", category: "grocery", emoji: "🐟", imageUrl: "https://www.themealdb.com/images/ingredients/Salmon%20Fillet.png"),

    // Oils & Spices (10 items)
    Product(id: 42, name: "Olive Oil", price: 650, description: "Extra virgin olive oil, 500ml", category: "grocery", emoji: "🫒", imageUrl: "https://www.themealdb.com/images/ingredients/Olive%20Oil.png"),
    Product(id: 43, name: "Sunflower Oil", price: 180, description: "Refined oil, 1L", category: "grocery", emoji: "🌻", imageUrl: "https://www.themealdb.com/images/ingredients/Sunflower%20Oil.png"),
    Product(id: 44, name: "Coconut Oil", price: 220, description: "Pure coconut oil, 500ml", category: "grocery", emoji: "🥥", imageUrl: "https://www.themealdb.com/images/ingredients/Coconut%20Oil.png"),
    Product(id: 45, name: "Turmeric Powder", price: 60, description: "Pure turmeric, 100g", category: "grocery", emoji: "🌶️", imageUrl: "https://www.themealdb.com/images/ingredients/Turmeric.png"),
    Product(id: 46, name: "Red Chili Powder", price: 50, description: "Spicy chili powder, 100g", category: "grocery", emoji: "🌶️", imageUrl: "https://www.themealdb.com/images/ingredients/Chilli%20Powder.png"),
    Product(id: 47, name: "Garam Masala", price: 80, description: "Premium blend, 100g", category: "grocery", emoji: "🌶️", imageUrl: "https://www.themealdb.com/images/ingredients/Garam%20Masala.png"),
    Product(id: 48, name: "Cumin Seeds", price: 45, description: "Whole jeera, 100g", category: "grocery", emoji: "🌾", imageUrl: "https://www.themealdb.com/images/ingredients/Cumin.png"),
    Product(id: 49, name: "Coriander Powder", price: 40, description: "Ground coriander, 100g", category: "grocery", emoji: "🌿", imageUrl: "https://www.themealdb.com/images/ingredients/Coriander.png"),
    Product(id: 50, name: "Salt", price: 20, description: "Iodized salt, 1kg", category: "grocery", emoji: "🧂", imageUrl: "https://www.themealdb.com/images/ingredients/Salt.png"),
    Product(id: 51, name: "Sugar", price: 45, description: "White sugar, 1kg", category: "grocery", emoji: "🍬", imageUrl: "https://www.themealdb.com/images/ingredients/Sugar.png"),

    // Beverages & Others (9 items)
    Product(id: 52, name: "Green Tea", price: 280, description: "Premium green tea, 100g", category: "grocery", emoji: "🍵", imageUrl: "https://www.themealdb.com/images/ingredients/Green%20Tea.png"),
    Product(id: 53, name: "Coffee Powder", price: 350, description: "Filter coffee, 250g", category: "grocery", emoji: "☕", imageUrl: "https://www.themealdb.com/images/ingredients/Coffee%20Granules.png"),
    Product(id: 54, name: "Honey", price: 320, description: "Pure forest honey, 500g", category: "grocery", emoji: "🍯", imageUrl: "https://www.themealdb.com/images/ingredients/Honey.png"),
    Product(id: 55, name: "Jam", price: 180, description: "Mixed fruit jam, 500g", category: "grocery", emoji: "🍓", imageUrl: "https://www.themealdb.com/images/ingredients/Strawberry%20Jam.png"),
    Product(id: 56, name: "Peanut Butter", price: 250, description: "Creamy peanut butter, 500g", category: "grocery", emoji: "🥜", imageUrl: "https://www.themealdb.com/images/ingredients/Peanut%20Butter.png"),
    Product(id: 57, name: "Almonds", price: 420, description: "California almonds, 250g", category: "grocery", emoji: "🌰", imageUrl: "https://www.themealdb.com/images/ingredients/Almonds.png"),
    Product(id: 58, name: "Cashews", price: 580, description: "Premium cashews, 250g", category: "grocery", emoji: "🌰", imageUrl: "https://www.themealdb.com/images/ingredients/Cashew%20Nuts.png"),
    Product(id: 59, name: "Bread", price: 40, description: "Whole wheat bread, 400g", category: "grocery", emoji: "🍞", imageUrl: "https://www.themealdb.com/images/ingredients/Bread.png"),
    Product(id: 60, name: "Pasta", price: 120, description: "Italian pasta, 500g", category: "grocery", emoji: "🍝", imageUrl: "https://www.themealdb.com/images/ingredients/Penne.png"),
  ];

  static final List<Product> foodProducts = [
    // Pizza (5 items)
    Product(id: 101, name: "Margherita Pizza", price: 280, description: "Classic cheese pizza with basil", category: "food", emoji: "🍕", imageUrl: "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=400&fit=crop"),
    Product(id: 102, name: "Pepperoni Pizza", price: 350, description: "Spicy pepperoni & cheese", category: "food", emoji: "🍕", imageUrl: "https://images.unsplash.com/photo-1628840042765-356cda07504e?w=400&fit=crop"),
    Product(id: 103, name: "Veggie Supreme Pizza", price: 320, description: "Loaded with vegetables", category: "food", emoji: "🍕", imageUrl: "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&fit=crop"),
    Product(id: 104, name: "BBQ Chicken Pizza", price: 380, description: "BBQ sauce & grilled chicken", category: "food", emoji: "🍕", imageUrl: "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&fit=crop"),
    Product(id: 105, name: "Paneer Tikka Pizza", price: 340, description: "Indian style paneer pizza", category: "food", emoji: "🍕", imageUrl: "https://images.unsplash.com/photo-1593560708920-61dd98c46a4e?w=400&fit=crop"),
    
    // Indian Main Course (10 items)
    Product(id: 106, name: "Chicken Biryani", price: 220, description: "Authentic Hyderabadi biryani", category: "food", emoji: "🍛", imageUrl: "https://images.unsplash.com/photo-1701579231305-d84d8af9a3fd?fm=jpg&q=60&w=3000&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8Y2hpY2tlbiUyMGJpcnlhbml8ZW58MHx8MHx8fDA%3D&fit=crop"),
    Product(id: 107, name: "Veg Biryani", price: 180, description: "Aromatic vegetable biryani", category: "food", emoji: "🍛", imageUrl: "https://images.unsplash.com/photo-1645177628172-a94c1f96e6db?w=400&fit=crop"),
    Product(id: 108, name: "Butter Chicken", price: 280, description: "Creamy tomato curry with chicken", category: "food", emoji: "🍗", imageUrl: "https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=400&fit=crop"),
    Product(id: 109, name: "Paneer Butter Masala", price: 240, description: "Cottage cheese in rich gravy", category: "food", emoji: "🧈", imageUrl: "https://img.freepik.com/premium-photo/delicious-paneer-butter-masala-photography_928503-851.jpg?w=2000&fit=crop"),
    Product(id: 110, name: "Dal Makhani", price: 180, description: "Creamy black lentils", category: "food", emoji: "🍲", imageUrl: "https://myfoodstory.com/wp-content/uploads/2018/08/Dal-Makhani-New-4.jpg?fit=1200,9999&fit=crop"),
    Product(id: 111, name: "Chole Bhature", price: 150, description: "Spicy chickpeas with fried bread", category: "food", emoji: "🫓", imageUrl: "https://media.istockphoto.com/id/1488738112/photo/chole-bhature-punjabi-bhature.webp?b=1&s=170667a&w=0&k=20&c=RBQ03nVweEEVDi3I9eddVC-ry_Tlbxj0TPzuoNQJibM=&fit=crop"),
    Product(id: 112, name: "Palak Paneer", price: 220, description: "Spinach with cottage cheese", category: "food", emoji: "🥬", imageUrl: "https://media.istockphoto.com/id/1146291429/photo/palak-paneer-or-spinach-and-cottage-cheese-curry-on-a-dark-background-traditional-indian-food.webp?b=1&s=170667a&w=0&k=20&c=p2CM7csO98p5NzySIFsLSuwLCYyViiaLZ-mgKUsZx-U=&fit=crop"),
    Product(id: 113, name: "Kadai Chicken", price: 260, description: "Spicy chicken curry", category: "food", emoji: "🍗", imageUrl: "https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400&fit=crop"),
    Product(id: 114, name: "Fish Curry", price: 300, description: "Coastal style fish curry", category: "food", emoji: "🐟", imageUrl: "https://media.istockphoto.com/photos/spicy-fish-curry-popular-indian-seafood-served-with-rice-picture-id1266092627?b=1&k=20&m=1266092627&s=170667a&w=0&h=w6qKR6LhxSzsPdqs8PMYglTGU3S_IE7W00JSwbK9R3Y=&fit=crop"),
    Product(id: 115, name: "Mutton Rogan Josh", price: 350, description: "Aromatic mutton curry", category: "food", emoji: "🍖", imageUrl: "https://tse2.mm.bing.net/th/id/OIP.e5rhS3LwatOwGTOZ85MiawHaHa?rs=1&pid=ImgDetMain&o=7&rm=3&fit=crop"),
    
    // South Indian (8 items)
    Product(id: 116, name: "Masala Dosa", price: 80, description: "Crispy dosa with potato filling", category: "food", emoji: "🥞", imageUrl: "https://images.unsplash.com/photo-1668236543090-82eba5ee5976?fm=jpg&q=60&w=3000&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8bWFzYWxhJTIwZG9zYXxlbnwwfHwwfHx8MA%3D%3D&fit=crop"),
    Product(id: 117, name: "Plain Dosa", price: 60, description: "Crispy rice crepe", category: "food", emoji: "🥞", imageUrl: "https://tse3.mm.bing.net/th/id/OIP.d0l39gif7KkVFntnE-StIgHaHa?rs=1&pid=ImgDetMain&o=7&rm=3&fit=crop"),
    Product(id: 118, name: "Idli Sambar", price: 70, description: "Steamed rice cakes with lentil soup", category: "food", emoji: "🍚", imageUrl: "https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=400&fit=crop"),
    Product(id: 119, name: "Vada Sambar", price: 75, description: "Lentil donuts with sambar", category: "food", emoji: "🍩", imageUrl: "https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=400&fit=crop"),
    Product(id: 120, name: "Uttapam", price: 90, description: "Thick rice pancake with veggies", category: "food", emoji: "🥞", imageUrl: "https://images.unsplash.com/photo-1630383249946-52eed63e1b5b?w=400&fit=crop"),
    Product(id: 121, name: "Pongal", price: 85, description: "Rice and lentil dish", category: "food", emoji: "🍚", imageUrl: "https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&fit=crop"),
    Product(id: 122, name: "Appam", price: 95, description: "Rice pancakes, 3 pieces", category: "food", emoji: "🥞", imageUrl: "https://images.unsplash.com/photo-1630383249896-483b843fffed?w=400&fit=crop"),
    Product(id: 123, name: "Rasam Rice", price: 100, description: "Tangy soup with rice", category: "food", emoji: "🍲", imageUrl: "https://images.unsplash.com/photo-1546833998-877b37c2e5c6?w=400&fit=crop"),
    
    // Burgers & Sandwiches (6 items)
    Product(id: 124, name: "Veg Burger", price: 120, description: "Grilled veggie patty", category: "food", emoji: "🍔", imageUrl: "https://images.unsplash.com/photo-1520072959219-c595dc870360?w=400&fit=crop"),
    Product(id: 125, name: "Chicken Burger", price: 150, description: "Juicy chicken burger", category: "food", emoji: "🍔", imageUrl: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&fit=crop"),
    Product(id: 126, name: "Cheese Burger", price: 140, description: "Double cheese burger", category: "food", emoji: "🍔", imageUrl: "https://images.unsplash.com/photo-1550547660-d9450f859349?w=400&fit=crop"),
    Product(id: 127, name: "Club Sandwich", price: 160, description: "Triple-decker sandwich", category: "food", emoji: "🥪", imageUrl: "https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=400&fit=crop"),
    Product(id: 128, name: "Grilled Sandwich", price: 100, description: "Cheese & veggie grilled", category: "food", emoji: "🥪", imageUrl: "https://images.unsplash.com/photo-1553909489-cd47e0907980?w=400&fit=crop"),
    Product(id: 129, name: "Paneer Sandwich", price: 130, description: "Spicy paneer filling", category: "food", emoji: "🥪", imageUrl: "https://images.unsplash.com/photo-1481070414801-51fd732d7184?w=400&fit=crop"),
    
    // Pasta & Noodles (6 items)
    Product(id: 130, name: "Pasta Alfredo", price: 260, description: "Creamy white sauce pasta", category: "food", emoji: "🍝", imageUrl: "https://images.unsplash.com/photo-1645112411341-6c4fd023714a?w=400&fit=crop"),
    Product(id: 131, name: "Pasta Arrabiata", price: 240, description: "Spicy tomato pasta", category: "food", emoji: "🍝", imageUrl: "https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=400&fit=crop"),
    Product(id: 132, name: "Mac & Cheese", price: 220, description: "Creamy macaroni", category: "food", emoji: "🍝", imageUrl: "https://images.unsplash.com/photo-1612182216893-f3e85f0e3b3b?w=400&fit=crop"),
    Product(id: 133, name: "Hakka Noodles", price: 180, description: "Stir-fried noodles", category: "food", emoji: "🍜", imageUrl: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400&fit=crop"),
    Product(id: 134, name: "Chowmein", price: 160, description: "Chinese style noodles", category: "food", emoji: "🍜", imageUrl: "https://images.unsplash.com/photo-1585032226651-759b368d7246?w=400&fit=crop"),
    Product(id: 135, name: "Pad Thai", price: 280, description: "Thai style noodles", category: "food", emoji: "🍜", imageUrl: "https://images.unsplash.com/photo-1559314809-0d155014e29e?w=400&fit=crop"),
    
    // Snacks & Starters (8 items)
    Product(id: 136, name: "French Fries", price: 90, description: "Crispy golden fries", category: "food", emoji: "🍟", imageUrl: "https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=400&fit=crop"),
    Product(id: 137, name: "Paneer Tikka", price: 240, description: "Grilled cottage cheese", category: "food", emoji: "🍢", imageUrl: "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=400&fit=crop"),
    Product(id: 138, name: "Chicken Wings", price: 320, description: "Spicy BBQ wings, 6 pcs", category: "food", emoji: "🍗", imageUrl: "https://images.unsplash.com/photo-1527477396000-e27163b481c2?w=400&fit=crop"),
    Product(id: 139, name: "Spring Rolls", price: 140, description: "Veg spring rolls, 4 pcs", category: "food", emoji: "🥟", imageUrl: "https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=400&fit=crop"),
    Product(id: 140, name: "Samosa", price: 40, description: "Crispy potato samosa, 2 pcs", category: "food", emoji: "🥟", imageUrl: "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&fit=crop"),
    Product(id: 141, name: "Pakoda", price: 80, description: "Mixed veg fritters, 200g", category: "food", emoji: "🥘", imageUrl: "https://images.unsplash.com/photo-1626082927389-6cd097cee6a6?w=400&fit=crop"),
    Product(id: 142, name: "Chicken Nuggets", price: 180, description: "Crispy nuggets, 8 pcs", category: "food", emoji: "🍗", imageUrl: "https://images.unsplash.com/photo-1562802378-063ec186a863?w=400&fit=crop"),
    Product(id: 143, name: "Momos", price: 120, description: "Steamed dumplings, 8 pcs", category: "food", emoji: "🥟", imageUrl: "https://images.unsplash.com/photo-1496116218417-1a781b1c416c?w=400&fit=crop"),
    
    // Desserts (7 items)
    Product(id: 144, name: "Chocolate Cake", price: 450, description: "Rich truffle cake, 500g", category: "food", emoji: "🍰", imageUrl: "https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400&fit=crop"),
    Product(id: 145, name: "Gulab Jamun", price: 100, description: "Sweet balls, 6 pcs", category: "food", emoji: "🍡", imageUrl: "https://images.unsplash.com/photo-1666385810754-020c0979b552?w=400&fit=crop"),
    Product(id: 146, name: "Rasgulla", price: 90, description: "Spongy sweets, 6 pcs", category: "food", emoji: "🍡", imageUrl: "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&fit=crop"),
    Product(id: 147, name: "Ice Cream", price: 180, description: "Assorted flavors, 500ml", category: "food", emoji: "🍨", imageUrl: "https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&fit=crop"),
    Product(id: 148, name: "Brownie", price: 120, description: "Chocolate brownie with ice cream", category: "food", emoji: "🍰", imageUrl: "https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=400&fit=crop"),
    Product(id: 149, name: "Tiramisu", price: 280, description: "Italian coffee dessert", category: "food", emoji: "🍰", imageUrl: "https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=400&fit=crop"),
    Product(id: 150, name: "Kheer", price: 80, description: "Rice pudding, 250g", category: "food", emoji: "🍮", imageUrl: "https://images.unsplash.com/photo-1611274586645-3bc4c5f2b8e0?w=400&fit=crop"),
    
    // Beverages (10 items)
    Product(id: 151, name: "Mango Smoothie", price: 110, description: "Fresh mango smoothie", category: "food", emoji: "🥤", imageUrl: "https://images.unsplash.com/photo-1546173159-315724a31696?w=400&fit=crop"),
    Product(id: 152, name: "Banana Shake", price: 100, description: "Thick banana milkshake", category: "food", emoji: "🥤", imageUrl: "https://images.unsplash.com/photo-1553530666-ba11a90a3410?w=400&fit=crop"),
    Product(id: 153, name: "Fresh Lime Soda", price: 60, description: "Refreshing lime drink", category: "food", emoji: "🥤", imageUrl: "https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400&fit=crop"),
    Product(id: 154, name: "Lassi", price: 80, description: "Sweet/salty yogurt drink", category: "food", emoji: "🥛", imageUrl: "https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=400&fit=crop"),
    Product(id: 155, name: "Cold Coffee", price: 120, description: "Iced coffee with cream", category: "food", emoji: "☕", imageUrl: "https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400&fit=crop"),
    Product(id: 156, name: "Hot Chocolate", price: 130, description: "Rich hot chocolate", category: "food", emoji: "☕", imageUrl: "https://images.unsplash.com/photo-1517578239113-b03992dcdd25?w=400&fit=crop"),
    Product(id: 157, name: "Masala Chai", price: 40, description: "Spiced Indian tea", category: "food", emoji: "🍵", imageUrl: "https://images.unsplash.com/photo-1571934811356-5cc061b6821f?w=400&fit=crop"),
    Product(id: 158, name: "Green Tea", price: 50, description: "Healthy green tea", category: "food", emoji: "🍵", imageUrl: "https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400&fit=crop"),
    Product(id: 159, name: "Orange Juice", price: 90, description: "Fresh squeezed juice", category: "food", emoji: "🍊", imageUrl: "https://images.unsplash.com/photo-1613478223719-2ab802602423?w=400&fit=crop"),
    Product(id: 160, name: "Watermelon Juice", price: 85, description: "Fresh watermelon juice", category: "food", emoji: "🍉", imageUrl: "https://images.unsplash.com/photo-1527838832700-5059252407fa?w=400&fit=crop"),
  ];

  static final List<Product> fashionProducts = [
    // --- Tops ---
    Product(id: 201, name: "Cotton T-Shirt - Black", price: 499, description: "Premium cotton tee, S-XXL", category: "fashion", emoji: "👕", imageUrl: "https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=500&q=80"),
    Product(id: 202, name: "Polo T-Shirt", price: 799, description: "Collar polo, multiple colors", category: "fashion", emoji: "👕", imageUrl: "https://images.unsplash.com/photo-1586363104862-3a5e2ab60d99?w=500&q=80"),
    Product(id: 203, name: "V-Neck T-Shirt", price: 599, description: "Casual v-neck tee", category: "fashion", emoji: "👕", imageUrl: "https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=500&q=80"),
    Product(id: 204, name: "Graphic T-Shirt", price: 699, description: "Printed design tee", category: "fashion", emoji: "👕", imageUrl: "https://images.unsplash.com/photo-1562157873-818bc0726f68?w=500&q=80"),
    Product(id: 205, name: "Full Sleeve T-Shirt", price: 749, description: "Long sleeve cotton", category: "fashion", emoji: "👕", imageUrl: "https://images.unsplash.com/photo-1618354691373-d851c5c3a990?w=500&q=80"),
    Product(id: 206, name: "Sports T-Shirt", price: 899, description: "Dri-fit sports tee", category: "fashion", emoji: "👕", imageUrl: "https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=500&q=80"),
    Product(id: 209, name: "Crop Top", price: 599, description: "Trendy crop top, XS-XL", category: "fashion", emoji: "👚", imageUrl: "https://images.unsplash.com/photo-1503342217505-b0a15ec3261c?w=500&q=80"),
    Product(id: 211, name: "Blouse", price: 899, description: "Formal blouse", category: "fashion", emoji: "👚", imageUrl: "https://images.unsplash.com/photo-1503342217505-b0a15ec3261c?w=500&q=80"),
    Product(id: 214, name: "Kurti", price: 999, description: "Traditional kurti", category: "fashion", emoji: "👚", imageUrl: "https://images.unsplash.com/photo-1503342217505-b0a15ec3261c?w=500&q=80"),

    // --- Bottoms ---
    Product(id: 215, name: "Slim Fit Jeans - Blue", price: 1299, description: "Classic blue denim, 28-40", category: "fashion", emoji: "👖", imageUrl: "https://images.unsplash.com/photo-1542272604-787c3835535d?w=500&q=80"),
    Product(id: 216, name: "Skinny Jeans - Black", price: 1399, description: "Stretchable black jeans", category: "fashion", emoji: "👖", imageUrl: "https://images.unsplash.com/photo-1541099649105-f69ad21f3246?w=500&q=80"),
    Product(id: 219, name: "Chinos", price: 1099, description: "Formal chino pants", category: "fashion", emoji: "👖", imageUrl: "https://images.unsplash.com/photo-1473966968600-fa804b86862b?w=500&q=80"),
    Product(id: 220, name: "Cargo Pants", price: 1249, description: "Multi-pocket cargo", category: "fashion", emoji: "👖", imageUrl: "https://images.unsplash.com/photo-1473966968600-fa804b86862b?w=500&q=80"),
    Product(id: 221, name: "Track Pants", price: 799, description: "Comfortable trackpants", category: "fashion", emoji: "👖", imageUrl: "https://images.unsplash.com/photo-1473966968600-fa804b86862b?w=500&q=80"),

    // --- Dresses & Ethnic ---
    Product(id: 225, name: "Summer Dress", price: 1899, description: "Floral print dress, S-XL", category: "fashion", emoji: "👗", imageUrl: "https://images.unsplash.com/photo-1572804013307-f9a8a9264bb7?w=500&q=80"),
    Product(id: 227, name: "Party Dress", price: 2499, description: "Evening party wear", category: "fashion", emoji: "👗", imageUrl: "https://images.unsplash.com/photo-1572804013307-f9a8a9264bb7?w=500&q=80"),
    Product(id: 229, name: "Saree", price: 2999, description: "Designer saree with blouse", category: "fashion", emoji: "🥻", imageUrl: "https://images.unsplash.com/photo-1583391733956-3750e0ff4e8b?w=500&q=80"),
    Product(id: 231, name: "Lehenga", price: 4999, description: "Festive lehenga set", category: "fashion", emoji: "👗", imageUrl: "https://images.unsplash.com/photo-1583391733956-3750e0ff4e8b?w=500&q=80"),

    // --- Footwear ---
    Product(id: 233, name: "Running Shoes", price: 2299, description: "Comfortable sports shoes, 6-12", category: "fashion", emoji: "👟", imageUrl: "https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=500&q=80"),
    Product(id: 234, name: "Casual Sneakers", price: 1899, description: "Everyday sneakers", category: "fashion", emoji: "👟", imageUrl: "https://images.unsplash.com/photo-1595950653106-6c9ebd614d3a?w=500&q=80"),
    Product(id: 235, name: "Formal Shoes", price: 2599, description: "Leather formal shoes", category: "fashion", emoji: "👞", imageUrl: "https://images.unsplash.com/photo-1533867617858-e7b97e060509?w=500&q=80"),
    Product(id: 241, name: "Heels", price: 2199, description: "Elegant high heels, 5-9", category: "fashion", emoji: "👠", imageUrl: "https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=500&q=80"),
    Product(id: 244, name: "Ankle Boots", price: 2799, description: "Stylish ankle boots", category: "fashion", emoji: "👢", imageUrl: "https://images.unsplash.com/photo-1608256246200-53e635b5b65f?w=500&q=80"),

    // --- Accessories ---
    Product(id: 248, name: "Sunglasses", price: 799, description: "UV protection aviator, One Size", category: "fashion", emoji: "🕶️", imageUrl: "https://images.unsplash.com/photo-1511499767390-90342f568952?w=500&q=80"),
    Product(id: 249, name: "Watch - Men's", price: 2499, description: "Analog wristwatch", category: "fashion", emoji: "⌚", imageUrl: "https://images.unsplash.com/photo-1524592094714-0f0654e20314?w=500&q=80"),
    Product(id: 251, name: "Handbag", price: 1599, description: "Stylish leather handbag", category: "fashion", emoji: "👜", imageUrl: "https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=500&q=80"),
    Product(id: 252, name: "Backpack", price: 1899, description: "Laptop backpack", category: "fashion", emoji: "🎒", imageUrl: "https://images.unsplash.com/photo-1553062407-98eeb94c6a62?w=500&q=80"),

    // --- Outerwear ---
    Product(id: 259, name: "Leather Jacket", price: 3499, description: "Genuine leather biker jacket, S-XXL", category: "fashion", emoji: "🧥", imageUrl: "https://images.unsplash.com/photo-1551028719-00167b16eac5?w=500&q=80"),
    Product(id: 262, name: "Hoodie", price: 1299, description: "Comfortable hoodie", category: "fashion", emoji: "🧥", imageUrl: "https://images.unsplash.com/photo-1556821840-3a63f95609a7?w=500&q=80"),
    Product(id: 263, name: "Blazer", price: 3999, description: "Formal blazer", category: "fashion", emoji: "🧥", imageUrl: "https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=500&q=80"),
  ];

  static List<Product> getAllProducts() {
    return [...groceryProducts, ...foodProducts, ...fashionProducts];
  }

  static List<Product> getProductsByCategory(String category) {
    switch (category.toLowerCase()) {
      case 'grocery': return groceryProducts;
      case 'food': return foodProducts;
      case 'fashion': return fashionProducts;
      default: return getAllProducts();
    }
  }
}