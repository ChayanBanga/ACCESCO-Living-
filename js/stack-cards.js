const stack = document.getElementById('stack');
const cards = Array.from(stack.querySelectorAll('.stack-card'));
let isAnimating = false;
let startX = 0;
let startY = 0;

stack.addEventListener('mousedown', startSwipe);
stack.addEventListener('touchstart', startSwipe);

function startSwipe(e) {
    if (isAnimating) return;
    startX = e.type.includes('mouse') ? e.clientX : e.touches[0].clientX;
    document.addEventListener('mouseup', endSwipe);
    document.addEventListener('touchend', endSwipe);
}

function endSwipe(e) {
    if (isAnimating) return;
    const endX = e.type.includes('mouse') ? e.clientX : e.changedTouches[0].clientX;
    const diff = endX - startX;

    if (Math.abs(diff) > 50) {
        const direction = diff > 0 ? 'right' : 'left';
        animateStack(direction);
    } else if (diff === 0 && e.target.closest('.stack-card')) {
        animateStack('left');
    }

    document.removeEventListener('mouseup', endSwipe);
    document.removeEventListener('touchend', endSwipe);
}

function animateStack(direction) {
    isAnimating = true;
    const front = cards.find(c => c.classList.contains('pos-1'));
    const mid = cards.find(c => c.classList.contains('pos-2'));
    const back = cards.find(c => c.classList.contains('pos-3'));

    front.classList.add(direction === 'right' ? 'swipe-right' : 'swipe-left');

    setTimeout(() => {
        front.classList.remove('pos-1', 'swipe-right', 'swipe-left');
        front.classList.add('pos-3');

        mid.classList.remove('pos-2');
        mid.classList.add('pos-1');

        back.classList.remove('pos-3');
        back.classList.add('pos-2');

        isAnimating = false;
    }, 300);
}
