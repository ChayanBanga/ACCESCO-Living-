// Grokly Market Product Management
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm'

const supabase = createClient(
  'https://nfdrnbikwzfmijrqmoqt.supabase.co',
  'sb_publishable_dVvOYAqamp2BGoI8zvyB5g_NfCSkQ6b'
)

let products = [];
let filtered = [];
let cart = JSON.parse(localStorage.getItem('cart')) || [];

const ui = {
  feed: document.getElementById('feed'),
  cartCount: document.getElementById('cart-count'), 
  cartItems: document.getElementById('cartItems'),
  cartTotal: document.getElementById('cartTotal'),
  cartView: document.getElementById('cartView'),
  cartBackdrop: document.getElementById('cartBackdrop'),
  placeOrderBtn: document.getElementById('placeOrderBtn'),
  addrDisplay: document.getElementById('addrDisplay'),
  addressModal: document.getElementById('addressModal'),
  addressBackdrop: document.getElementById('addressBackdrop')
};

async function fetchProducts() {
  try {
    // Added 'stock' to the select query
    const { data, error } = await supabase.from('products').select('*, stock').limit(100); 
    if (error) throw error;
    products = data.map(p => ({
      id: p.id,
      title: p.name || p.title || 'Grokly Item',
      price: p.price || 0,
      image: p.image_url || p.image || 'https://via.placeholder.com/300?text=Product',
      category: canonicalCategory(p.category),
      vendor_id: p.vendor_id || null,
      stock: p.stock ?? 999 // Use nullish coalescing: 0 stays 0, null/undefined becomes 999
    }));
    filtered = [...products];
    renderProducts(); 
    updateBadge();
    loadSavedAddress();
  } catch (e) { console.error("Fetch error:", e); }
}

function canonicalCategory(cat) {
  const s = (cat || '').toLowerCase();
  if (s.includes('fruit')) return 'Fruits';
  if (s.includes('veget')) return 'Vegetables';
  if (s.includes('dairy') || s.includes('milk')) return 'Dairy and Bakery';
  if (s.includes('cloth') || s.includes('shirt') || s.includes('wear') || s.includes('pant')) return 'Clothes';
  if (s.includes('snack')) return 'Snacks';
  return 'Grocery';
}

function renderProducts() {
  ui.feed.innerHTML = '';
  const categories = [...new Set(filtered.map(p => p.category))];
  
  // Custom sort order
  const order = ['Vegetables', 'Fruits', 'Dairy and Bakery', 'Clothes', 'Snacks', 'Grocery'];
  categories.sort((a,b) => order.indexOf(a) - order.indexOf(b));

  categories.forEach(cat => {
    const items = filtered.filter(p => p.category === cat);
    if(items.length === 0) return;

    const sec = el('section', {class:'feed-section'}, [
      el('h3', {class:'feed-title'}, [
        cat === 'Clothes' ? el('i', {class:'ri-shirt-line'}) : '',
        cat
      ]),
      el('div', {class:'product-grid'}, items.map(p => productCard(p)))
    ]);
    ui.feed.appendChild(sec);
  });
}

function productCard(p) {
  // Check if stock exists and is a number, if not treat as unlimited
  const stockValue = p.stock !== null && p.stock !== undefined ? p.stock : 999;
  const isOutOfStock = stockValue <= 0;
  const stockDisplay = (p.stock !== null && p.stock !== undefined) ? `Stock: ${p.stock}` : 'Stock: Unlimited';
  
  // Create image with better error handling
  const imgElement = el('img', {
    class:'p-img', 
    src: p.image, 
    loading: 'lazy', 
    onerror: function(e) {
      // Try multiple fallbacks if image fails
      if (!e.target.dataset.retried) {
        e.target.dataset.retried = 'true';
        e.target.src = 'https://via.placeholder.com/300x300?text=' + encodeURIComponent(p.title);
      } else if (!e.target.dataset.retried2) {
        e.target.dataset.retried2 = 'true';
        e.target.src = 'https://placehold.co/300x300?text=Product&font=raleway';
      } else {
        e.target.src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="300" height="300"%3E%3Crect fill="%23f0f0f0" width="300" height="300"/%3E%3Ctext x="50%25" y="50%25" dominant-baseline="middle" text-anchor="middle" font-family="Arial" font-size="16" fill="%23999"%3EImage not available%3C/text%3E%3C/svg%3E';
      }
    }
  });
  
  return el('div', {class:'product-card', 'data-category': p.category, style: isOutOfStock ? 'opacity:0.6;' : ''}, [
    el('div', {class:'p-img-wrapper'}, [
      imgElement,
      isOutOfStock ? el('div', {style:'position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);background:rgba(0,0,0,0.8);color:white;padding:8px 16px;border-radius:8px;font-weight:bold;'}, 'Out of Stock') : ''
    ]),
    el('div', {class:'p-info'}, [
      el('div', {class:'p-title', innerHTML: p.title}),
      el('div', {style:'font-size:0.8rem;color:#666;margin-bottom:8px;'}, stockDisplay),
      el('div', {class:'p-meta'}, [
        el('span', {innerHTML: `₹${p.price}`}),
        el('button', {class:'add-btn', onclick: () => window.addToCart(p), innerHTML: isOutOfStock ? 'Out of Stock' : 'Add', disabled: isOutOfStock})
      ])
    ])
  ]);
}

function el(tag, attrs={}, children=[]) {
  const n = document.createElement(tag);
  Object.entries(attrs).forEach(([k,v]) => {
    if (k === 'onclick') {
      n.onclick = v;
    } else if (k === 'disabled') {
      // Handle boolean disabled attribute properly
      if (v === true || v === 'disabled') {
        n.disabled = true;
      } else {
        n.disabled = false;
      }
    } else {
      n.setAttribute(k, v);
    }
  });
  if(attrs.innerHTML) n.innerHTML = attrs.innerHTML;
  (Array.isArray(children) ? children : [children]).forEach(c => {
    if(typeof c === 'string') n.appendChild(document.createTextNode(c));
    else if(c) n.appendChild(c);
  });
  return n;
}

window.addToCart = (p) => {
  const idx = cart.findIndex(i => i.id === p.id);
  const maxStock = p.stock ?? 999; // Use nullish coalescing: 0 stays 0, null/undefined becomes 999
  
  // Check if product has available stock
  if (maxStock <= 0) {
    alert(`${p.title} is out of stock!`);
    return;
  }
  
  if(idx > -1) {
    // Check if adding one more would exceed stock
    if(cart[idx].qty >= maxStock) {
      alert(`Only ${maxStock} ${p.title}(s) available in stock!`);
      return;
    }
    cart[idx].qty++;
  } else {
    cart.push({...p, qty: 1});
  }
  saveCart(); updateBadge();
}

function saveCart() { localStorage.setItem('cart', JSON.stringify(cart)); }

function updateBadge() {
  const total = cart.reduce((s, i) => s + i.qty, 0);
  ui.cartCount.innerText = total;
  ui.cartCount.style.display = total > 0 ? 'block' : 'none';
}

function renderCart() {
  ui.cartItems.innerHTML = cart.length ? '' : '<p style="text-align:center;color:#999;">Cart is empty</p>';
  let total = 0;
  cart.forEach((item, idx) => {
    const maxQty = item.stock || 0;
    total += item.price * item.qty;
    
    ui.cartItems.appendChild(el('div', {style:'display:flex;justify-content:space-between;align-items:center;margin-bottom:15px;border-bottom:1px solid #eee;padding-bottom:10px;'}, [
      el('div', {style:'flex:1;'}, [
        el('div', {style:'font-weight:bold;'}, item.title),
        el('small', {style:'color:#999;', innerHTML: `Stock: ${maxQty} | Price: ₹${item.price}`}),
        el('div', {style:'display:flex;gap:8px;align-items:center;margin-top:8px;'}, [
          el('button', {
            style:'width:24px;height:24px;border:1px solid #ddd;border-radius:4px;background:#fff;cursor:pointer;font-weight:bold;',
            innerHTML: '-',
            onclick: () => { if(item.qty > 1) { item.qty--; saveCart(); renderCart(); updateBadge(); } }
          }),
          el('span', {style:'min-width:30px;text-align:center;font-weight:bold;', innerHTML: item.qty}),
          el('button', {
            style:'width:24px;height:24px;border:1px solid #ddd;border-radius:4px;background:#fff;cursor:pointer;font-weight:bold;',
            innerHTML: '+',
            onclick: () => { 
              if(item.qty < maxQty) { item.qty++; saveCart(); renderCart(); updateBadge(); }
              else alert(`Only ${maxQty} available!`);
            }
          })
        ])
      ]),
      el('div', {style:'text-align:right;'}, [
        el('span', {innerHTML: `₹${item.price * item.qty}`}),
        el('button', {
          style:'display:block;margin-top:8px;color:red;border:none;background:none;cursor:pointer;font-weight:600;',
          innerHTML: '✕ Remove',
          onclick: () => { cart.splice(idx, 1); saveCart(); renderCart(); updateBadge(); }
        })
      ])
    ]));
  });
  ui.cartTotal.innerText = `₹${total}`;
}

async function placeOrder() {
  const savedAddress = JSON.parse(localStorage.getItem('grokly_address'));
  if (!savedAddress) { ui.addressModal.classList.add('show'); ui.addressBackdrop.classList.add('show'); return; }
  if (cart.length === 0) return;

  // Validate stock before placing order
  for (let item of cart) {
    const product = products.find(p => p.id === item.id);
    if (!product || product.stock < item.qty) {
      alert(`Insufficient stock for ${item.title}. Available: ${product?.stock || 0}, Requested: ${item.qty}`);
      return;
    }
  }

  ui.placeOrderBtn.disabled = true;
  ui.placeOrderBtn.innerText = "Processing...";

  try {
    const { error } = await supabase.from('orders').insert([{
      items: cart,
      total_amount: cart.reduce((s, i) => s + (i.price * i.qty), 0),
      address: savedAddress,
      status: 'pending'
    }]);
    if (error) throw error;

    // Reduce stock for each product in the order
    for (let item of cart) {
      const product = products.find(p => p.id === item.id);
      if (product) {
        const newStock = Math.max(0, product.stock - item.qty); // Ensure stock doesn't go negative
        const { error: updateError } = await supabase
          .from('products')
          .update({ stock: newStock })
          .eq('id', item.id);
        
        if (updateError) {
          console.error(`Stock update error for product ${item.id}:`, updateError);
        } else {
          // Update local products array
          product.stock = newStock;
        }
      }
    }

    cart = []; saveCart(); updateBadge();
    ui.cartView.classList.remove('show');
    ui.cartBackdrop.classList.remove('show');
    const toast = document.getElementById('successToast');
    toast.style.display = 'block';
    setTimeout(() => toast.style.display = 'none', 3000);
    
    // Refresh products to show updated stock
    fetchProducts();
  } catch (err) { alert("Error: " + err.message); }
  finally { ui.placeOrderBtn.disabled = false; ui.placeOrderBtn.innerText = "Place Order"; }
}

// UI Event Listeners
ui.placeOrderBtn.onclick = placeOrder;
document.getElementById('cartBtn').onclick = () => { renderCart(); ui.cartView.classList.add('show'); ui.cartBackdrop.classList.add('show'); };
document.getElementById('closeCart').onclick = () => { ui.cartView.classList.remove('show'); ui.cartBackdrop.classList.remove('show'); };
document.getElementById('addressBtn').onclick = () => { ui.addressModal.classList.add('show'); ui.addressBackdrop.classList.add('show'); };

document.getElementById('saveAddressBtn').onclick = () => {
  const addr = { 
    house: document.getElementById('addrHouse').value, 
    street: document.getElementById('addrStreet').value, 
    pincode: document.getElementById('addrPin').value 
  };
  if(!addr.street || !addr.house) return alert("Fill all details");
  localStorage.setItem('grokly_address', JSON.stringify(addr));
  ui.addrDisplay.innerText = addr.street;
  ui.addressModal.classList.remove('show');
  ui.addressBackdrop.classList.remove('show');
};

function loadSavedAddress() {
  const saved = JSON.parse(localStorage.getItem('grokly_address'));
  if(saved) ui.addrDisplay.innerText = saved.street;
}

fetchProducts();
