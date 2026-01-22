(() => {
    const btn = document.querySelector('.submit-btn');
    if (!btn) return;

    btn.addEventListener('pointermove', (e) => {
        const rect = btn.getBoundingClientRect();
        const offsetX = e.clientX - rect.left;
        const offsetY = e.clientY - rect.top;
        const tiltX = ((offsetX / rect.width) - 0.5) * 10;
        const tiltY = -((offsetY / rect.height) - 0.5) * 6;
        btn.style.setProperty('--tiltX', `${tiltX}deg`);
        btn.style.setProperty('--tiltY', `${tiltY}deg`);
    });

    btn.addEventListener('pointerleave', () => {
        btn.style.setProperty('--tiltX', '0deg');
        btn.style.setProperty('--tiltY', '0deg');
    });

    btn.addEventListener('click', (e) => {
        const rect = btn.getBoundingClientRect();
        const ripple = document.createElement('span');
        ripple.className = 'submit-ripple';
        ripple.style.left = `${e.clientX - rect.left}px`;
        ripple.style.top = `${e.clientY - rect.top}px`;
        btn.appendChild(ripple);
        ripple.addEventListener('animationend', () => ripple.remove());
    });
})();
