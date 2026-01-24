// ===== FLAPPY BIRD GAME =====
const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');
const scoreElement = document.getElementById('score');
const highScoreElement = document.getElementById('highScore');
const levelElement = document.getElementById('level');

// Set canvas to full screen dimensions
function resizeCanvas() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
}
resizeCanvas();
window.addEventListener('resize', resizeCanvas);

// Game variables
let frames = 0;
let score = 0;
let level = 1;
let highScore = localStorage.getItem('flappyHighScore') || 0;
let highestLevel = localStorage.getItem('flappyHighestLevel') || 1;
highScoreElement.textContent = `Best: ${highScore}`;

// Game state
let gameState = 'playing'; // start, playing, gameover

// Difficulty variables that change with level
let pipeGap = 220;
let pipeSpeed = 2;
let pipeFrequency = 100;

// Bird object
const bird = {
    x: 80,
    y: 250,
    width: 40,
    height: 30,
    velocity: 0,
    gravity: 0.5,
    jump: -10,
    drop: 8,
    
    draw() {
        // Bird shadow
        ctx.fillStyle = 'rgba(0, 0, 0, 0.2)';
        ctx.beginPath();
        ctx.ellipse(this.x + 20, canvas.height - 60, 22, 6, 0, 0, Math.PI * 2);
        ctx.fill();
        
        // Bird body
        ctx.fillStyle = '#FFD700';
        ctx.beginPath();
        ctx.arc(this.x + 20, this.y + 15, 18, 0, Math.PI * 2);
        ctx.fill();
        
        // Bird outline
        ctx.strokeStyle = '#FF6347';
        ctx.lineWidth = 2.5;
        ctx.stroke();
        
        // Eye white with shadow
        ctx.fillStyle = '#fff';
        ctx.beginPath();
        ctx.arc(this.x + 28, this.y + 12, 5.5, 0, Math.PI * 2);
        ctx.fill();
        
        // Eye pupil
        ctx.fillStyle = '#000';
        ctx.beginPath();
        ctx.arc(this.x + 30, this.y + 12, 3.5, 0, Math.PI * 2);
        ctx.fill();
        
        // Eye shine
        ctx.fillStyle = '#fff';
        ctx.beginPath();
        ctx.arc(this.x + 31, this.y + 11, 1.2, 0, Math.PI * 2);
        ctx.fill();
        
        // Beak
        ctx.fillStyle = '#FF6347';
        ctx.beginPath();
        ctx.moveTo(this.x + 35, this.y + 15);
        ctx.lineTo(this.x + 46, this.y + 15);
        ctx.lineTo(this.x + 35, this.y + 21);
        ctx.closePath();
        ctx.fill();
        
        // Wing with gradient
        const wingGradient = ctx.createLinearGradient(this.x + 4, this.y + 10, this.x + 20, this.y + 30);
        wingGradient.addColorStop(0, '#FFA500');
        wingGradient.addColorStop(1, '#FF8C00');
        ctx.fillStyle = wingGradient;
        ctx.beginPath();
        ctx.ellipse(this.x + 12, this.y + 20, 10, 14, Math.PI / 4, 0, Math.PI * 2);
        ctx.fill();
    },
    
    update() {
        this.velocity += this.gravity;
        this.y += this.velocity;
        
        // Ground collision
        if (this.y + this.height >= canvas.height - 50) {
            this.y = canvas.height - 50 - this.height;
            this.velocity = 0;
            if (gameState === 'playing') endGame();
        }
        
        // Ceiling collision
        if (this.y <= 0) {
            this.y = 0;
            this.velocity = 0;
        }
    },
    
    flap() {
        this.velocity = this.jump;
    },

    dropDown() {
        this.velocity = this.drop;
    },
    
    reset() {
        this.y = 250;
        this.velocity = 0;
    }
};

// Pipes array
let pipes = [];
const pipeWidth = 60;

function updateDifficulty() {
    // Increase speed every level (caps at level 100)
    pipeSpeed = Math.min(2 + (level - 1) * 0.15, 17);
    
    // Decrease gap size every level (minimum gap of 100)
    pipeGap = Math.max(180 - (level - 1) * 1.5, 100);
    
    // Increase pipe frequency every level (minimum 40 frames between pipes)
    pipeFrequency = Math.max(100 - (level - 1) * 1, 40);
    
    // Update gravity slightly for higher levels (caps at 0.8)
    bird.gravity = Math.min(0.5 + (level - 1) * 0.005, 0.8);
}

function createPipe() {
    const minHeight = 50;
    const maxHeight = canvas.height - 200 - pipeGap;
    const topHeight = Math.floor(Math.random() * (maxHeight - minHeight + 1)) + minHeight;
    
    pipes.push({
        x: canvas.width,
        topHeight: topHeight,
        bottomY: topHeight + pipeGap,
        scored: false,
        levelScored: false
    });
}

function drawPipe(pipe) {
    // Pipe gradient
    const gradient = ctx.createLinearGradient(pipe.x, 0, pipe.x + pipeWidth, 0);
    gradient.addColorStop(0, '#4CAF50');
    gradient.addColorStop(0.5, '#5CDB95');
    gradient.addColorStop(1, '#45a049');
    
    // Top pipe with shadow
    ctx.shadowColor = 'rgba(0, 0, 0, 0.3)';
    ctx.shadowBlur = 8;
    ctx.fillStyle = gradient;
    ctx.fillRect(pipe.x, 0, pipeWidth, pipe.topHeight);
    
    // Top pipe cap with 3D effect
    ctx.fillStyle = '#3d8b40';
    ctx.fillRect(pipe.x - 8, pipe.topHeight - 20, pipeWidth + 16, 20);
    ctx.fillStyle = gradient;
    ctx.fillRect(pipe.x - 5, pipe.topHeight - 30, pipeWidth + 10, 15);
    
    // Bottom pipe
    ctx.fillStyle = gradient;
    ctx.fillRect(pipe.x, pipe.bottomY, pipeWidth, canvas.height - pipe.bottomY - 50);
    
    // Bottom pipe cap with 3D effect
    ctx.fillStyle = '#3d8b40';
    ctx.fillRect(pipe.x - 8, pipe.bottomY - 5, pipeWidth + 16, 20);
    ctx.fillStyle = gradient;
    ctx.fillRect(pipe.x - 5, pipe.bottomY, pipeWidth + 10, 30);
    
    // Pipe outlines for depth
    ctx.shadowColor = 'transparent';
    ctx.strokeStyle = '#2C5F2D';
    ctx.lineWidth = 2.5;
    ctx.strokeRect(pipe.x, 0, pipeWidth, pipe.topHeight);
    ctx.strokeRect(pipe.x, pipe.bottomY, pipeWidth, canvas.height - pipe.bottomY - 50);
    
    // Highlight edges
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.2)';
    ctx.lineWidth = 1;
    ctx.strokeRect(pipe.x + 2, 2, pipeWidth - 4, pipe.topHeight - 2);
}

function updatePipes() {
    if (frames % pipeFrequency === 0) {
        createPipe();
    }
    
    pipes.forEach((pipe, index) => {
        pipe.x -= pipeSpeed;
        
        // Check for score
        if (!pipe.scored && pipe.x + pipeWidth < bird.x) {
            pipe.scored = true;
            score++;
            scoreElement.textContent = `Score: ${score}`;
        }
        
        // Check for level up (every 5 points, max level 1000)
        if (!pipe.levelScored && pipe.x + pipeWidth < bird.x && score > 0 && score % 5 === 0) {
            pipe.levelScored = true;
            if (level < 1000) {
                level++;
                levelElement.textContent = `Level: ${level}`;
                updateDifficulty();
                
                // Visual feedback for level up
                canvas.style.animation = 'none';
                setTimeout(() => {
                    canvas.style.animation = 'pulse 0.3s ease-in-out';
                }, 10);
            }
        }
        
        // Remove off-screen pipes
        if (pipe.x + pipeWidth < 0) {
            pipes.splice(index, 1);
        }
        
        // Collision detection
        if (
            bird.x + bird.width > pipe.x &&
            bird.x < pipe.x + pipeWidth &&
            (bird.y < pipe.topHeight || bird.y + bird.height > pipe.bottomY)
        ) {
            if (gameState === 'playing') endGame();
        }
    });
}

function drawBackground() {
    // Sky gradient - more vibrant
    const skyGradient = ctx.createLinearGradient(0, 0, 0, canvas.height - 50);
    skyGradient.addColorStop(0, '#87CEEB');
    skyGradient.addColorStop(1, '#E0F8FF');
    ctx.fillStyle = skyGradient;
    ctx.fillRect(0, 0, canvas.width, canvas.height - 50);
    
    // Sun
    ctx.fillStyle = 'rgba(255, 200, 50, 0.3)';
    ctx.beginPath();
    ctx.arc(350, 80, 60, 0, Math.PI * 2);
    ctx.fill();
    
    ctx.fillStyle = 'rgba(255, 215, 0, 0.7)';
    ctx.beginPath();
    ctx.arc(350, 80, 40, 0, Math.PI * 2);
    ctx.fill();
    
    // Clouds - improved
    ctx.fillStyle = 'rgba(255, 255, 255, 0.8)';
    ctx.shadowColor = 'rgba(0, 0, 0, 0.1)';
    ctx.shadowBlur = 5;
    
    // Cloud 1
    ctx.beginPath();
    ctx.arc(100 - (frames % 450) + canvas.width, 70, 35, 0, Math.PI * 2);
    ctx.arc(140 - (frames % 450) + canvas.width, 65, 40, 0, Math.PI * 2);
    ctx.arc(180 - (frames % 450) + canvas.width, 70, 35, 0, Math.PI * 2);
    ctx.fill();
    
    // Cloud 2
    ctx.beginPath();
    ctx.arc(300 - (frames % 500) + canvas.width, 110, 30, 0, Math.PI * 2);
    ctx.arc(335 - (frames % 500) + canvas.width, 105, 35, 0, Math.PI * 2);
    ctx.arc(370 - (frames % 500) + canvas.width, 110, 30, 0, Math.PI * 2);
    ctx.fill();
    
    ctx.shadowColor = 'transparent';
    
    // Ground
    ctx.fillStyle = '#C1A66B';
    ctx.fillRect(0, canvas.height - 50, canvas.width, 50);
    
    // Grass
    ctx.fillStyle = '#90EE90';
    ctx.fillRect(0, canvas.height - 50, canvas.width, 12);
    
    // Ground pattern
    ctx.fillStyle = 'rgba(139, 115, 85, 0.5)';
    for (let i = 0; i < canvas.width; i += 25) {
        ctx.fillRect(i - (frames % 25), canvas.height - 35, 12, 8);
    }
    
    // Grass details
    ctx.strokeStyle = 'rgba(76, 175, 80, 0.6)';
    ctx.lineWidth = 1.5;
    for (let i = 0; i < canvas.width; i += 20) {
        ctx.beginPath();
        ctx.moveTo(i - (frames % 20), canvas.height - 50);
        ctx.lineTo(i - (frames % 20) + 3, canvas.height - 46);
        ctx.stroke();
    }
}

function drawStartScreen() {
    // Don't show start screen - game starts immediately
}

function drawGameOver() {
    // Dark overlay
    ctx.fillStyle = 'rgba(0, 0, 0, 0.8)';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // Game Over title with glow effect
    ctx.shadowColor = 'rgba(255, 99, 71, 0.7)';
    ctx.shadowBlur = 20;
    ctx.fillStyle = '#FF6347';
    ctx.font = 'bold 56px Segoe UI';
    ctx.textAlign = 'center';
    ctx.fillText('Game Over!', canvas.width / 2, canvas.height / 2 - 100);
    ctx.shadowColor = 'transparent';
    
    // Stats container
    ctx.fillStyle = 'rgba(255, 255, 255, 0.1)';
    ctx.fillRect(canvas.width / 2 - 140, canvas.height / 2 - 40, 280, 120);
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.3)';
    ctx.lineWidth = 2;
    ctx.strokeRect(canvas.width / 2 - 140, canvas.height / 2 - 40, 280, 120);
    
    // Stats text
    ctx.fillStyle = '#fff';
    ctx.font = '26px Segoe UI';
    ctx.textAlign = 'center';
    ctx.fillText(`Level: ${level}`, canvas.width / 2, canvas.height / 2 - 10);
    ctx.fillText(`Score: ${score}`, canvas.width / 2, canvas.height / 2 + 25);
    ctx.fillText(`Best: ${highScore}`, canvas.width / 2, canvas.height / 2 + 60);
    
    // Play again button
    ctx.fillStyle = 'rgba(102, 126, 234, 0.8)';
    ctx.fillRect(canvas.width / 2 - 130, canvas.height / 2 + 100, 260, 50);
    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 2;
    ctx.strokeRect(canvas.width / 2 - 130, canvas.height / 2 + 100, 260, 50);
    
    ctx.fillStyle = '#fff';
    ctx.font = 'bold 22px Segoe UI';
    ctx.fillText('Press ↑ or Click to Play Again', canvas.width / 2, canvas.height / 2 + 132);
}

function endGame() {
    gameState = 'gameover';
    
    // Update high score
    if (score > highScore) {
        highScore = score;
        localStorage.setItem('flappyHighScore', highScore);
        highScoreElement.textContent = `Best: ${highScore}`;
    }
    
    // Update highest level
    if (level > highestLevel) {
        highestLevel = level;
        localStorage.setItem('flappyHighestLevel', highestLevel);
    }
}

function resetGame() {
    score = 0;
    level = 1;
    frames = 0;
    pipes = [];
    bird.reset();
    scoreElement.textContent = 'Score: 0';
    levelElement.textContent = 'Level: 1';
    updateDifficulty();
    gameState = 'playing';
}

function gameLoop() {
    frames++;
    
    drawBackground();
    
    if (gameState === 'start') {
        drawStartScreen();
        bird.draw();
    } else if (gameState === 'playing') {
        bird.update();
        bird.draw();
        updatePipes();
        pipes.forEach(pipe => drawPipe(pipe));
    } else if (gameState === 'gameover') {
        pipes.forEach(pipe => drawPipe(pipe));
        bird.draw();
        drawGameOver();
    }
    
    requestAnimationFrame(gameLoop);
}

// Event listeners
canvas.addEventListener('click', () => {
    if (gameState === 'gameover') {
        resetGame();
    }
});

document.addEventListener('keydown', (e) => {
    if (e.code === 'ArrowUp') {
        e.preventDefault();
        if (gameState === 'start') {
            gameState = 'playing';
        } else if (gameState === 'playing') {
            bird.flap();
        } else if (gameState === 'gameover') {
            resetGame();
        }
    } else if (e.code === 'ArrowDown') {
        e.preventDefault();
        if (gameState === 'playing') {
            bird.dropDown();
        }
    }
});

// Start the game
updateDifficulty();
gameLoop();
