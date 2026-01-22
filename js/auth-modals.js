// State variable
let isUserLoggedIn = false; 

// Main Handler for Top Right Icon
function handleUserClick() {
    if (isUserLoggedIn) {
        openProfileModal();
    } else {
        openLoginModal();
    }
}

// Login Modal Functions
function openLoginModal() {
    document.getElementById('loginOverlay').classList.add('show');
}
function closeLoginModal() {
    document.getElementById('loginOverlay').classList.remove('show');
}

// Profile Modal Functions
function openProfileModal() {
    document.getElementById('profileOverlay').classList.add('show');
}
function closeProfileModal() {
    document.getElementById('profileOverlay').classList.remove('show');
}

// Logic to simulate login/logout
function performLogin() {
    isUserLoggedIn = true;
    closeLoginModal();
    
    // Optional: Visual feedback on the top icon
    const userBtn = document.querySelector('.nav-user-btn');
    userBtn.style.color = "var(--accent)"; 
    userBtn.innerHTML = '<i class="ri-user-smile-fill"></i>';
}

function logoutUser() {
    isUserLoggedIn = false;
    closeProfileModal();
    
    // Reset Icon
    const userBtn = document.querySelector('.nav-user-btn');
    userBtn.style.color = "#000";
    userBtn.innerHTML = '<i class="ri-user-line"></i>';
}

// Close if clicked outside
document.getElementById('loginOverlay').addEventListener('click', function(e) {
    if (e.target === this) closeLoginModal();
});
document.getElementById('profileOverlay').addEventListener('click', function(e) {
    if (e.target === this) closeProfileModal();
});

// Expose to window so console users can test it easily
window.openLoginModal = openLoginModal;
