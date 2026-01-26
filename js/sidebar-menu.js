document.addEventListener("DOMContentLoaded", () => {
    const smToggle = document.getElementById('smToggle');
    const smPanel = document.getElementById('smPanel');
    const smIcon = document.getElementById('smIcon');
    const smText = document.getElementById('smToggleText');
    
    let isMenuOpen = false;

    smToggle.addEventListener('click', () => {
        isMenuOpen = !isMenuOpen;

        if (isMenuOpen) {
            // Opening the menu
            smPanel.classList.remove('closing');
            smPanel.classList.add('active');
            smIcon.classList.add('menu-open');
            smToggle.style.color = "#1a0014";
            smToggle.style.background = "linear-gradient(135deg, rgba(255, 248, 240, 0.95), rgba(245, 232, 224, 0.95))";
            smToggle.style.borderColor = "rgba(112, 4, 87, 0.4)";
            smText.innerText = "CLOSE";
        } else {
            // Closing the menu with animation
            smPanel.classList.add('closing');
            setTimeout(() => {
                smPanel.classList.remove('active', 'closing');
                smIcon.classList.remove('menu-open');
                smToggle.style.color = "#fff";
                smToggle.style.background = "linear-gradient(135deg, rgba(112, 4, 87, 0.9), rgba(160, 30, 125, 0.8))";
                smToggle.style.borderColor = "rgba(255,255,255,0.6)";
                smText.innerText = "MENU";
            }, 300);
        }
    });

    // Close menu on link click with smooth closing
    document.querySelectorAll('.sm-panel-item').forEach(link => {
        link.addEventListener('click', (e) => {
            // Allow navigation but close menu smoothly
            if (isMenuOpen) {
                smPanel.classList.add('closing');
                setTimeout(() => {
                    smPanel.classList.remove('active', 'closing');
                    smIcon.classList.remove('menu-open');
                    smToggle.style.color = "#fff";
                    smToggle.style.background = "linear-gradient(135deg, rgba(112, 4, 87, 0.9), rgba(160, 30, 125, 0.8))";
                    smToggle.style.borderColor = "rgba(255,255,255,0.6)";
                    smText.innerText = "MENU";
                    isMenuOpen = false;
                }, 300);
            }
        });
    });

    // Close menu when clicking outside
    document.addEventListener('click', (e) => {
        if (isMenuOpen && !smPanel.contains(e.target) && !smToggle.contains(e.target)) {
            smPanel.classList.add('closing');
            setTimeout(() => {
                smPanel.classList.remove('active', 'closing');
                smIcon.classList.remove('menu-open');
                smToggle.style.color = "#fff";
                smToggle.style.background = "linear-gradient(135deg, rgba(112, 4, 87, 0.9), rgba(160, 30, 125, 0.8))";
                smToggle.style.borderColor = "rgba(255,255,255,0.6)";
                smText.innerText = "MENU";
                isMenuOpen = false;
            }, 300);
        }
    });
});
