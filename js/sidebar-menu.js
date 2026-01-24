document.addEventListener("DOMContentLoaded", () => {
    const smToggle = document.getElementById('smToggle');
    const smPanel = document.getElementById('smPanel');
    const smIcon = document.getElementById('smIcon');
    const smText = document.getElementById('smToggleText');
    
    let isMenuOpen = false;

    smToggle.addEventListener('click', () => {
        isMenuOpen = !isMenuOpen;

        // Toggle visibility instantly
        smPanel.classList.toggle('active');
        smIcon.classList.toggle('menu-open');

        if (isMenuOpen) {
            smToggle.style.color = "#000";
            smToggle.style.background = "#fff";
            smText.innerText = "Close";
        } else {
            smToggle.style.color = "#fff";
            smToggle.style.background = "rgba(255, 255, 255, 0.2)";
            smText.innerText = "Menu";
        }
    });

    // Close menu on link click
    document.querySelectorAll('.sm-panel-item').forEach(link => {
        link.addEventListener('click', () => {
            if (isMenuOpen) smToggle.click();
        });
    });
});
