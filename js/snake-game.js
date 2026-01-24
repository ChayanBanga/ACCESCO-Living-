const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');
const scoreDisplay = document.getElementById('score');
const highScoreDisplay = document.getElementById('highScore');
const overlay = document.getElementById('overlay');
const startBtn = document.getElementById('startBtn');
const statusTitle = document.getElementById('statusTitle');
const hud = document.getElementById('hud');

const GRID_SIZE = 20;
let TILE_COUNT_X;
let TILE_COUNT_Y;
let gameActive = false;

let snake = [];
let food = { x: 5, y: 5 };
let currentDir = { x: 0, y: -1 };
let nextDir = { x: 0, y: -1 };

let moveTimer = 0;
let tickDuration = 150;
let lastTime = 0;
let score = 0;
let highScore = localStorage.getItem('gardenSnakeHi') || 0;
highScoreDisplay.textContent = highScore;

function resize() {
    // Check if we are on a desktop screen
    const isDesktop = window.innerWidth >= 768;
    
    // On desktop, we allow the grid to expand significantly
    const maxW = isDesktop ? 800 : 400;
    const maxH = isDesktop ? 600 : 400;

    const w = Math.min(window.innerWidth - 80, maxW);
    const h = Math.min(window.innerHeight - 300, maxH);

    // Snap canvas to nearest multiple of GRID_SIZE to keep pixels clean
    canvas.width = Math.floor(w / GRID_SIZE) * GRID_SIZE;
    canvas.height = Math.floor(h / GRID_SIZE) * GRID_SIZE;

    TILE_COUNT_X = canvas.width / GRID_SIZE;
    TILE_COUNT_Y = canvas.height / GRID_SIZE;

    // Sync HUD width to canvas width
    hud.style.maxWidth = `${canvas.width + 48}px`;
}

window.addEventListener('resize', resize);
resize();

function spawnFood() {
    food = {
        x: Math.floor(Math.random() * TILE_COUNT_X),
        y: Math.floor(Math.random() * TILE_COUNT_Y)
    };
    if (snake.some(s => s.x === food.x && s.y === food.y)) spawnFood();
}

function initGame() {
    // Start in the center of the grid
    const startX = Math.floor(TILE_COUNT_X / 2);
    const startY = Math.floor(TILE_COUNT_Y / 2);
    
    snake = [
        { x: startX, y: startY },
        { x: startX, y: startY + 1 },
        { x: startX, y: startY + 2 }
    ];
    
    currentDir = { x: 0, y: -1 };
    nextDir = { x: 0, y: -1 };
    score = 0;
    tickDuration = 150;
    spawnFood();
    gameActive = true;
    overlay.classList.add('opacity-0', 'pointer-events-none');
    scoreDisplay.textContent = '0';
    requestAnimationFrame(mainLoop);
}

function mainLoop(timestamp) {
    if (!gameActive) return;
    const deltaTime = timestamp - lastTime;
    lastTime = timestamp;
    update(deltaTime);
    draw();
    requestAnimationFrame(mainLoop);
}

function update(dt) {
    moveTimer += dt;
    if (moveTimer >= tickDuration) {
        moveTimer = 0;
        currentDir = nextDir;
        const head = { x: snake[0].x + currentDir.x, y: snake[0].y + currentDir.y };

        if (head.x < 0 || head.x >= TILE_COUNT_X || head.y < 0 || head.y >= TILE_COUNT_Y || 
            snake.some(s => s.x === head.x && s.y === head.y)) {
            return gameOver();
        }

        snake.unshift(head);
        if (head.x === food.x && head.y === food.y) {
            score++;
            scoreDisplay.textContent = score;
            if (score > highScore) {
                highScore = score;
                localStorage.setItem('gardenSnakeHi', highScore);
                highScoreDisplay.textContent = highScore;
            }
            tickDuration = Math.max(70, 150 - (score * 1.2));
            spawnFood();
        } else {
            snake.pop();
        }
    }
}

function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Draw Food (Apple)
    const fx = food.x * GRID_SIZE + GRID_SIZE/2;
    const fy = food.y * GRID_SIZE + GRID_SIZE/2;
    ctx.fillStyle = '#ef4444';
    ctx.beginPath();
    ctx.arc(fx, fy, 7, 0, Math.PI * 2);
    ctx.fill();
    // Leaf
    ctx.fillStyle = '#22c55e';
    ctx.fillRect(fx - 1, fy - 10, 2, 4);

    // Draw Snake
    const progress = moveTimer / tickDuration;
    
    snake.forEach((s, i) => {
        let x, y;
        const isHead = i === 0;

        if (isHead) {
            x = (s.x - currentDir.x * (1 - progress)) * GRID_SIZE;
            y = (s.y - currentDir.y * (1 - progress)) * GRID_SIZE;
        } else {
            const prev = snake[i-1];
            const moveX = prev.x - s.x;
            const moveY = prev.y - s.y;
            x = (s.x + moveX * progress) * GRID_SIZE;
            y = (s.y + moveY * progress) * GRID_SIZE;
        }

        const scale = 1 - (i / snake.length) * 0.4;
        const baseSize = GRID_SIZE - 4;
        const size = baseSize * scale;
        const centerOffset = (GRID_SIZE - size) / 2;

        ctx.fillStyle = isHead ? '#22c55e' : '#4ade80';
        
        ctx.shadowColor = 'rgba(0,0,0,0.05)';
        ctx.shadowBlur = 4;
        ctx.shadowOffsetY = 2;

        ctx.beginPath();
        ctx.roundRect(x + centerOffset, y + centerOffset, size, size, size / 2.5);
        ctx.fill();
        
        ctx.shadowColor = 'transparent';

        if (!isHead && i % 2 === 0) {
            ctx.fillStyle = '#22c55e';
            ctx.beginPath();
            ctx.arc(x + GRID_SIZE/2, y + GRID_SIZE/2, size/5, 0, Math.PI * 2);
            ctx.fill();
        }

        if (isHead) {
            // Tongue
            if (Math.sin(Date.now() / 150) > 0.7) {
                ctx.fillStyle = '#fb7185';
                const tongueW = 4;
                const tongueL = 8;
                if (currentDir.x === 1) ctx.fillRect(x + size + 2, y + GRID_SIZE/2 - tongueW/2, tongueL, tongueW);
                else if (currentDir.x === -1) ctx.fillRect(x - tongueL + 2, y + GRID_SIZE/2 - tongueW/2, tongueL, tongueW);
                else if (currentDir.y === 1) ctx.fillRect(x + GRID_SIZE/2 - tongueW/2, y + size + 2, tongueW, tongueL);
                else if (currentDir.y === -1) ctx.fillRect(x + GRID_SIZE/2 - tongueW/2, y - tongueL + 2, tongueW, tongueL);
            }

            // Eyes
            const drawEye = (ex, ey) => {
                ctx.fillStyle = 'white';
                ctx.beginPath();
                ctx.arc(ex, ey, 3.5, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillStyle = '#0f172a';
                ctx.beginPath();
                ctx.arc(ex, ey, 1.5, 0, Math.PI * 2);
                ctx.fill();
            };

            if (currentDir.x !== 0) {
                const eyeX = x + (currentDir.x > 0 ? size : 4);
                drawEye(eyeX, y + 6);
                drawEye(eyeX, y + size - 2);
            } else {
                const eyeY = y + (currentDir.y > 0 ? size : 4);
                drawEye(x + 6, eyeY);
                drawEye(x + size - 2, eyeY);
            }
        }
    });
}

function gameOver() {
    gameActive = false;
    statusTitle.textContent = `Game Over! Score: ${score}`;
    startBtn.textContent = "TRY AGAIN";
    overlay.classList.remove('opacity-0', 'pointer-events-none');
}

function setDir(x, y) {
    if (x === -currentDir.x && x !== 0) return;
    if (y === -currentDir.y && y !== 0) return;
    nextDir = { x, y };
}

window.addEventListener('keydown', e => {
    if (['ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(e.key)) e.preventDefault();
    switch(e.key) {
        case 'ArrowUp': setDir(0, -1); break;
        case 'ArrowDown': setDir(0, 1); break;
        case 'ArrowLeft': setDir(-1, 0); break;
        case 'ArrowRight': setDir(1, 0); break;
    }
});

document.getElementById('upBtn').onclick = () => setDir(0, -1);
document.getElementById('downBtn').onclick = () => setDir(0, 1);
document.getElementById('leftBtn').onclick = () => setDir(-1, 0);
document.getElementById('rightBtn').onclick = () => setDir(1, 0);
startBtn.onclick = initGame;

let tX = 0, tY = 0;
canvas.addEventListener('touchstart', e => { tX = e.touches[0].clientX; tY = e.touches[0].clientY; }, {passive: true});
canvas.addEventListener('touchend', e => {
    const dx = e.changedTouches[0].clientX - tX;
    const dy = e.changedTouches[0].clientY - tY;
    if (Math.abs(dx) > Math.abs(dy)) { if (Math.abs(dx) > 20) setDir(dx > 0 ? 1 : -1, 0); }
    else { if (Math.abs(dy) > 20) setDir(0, dy > 0 ? 1 : -1); }
}, {passive: true});

draw();
