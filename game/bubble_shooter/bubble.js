// =====================================================
// GAME CONFIGURATION
// =====================================================
const CONFIG = {
    canvasWidth: 800,
    canvasHeight: 600,
    bubbleRadius: 20,
    bubbleColors: ['#FF3D5C', '#4D96FF', '#FFD700', '#00FF88', '#FF6B9D', '#00D4FF'],
    rows: 8,
    cols: 16,
    shooterY: 550,
    fps: 60,
    bubbleSpeed: 10,
    maxHints: 3,
    pointsPerBubble: 10,
    pointsPerFloater: 20,
    comboMultiplier: 1.5,
    useRenderOptimization: true,
    particlePoolSize: 200
};

// =====================================================
// NOTIFICATION SYSTEM
// =====================================================
const NotificationSystem = {
    show(title, message, onConfirm = null, showCancel = false) {
        const notification = document.getElementById('notification');
        const titleEl = document.getElementById('notificationTitle');
        const messageEl = document.getElementById('notificationMessage');
        const confirmBtn = document.getElementById('notificationConfirm');
        const cancelBtn = document.getElementById('notificationCancel');
        
        titleEl.textContent = title;
        messageEl.textContent = message;
        
        cancelBtn.style.display = showCancel ? 'block' : 'none';
        notification.classList.remove('hidden');
        
        const handleConfirm = () => {
            notification.classList.add('hidden');
            confirmBtn.removeEventListener('click', handleConfirm);
            cancelBtn.removeEventListener('click', handleCancel);
            if (onConfirm) onConfirm(true);
        };
        
        const handleCancel = () => {
            notification.classList.add('hidden');
            confirmBtn.removeEventListener('click', handleConfirm);
            cancelBtn.removeEventListener('click', handleCancel);
            if (onConfirm) onConfirm(false);
        };
        
        confirmBtn.addEventListener('click', handleConfirm);
        cancelBtn.addEventListener('click', handleCancel);
    },
    
    alert(message) {
        this.show('Notice', message);
    },
    
    confirm(message, callback) {
        this.show('Confirm', message, callback, true);
    }
};

// =====================================================
// GAME STATE MANAGEMENT
// =====================================================
const GameState = {
    currentScreen: 'mainMenu',
    level: 1,
    score: 0,
    coins: 0,
    highScores: [],
    unlockedSkins: [0],
    currentSkin: 0,
    isPaused: false,
    isGameOver: false,
    hintsRemaining: CONFIG.maxHints,
    timeElapsed: 0,
    timerInterval: null,
    musicEnabled: true,
    combo: 0,
    
    init() {
        this.coins = parseInt(localStorage.getItem('coins')) || 0;
        this.highScores = JSON.parse(localStorage.getItem('highScores')) || [];
        this.unlockedSkins = JSON.parse(localStorage.getItem('unlockedSkins')) || [0];
        this.currentSkin = parseInt(localStorage.getItem('currentSkin')) || 0;
        this.musicEnabled = localStorage.getItem('musicEnabled') !== 'false';
    },
    
    saveProgress() {
        localStorage.setItem('coins', this.coins);
        localStorage.setItem('highScores', JSON.stringify(this.highScores));
        localStorage.setItem('unlockedSkins', JSON.stringify(this.unlockedSkins));
        localStorage.setItem('currentSkin', this.currentSkin);
        localStorage.setItem('musicEnabled', this.musicEnabled);
    },
    
    addScore(points) {
        const multiplier = 1 + (this.combo * 0.1);
        this.score += Math.floor(points * this.level * multiplier);
        this.combo++;
    },
    
    resetCombo() {
        this.combo = 0;
    }
};

// =====================================================
// AUDIO SYSTEM
// =====================================================
const AudioSystem = {
    context: null,
    bgmGain: null,
    sfxGain: null,
    isPlayingBGM: false,
    
    init() {
        try {
            this.context = new (window.AudioContext || window.webkitAudioContext)();
            
            this.bgmGain = this.context.createGain();
            this.bgmGain.connect(this.context.destination);
            this.bgmGain.gain.value = 0.15;
            
            this.sfxGain = this.context.createGain();
            this.sfxGain.connect(this.context.destination);
            this.sfxGain.gain.value = 0.3;
        } catch (e) {
            console.log('Web Audio API not supported');
        }
    },
    
    playNote(frequency, duration, gainValue = 0.1) {
        if (!GameState.musicEnabled || !this.context) return;
        
        const osc = this.context.createOscillator();
        const noteGain = this.context.createGain();
        
        osc.type = 'sine';
        osc.frequency.value = frequency;
        
        noteGain.gain.value = 0;
        noteGain.gain.setValueAtTime(0, this.context.currentTime);
        noteGain.gain.linearRampToValueAtTime(gainValue, this.context.currentTime + 0.01);
        noteGain.gain.linearRampToValueAtTime(0, this.context.currentTime + duration);
        
        osc.connect(noteGain);
        noteGain.connect(this.bgmGain);
        
        osc.start(this.context.currentTime);
        osc.stop(this.context.currentTime + duration);
    },
    
    playBGM() {
        if (!GameState.musicEnabled || this.isPlayingBGM || !this.context) return;
        this.isPlayingBGM = true;
        
        const melody = [
            {freq: 523.25, dur: 0.4}, {freq: 587.33, dur: 0.4},
            {freq: 659.25, dur: 0.4}, {freq: 698.46, dur: 0.4},
            {freq: 659.25, dur: 0.4}, {freq: 587.33, dur: 0.4},
            {freq: 523.25, dur: 0.8}
        ];
        
        const playMelody = () => {
            if (!this.isPlayingBGM || !GameState.musicEnabled) return;
            
            let time = 0;
            melody.forEach(note => {
                setTimeout(() => {
                    if (this.isPlayingBGM && GameState.musicEnabled) {
                        this.playNote(note.freq, note.dur);
                    }
                }, time * 1000);
                time += note.dur;
            });
            
            setTimeout(() => {
                if (this.isPlayingBGM && GameState.musicEnabled && 
                    GameState.currentScreen === 'game' && !GameState.isPaused) {
                    playMelody();
                } else {
                    this.isPlayingBGM = false;
                }
            }, time * 1000);
        };
        
        playMelody();
    },
    
    stopBGM() {
        this.isPlayingBGM = false;
    },
    
    playSFX(type) {
        if (!GameState.musicEnabled || !this.context) return;
        
        const effects = {
            shoot: () => this.playOscillator(400, 200, 0.1, 0.3),
            pop: () => this.playOscillator(800, 100, 0.15, 0.2),
            win: () => this.playChord([523.25, 659.25, 783.99]),
            lose: () => this.playChord([400, 350, 300]),
            click: () => this.playOscillator(600, 600, 0.05, 0.1),
            hint: () => this.playOscillator(880, 440, 0.15, 0.15),
            combo: () => this.playOscillator(1000, 500, 0.2, 0.2)
        };
        
        if (effects[type]) effects[type]();
    },
    
    playOscillator(startFreq, endFreq, duration, gainValue) {
        const osc = this.context.createOscillator();
        const gain = this.context.createGain();
        
        osc.frequency.value = startFreq;
        osc.frequency.exponentialRampToValueAtTime(endFreq, this.context.currentTime + duration);
        
        gain.gain.value = gainValue;
        gain.gain.exponentialRampToValueAtTime(0.01, this.context.currentTime + duration);
        
        osc.connect(gain);
        gain.connect(this.sfxGain);
        
        osc.start();
        osc.stop(this.context.currentTime + duration);
    },
    
    playChord(frequencies) {
        frequencies.forEach((freq, i) => {
            const osc = this.context.createOscillator();
            const gain = this.context.createGain();
            
            osc.frequency.value = freq;
            gain.gain.value = 0.2;
            gain.gain.exponentialRampToValueAtTime(0.01, this.context.currentTime + 0.3 + i * 0.1);
            
            osc.connect(gain);
            gain.connect(this.sfxGain);
            
            osc.start(this.context.currentTime + i * 0.1);
            osc.stop(this.context.currentTime + 0.5 + i * 0.1);
        });
    }
};

// =====================================================
// CANNON SKINS
// =====================================================
const SKINS = [
    { name: 'Ancient Stone', emoji: '🗿', cost: 0 },
    { name: 'Bronze Cannon', emoji: '🔫', cost: 100 },
    { name: 'Silver Barrel', emoji: '🎯', cost: 250 },
    { name: 'Gold Launcher', emoji: '⚡', cost: 500 },
    { name: 'Dragon Fire', emoji: '🐉', cost: 1000 },
    { name: 'Magic Crystal', emoji: '💎', cost: 2000 }
];

// =====================================================
// GAME OBJECTS
// =====================================================
class Bubble {
    constructor(x, y, color, row, col) {
        this.x = x;
        this.y = y;
        this.color = color;
        this.row = row;
        this.col = col;
        this.scale = 1;
        this.opacity = 1;
        this.rotation = Math.random() * Math.PI * 2;
        this.pulseTime = Math.random() * 100;
    }
    
    draw(ctx) {
        if (this.opacity <= 0) return;
        
        ctx.save();
        ctx.globalAlpha = this.opacity;
        
        const radius = CONFIG.bubbleRadius * this.scale;
        const pulse = Math.sin(this.pulseTime * 0.05) * 0.05;
        
        // Main bubble with gradient
        const gradient = ctx.createRadialGradient(this.x - radius * 0.3, this.y - radius * 0.3, 0, this.x, this.y, radius);
        gradient.addColorStop(0, this.getLighterColor(this.color));
        gradient.addColorStop(0.5, this.color);
        gradient.addColorStop(0.85, this.getDarkerColor(this.color));
        gradient.addColorStop(1, 'rgba(0, 0, 0, 0.4)');
        
        ctx.fillStyle = gradient;
        ctx.beginPath();
        ctx.arc(this.x, this.y, radius * (1 + pulse * 0.1), 0, Math.PI * 2);
        ctx.fill();
        
        // Shiny highlight
        const highlightGradient = ctx.createRadialGradient(
            this.x - radius * 0.35, this.y - radius * 0.35, 0,
            this.x - radius * 0.35, this.y - radius * 0.35, radius * 0.5
        );
        highlightGradient.addColorStop(0, 'rgba(255, 255, 255, 0.8)');
        highlightGradient.addColorStop(0.5, 'rgba(255, 255, 255, 0.3)');
        highlightGradient.addColorStop(1, 'rgba(255, 255, 255, 0)');
        
        ctx.fillStyle = highlightGradient;
        ctx.beginPath();
        ctx.arc(this.x, this.y, radius, 0, Math.PI * 2);
        ctx.fill();
        
        // Add pattern texture
        this.drawPattern(ctx, radius);
        
        // Border glow
        ctx.strokeStyle = this.getGlowColor(this.color);
        ctx.lineWidth = 2.5;
        ctx.globalAlpha = this.opacity * 0.6;
        ctx.beginPath();
        ctx.arc(this.x, this.y, radius, 0, Math.PI * 2);
        ctx.stroke();
        
        ctx.restore();
        this.pulseTime++;
    }
    
    drawPattern(ctx, radius) {
        ctx.save();
        ctx.globalAlpha = this.opacity * 0.15;
        
        const colorIndex = CONFIG.bubbleColors.indexOf(this.color);
        const patterns = [
            this.drawDots.bind(this),
            this.drawWaves.bind(this),
            this.drawCross.bind(this),
            this.drawSpiral.bind(this),
            this.drawDiamond.bind(this),
            this.drawStars.bind(this)
        ];
        
        if (colorIndex >= 0 && colorIndex < patterns.length) {
            patterns[colorIndex](ctx, radius);
        }
        
        ctx.restore();
    }
    
    drawDots(ctx, radius) {
        for (let i = 0; i < 8; i++) {
            const angle = (i / 8) * Math.PI * 2;
            const x = this.x + Math.cos(angle) * radius * 0.5;
            const y = this.y + Math.sin(angle) * radius * 0.5;
            ctx.fillStyle = '#ffffff';
            ctx.beginPath();
            ctx.arc(x, y, 2, 0, Math.PI * 2);
            ctx.fill();
        }
    }
    
    drawWaves(ctx, radius) {
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 1.5;
        for (let i = 1; i <= 3; i++) {
            ctx.beginPath();
            ctx.arc(this.x, this.y, radius * (0.3 + i * 0.15), 0, Math.PI * 2);
            ctx.stroke();
        }
    }
    
    drawCross(ctx, radius) {
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 2;
        const len = radius * 0.5;
        ctx.beginPath();
        ctx.moveTo(this.x - len, this.y);
        ctx.lineTo(this.x + len, this.y);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(this.x, this.y - len);
        ctx.lineTo(this.x, this.y + len);
        ctx.stroke();
    }
    
    drawSpiral(ctx, radius) {
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        for (let i = 0; i < 100; i++) {
            const angle = (i / 10) * Math.PI * 2;
            const r = (i / 100) * radius * 0.8;
            const x = this.x + Math.cos(angle) * r;
            const y = this.y + Math.sin(angle) * r;
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.stroke();
    }
    
    drawDiamond(ctx, radius) {
        ctx.fillStyle = '#ffffff';
        const corners = [
            {x: this.x, y: this.y - radius * 0.6},
            {x: this.x + radius * 0.6, y: this.y},
            {x: this.x, y: this.y + radius * 0.6},
            {x: this.x - radius * 0.6, y: this.y}
        ];
        ctx.beginPath();
        corners.forEach((c, i) => {
            if (i === 0) ctx.moveTo(c.x, c.y);
            else ctx.lineTo(c.x, c.y);
        });
        ctx.closePath();
        ctx.fill();
    }
    
    drawStars(ctx, radius) {
        ctx.fillStyle = '#ffffff';
        for (let i = 0; i < 5; i++) {
            const angle = (i / 5) * Math.PI * 2 - Math.PI / 2;
            const x = this.x + Math.cos(angle) * radius * 0.5;
            const y = this.y + Math.sin(angle) * radius * 0.5;
            ctx.beginPath();
            ctx.arc(x, y, 2, 0, Math.PI * 2);
            ctx.fill();
        }
    }
    
    getLighterColor(color) {
        const hex = color.replace('#', '');
        const r = Math.min(255, parseInt(hex.substr(0, 2), 16) + 40);
        const g = Math.min(255, parseInt(hex.substr(2, 2), 16) + 40);
        const b = Math.min(255, parseInt(hex.substr(4, 2), 16) + 40);
        return `rgb(${r},${g},${b})`;
    }
    
    getDarkerColor(color) {
        const hex = color.replace('#', '');
        const r = Math.max(0, parseInt(hex.substr(0, 2), 16) - 60);
        const g = Math.max(0, parseInt(hex.substr(2, 2), 16) - 60);
        const b = Math.max(0, parseInt(hex.substr(4, 2), 16) - 60);
        return `rgb(${r},${g},${b})`;
    }
    
    getGlowColor(color) {
        if (color === '#FF3D5C') return 'rgba(255, 61, 92, 0.8)';
        if (color === '#4D96FF') return 'rgba(77, 150, 255, 0.8)';
        if (color === '#FFD700') return 'rgba(255, 215, 0, 0.8)';
        if (color === '#00FF88') return 'rgba(0, 255, 136, 0.8)';
        if (color === '#FF6B9D') return 'rgba(255, 107, 157, 0.8)';
        if (color === '#00D4FF') return 'rgba(0, 212, 255, 0.8)';
        return 'rgba(255, 255, 255, 0.8)';
    }
}

class Shooter {
    constructor() {
        this.x = CONFIG.canvasWidth / 2;
        this.y = CONFIG.shooterY;
        this.angle = -Math.PI / 2;
        this.currentBubble = null;
        this.nextBubble = null;
    }
    
    updateAngle(mouseX, mouseY) {
        this.angle = Math.atan2(mouseY - this.y, mouseX - this.x);
        
        // Limit angle to upper half
        const minAngle = -Math.PI + 0.1;
        const maxAngle = -0.1;
        this.angle = Math.max(minAngle, Math.min(maxAngle, this.angle));
    }
    
    draw(ctx) {
        ctx.save();
        ctx.translate(this.x, this.y);
        
        // Cannon base with gradient
        const baseGradient = ctx.createRadialGradient(0, 0, 0, 0, 0, 30);
        baseGradient.addColorStop(0, '#0099ff');
        baseGradient.addColorStop(0.7, '#0077cc');
        baseGradient.addColorStop(1, '#004499');
        
        ctx.fillStyle = baseGradient;
        ctx.beginPath();
        ctx.arc(0, 0, 30, 0, Math.PI * 2);
        ctx.fill();
        
        ctx.strokeStyle = '#00d4ff';
        ctx.lineWidth = 3;
        ctx.globalAlpha = 0.6;
        ctx.stroke();
        ctx.globalAlpha = 1;
        
        // Cannon barrel with glow
        ctx.rotate(this.angle);
        ctx.fillStyle = '#0088dd';
        ctx.fillRect(0, -10, 40, 20);
        
        ctx.strokeStyle = '#00d4ff';
        ctx.lineWidth = 2;
        ctx.globalAlpha = 0.5;
        ctx.strokeRect(0, -10, 40, 20);
        ctx.globalAlpha = 1;
        
        // Glow effect
        ctx.strokeStyle = '#00d4ff';
        ctx.lineWidth = 1;
        ctx.globalAlpha = 0.3;
        ctx.strokeRect(-2, -12, 44, 24);
        ctx.globalAlpha = 1;
        
        // Skin emoji
        ctx.rotate(-this.angle);
        ctx.font = 'bold 30px Arial';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(SKINS[GameState.currentSkin].emoji, 0, 0);
        
        // Current bubble
        if (this.currentBubble && !Game.activeBubble) {
            ctx.rotate(this.angle);
            const bubble = new Bubble(45, 0, this.currentBubble.color, 0, 0);
            bubble.scale = 0.75;
            bubble.draw(ctx);
        }
        
        ctx.restore();
    }
}

class Particle {
    constructor(x, y, color) {
        this.x = x;
        this.y = y;
        this.vx = (Math.random() - 0.5) * 6;
        this.vy = (Math.random() - 0.5) * 6 - 2;
        this.color = color;
        this.size = Math.random() * 6 + 2;
        this.life = 1;
    }
    
    update() {
        this.x += this.vx;
        this.y += this.vy;
        this.vy += 0.2;
        this.life -= 0.02;
        this.size *= 0.95;
    }
    
    draw(ctx) {
        ctx.save();
        ctx.globalAlpha = this.life;
        ctx.fillStyle = this.color;
        ctx.beginPath();
        ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
    }
}

// =====================================================
// MAIN GAME CLASS
// =====================================================
const Game = {
    canvas: null,
    ctx: null,
    bubbles: [],
    shooter: null,
    activeBubble: null,
    particles: [],
    animations: [],
    
    init() {
        this.canvas = document.getElementById('gameCanvas');
        this.ctx = this.canvas.getContext('2d');
        this.canvas.width = CONFIG.canvasWidth;
        this.canvas.height = CONFIG.canvasHeight;
        
        this.shooter = new Shooter();
        this.setupEventListeners();
    },
    
    setupEventListeners() {
        this.canvas.addEventListener('mousemove', (e) => this.handleMouseMove(e));
        this.canvas.addEventListener('click', () => this.handleClick());
    },
    
    handleMouseMove(e) {
        if (GameState.isPaused || GameState.isGameOver || this.activeBubble) return;
        
        const rect = this.canvas.getBoundingClientRect();
        const mouseX = e.clientX - rect.left;
        const mouseY = e.clientY - rect.top;
        
        this.shooter.updateAngle(mouseX, mouseY);
    },
    
    handleClick() {
        if (GameState.isPaused || GameState.isGameOver || this.activeBubble) return;
        this.shootBubble();
    },
    
    start() {
        this.reset();
        this.createBubbleGrid();
        this.shooter.currentBubble = this.createRandomBubble();
        this.shooter.nextBubble = this.createRandomBubble();
        Timer.start();
        this.loop();
        
        if (GameState.musicEnabled) {
            AudioSystem.playBGM();
        }
    },
    
    reset() {
        GameState.isPaused = false;
        GameState.isGameOver = false;
        GameState.hintsRemaining = CONFIG.maxHints;
        GameState.combo = 0;
        this.bubbles = [];
        this.particles = [];
        this.animations = [];
        this.activeBubble = null;
        UI.updateDisplay();
    },
    
    createBubbleGrid() {
        this.bubbles = [];
        const rowsForLevel = Math.min(CONFIG.rows, 4 + GameState.level);
        
        for (let row = 0; row < rowsForLevel; row++) {
            for (let col = 0; col < CONFIG.cols; col++) {
                // Hexagonal grid pattern
                if ((row % 2 === 0 || col < CONFIG.cols - 1) && Math.random() > 0.2) {
                    const x = col * (CONFIG.bubbleRadius * 2) + CONFIG.bubbleRadius + 
                             (row % 2 === 1 ? CONFIG.bubbleRadius : 0);
                    const y = row * (CONFIG.bubbleRadius * 2) + CONFIG.bubbleRadius;
                    
                    const color = CONFIG.bubbleColors[Math.floor(Math.random() * CONFIG.bubbleColors.length)];
                    this.bubbles.push(new Bubble(x, y, color, row, col));
                }
            }
        }
    },
    
    createRandomBubble() {
        const color = CONFIG.bubbleColors[Math.floor(Math.random() * CONFIG.bubbleColors.length)];
        return { color };
    },
    
    shootBubble() {
        if (!this.shooter.currentBubble || this.activeBubble) return;
        
        AudioSystem.playSFX('shoot');
        
        this.activeBubble = {
            x: this.shooter.x,
            y: this.shooter.y,
            vx: Math.cos(this.shooter.angle) * CONFIG.bubbleSpeed,
            vy: Math.sin(this.shooter.angle) * CONFIG.bubbleSpeed,
            color: this.shooter.currentBubble.color
        };
        
        this.shooter.currentBubble = this.shooter.nextBubble;
        this.shooter.nextBubble = this.createRandomBubble();
    },
    
    update() {
        if (this.activeBubble) {
            this.updateActiveBubble();
        }
        
        this.updateAnimations();
        this.updateParticles();
    },
    
    updateActiveBubble() {
        this.activeBubble.x += this.activeBubble.vx;
        this.activeBubble.y += this.activeBubble.vy;
        
        // Wall collision
        if (this.activeBubble.x - CONFIG.bubbleRadius <= 0 || 
            this.activeBubble.x + CONFIG.bubbleRadius >= CONFIG.canvasWidth) {
            this.activeBubble.vx *= -1;
            this.activeBubble.x = Math.max(CONFIG.bubbleRadius, 
                Math.min(CONFIG.canvasWidth - CONFIG.bubbleRadius, this.activeBubble.x));
        }
        
        // Check collision
        let collision = false;
        
        for (let bubble of this.bubbles) {
            const dist = Math.sqrt(
                Math.pow(this.activeBubble.x - bubble.x, 2) + 
                Math.pow(this.activeBubble.y - bubble.y, 2)
            );
            
            if (dist < CONFIG.bubbleRadius * 2) {
                collision = true;
                break;
            }
        }
        
        // Check top collision
        if (this.activeBubble.y - CONFIG.bubbleRadius <= 0) {
            collision = true;
        }
        
        if (collision) {
            this.snapBubbleToGrid();
            this.checkMatches();
            this.removeFloatingBubbles();
            this.checkGameOver();
            this.activeBubble = null;
        }
    },
    
    snapBubbleToGrid() {
        const row = Math.floor(this.activeBubble.y / (CONFIG.bubbleRadius * 2));
        const col = Math.floor((this.activeBubble.x - (row % 2 === 1 ? CONFIG.bubbleRadius : 0)) / 
                               (CONFIG.bubbleRadius * 2));
        const x = col * (CONFIG.bubbleRadius * 2) + CONFIG.bubbleRadius + 
                 (row % 2 === 1 ? CONFIG.bubbleRadius : 0);
        const y = row * (CONFIG.bubbleRadius * 2) + CONFIG.bubbleRadius;
        
        const newBubble = new Bubble(x, y, this.activeBubble.color, row, col);
        newBubble.scale = 0;
        newBubble.opacity = 0;
        
        this.bubbles.push(newBubble);
        this.animations.push({
            bubble: newBubble,
            type: 'appear',
            progress: 0
        });
    },
    
    checkMatches() {
        const lastBubble = this.bubbles[this.bubbles.length - 1];
        const matched = [lastBubble];
        const checked = new Set();
        
        const findMatches = (bubble) => {
            const key = `${bubble.x},${bubble.y}`;
            if (checked.has(key)) return;
            checked.add(key);
            
            for (let other of this.bubbles) {
                if (other === bubble || checked.has(`${other.x},${other.y}`)) continue;
                
                const dist = Math.sqrt(
                    Math.pow(bubble.x - other.x, 2) + 
                    Math.pow(bubble.y - other.y, 2)
                );
                
                if (dist < CONFIG.bubbleRadius * 2.5 && other.color === bubble.color) {
                    matched.push(other);
                    findMatches(other);
                }
            }
        };
        
        findMatches(lastBubble);
        
        if (matched.length >= 3) {
            AudioSystem.playSFX('pop');
            
            if (matched.length >= 5) {
                AudioSystem.playSFX('combo');
            }
            
            // Animate matched bubbles
            matched.forEach(bubble => {
                this.animations.push({
                    bubble: bubble,
                    type: 'disappear',
                    progress: 0
                });
                
                this.createParticles(bubble.x, bubble.y, bubble.color);
            });
            
            // Remove bubbles
            this.bubbles = this.bubbles.filter(b => !matched.includes(b));
            
            // Update score
            GameState.addScore(matched.length * CONFIG.pointsPerBubble);
            UI.updateDisplay();
        } else {
            GameState.resetCombo();
        }
    },
    
    removeFloatingBubbles() {
        const connected = new Set();
        
        const markConnected = (bubble) => {
            const key = `${bubble.x},${bubble.y}`;
            if (connected.has(key)) return;
            connected.add(key);
            
            for (let other of this.bubbles) {
                const dist = Math.sqrt(
                    Math.pow(bubble.x - other.x, 2) + 
                    Math.pow(bubble.y - other.y, 2)
                );
                
                if (dist < CONFIG.bubbleRadius * 2.5) {
                    markConnected(other);
                }
            }
        };
        
        // Mark connected from top row
        for (let bubble of this.bubbles) {
            if (bubble.row === 0) {
                markConnected(bubble);
            }
        }
        
        // Find floating bubbles
        const floating = this.bubbles.filter(b => !connected.has(`${b.x},${b.y}`));
        
        if (floating.length > 0) {
            floating.forEach(bubble => {
                this.animations.push({
                    bubble: bubble,
                    type: 'fall',
                    progress: 0,
                    velocity: 0
                });
                
                this.createParticles(bubble.x, bubble.y, bubble.color);
            });
            
            this.bubbles = this.bubbles.filter(b => connected.has(`${b.x},${b.y}`));
            
            GameState.addScore(floating.length * CONFIG.pointsPerFloater);
            GameState.coins += floating.length * 2;
            GameState.saveProgress();
            UI.updateDisplay();
        }
    },
    
    updateAnimations() {
        for (let i = this.animations.length - 1; i >= 0; i--) {
            const anim = this.animations[i];
            anim.progress += 0.12;
            
            if (anim.type === 'appear') {
                anim.bubble.scale = Math.min(1, anim.progress * 2.5);
                anim.bubble.opacity = Math.min(1, anim.progress * 2.5);
                
                if (anim.progress >= 0.4) {
                    anim.bubble.scale = 1;
                    anim.bubble.opacity = 1;
                    this.animations.splice(i, 1);
                }
            } else if (anim.type === 'disappear') {
                anim.bubble.scale = Math.max(0, 1 - anim.progress * 2.5);
                anim.bubble.opacity = Math.max(0, 1 - anim.progress * 2);
                
                if (anim.progress >= 1) {
                    this.animations.splice(i, 1);
                }
            } else if (anim.type === 'fall') {
                anim.velocity += 0.6;
                anim.bubble.y += anim.velocity;
                anim.bubble.opacity = Math.max(0, 1 - anim.progress);
                
                if (anim.bubble.y > CONFIG.canvasHeight || anim.progress >= 1) {
                    this.animations.splice(i, 1);
                }
            }
        }
    },
    
    createParticles(x, y, color) {
        // Limit particle creation to reduce lag
        const particleCount = Math.min(15, 10 + Math.floor(Math.random() * 5));
        for (let i = 0; i < particleCount; i++) {
            if (this.particles.length < CONFIG.particlePoolSize) {
                this.particles.push(new Particle(x, y, color));
            }
        }
    },
    
    updateParticles() {
        // Process particles in reverse to allow safe removal
        for (let i = this.particles.length - 1; i >= 0; i--) {
            const p = this.particles[i];
            p.update();
            
            // Remove dead particles
            if (p.life <= 0) {
                this.particles.splice(i, 1);
            }
        }
        
        // Limit total particles for performance
        if (this.particles.length > CONFIG.particlePoolSize) {
            this.particles.length = CONFIG.particlePoolSize;
        }
    },
    
    checkGameOver() {
        // Check if bubbles reached shooter
        for (let bubble of this.bubbles) {
            if (bubble.y >= CONFIG.shooterY - CONFIG.bubbleRadius * 3) {
                this.gameOver(false);
                return;
            }
        }
        
        // Check if all bubbles cleared
        if (this.bubbles.length === 0) {
            this.gameOver(true);
        }
    },
    
    gameOver(won) {
        GameState.isGameOver = true;
        Timer.stop();
        AudioSystem.stopBGM();
        
        if (won) {
            AudioSystem.playSFX('win');
            const coinsEarned = 50 + (GameState.level * 10);
            GameState.coins += coinsEarned;
            UI.showGameOverModal(true, coinsEarned);
        } else {
            AudioSystem.playSFX('lose');
            UI.showGameOverModal(false, 0);
            this.updateHighScores();
        }
        
        GameState.saveProgress();
        UI.updateCoinsDisplay();
    },
    
    updateHighScores() {
        GameState.highScores.push({
            score: GameState.score,
            level: GameState.level,
            time: GameState.timeElapsed
        });
        
        GameState.highScores.sort((a, b) => b.score - a.score);
        GameState.highScores = GameState.highScores.slice(0, 10);
        GameState.saveProgress();
    },
    
    draw() {
        // Clear canvas with gradient background
        const gradient = this.ctx.createLinearGradient(0, 0, 0, CONFIG.canvasHeight);
        gradient.addColorStop(0, '#0d2233');
        gradient.addColorStop(0.5, '#1a4d7a');
        gradient.addColorStop(1, '#0d4455');
        this.ctx.fillStyle = gradient;
        this.ctx.fillRect(0, 0, CONFIG.canvasWidth, CONFIG.canvasHeight);
        
        // Draw subtle animated background
        this.drawBackgroundAnimation();
        
        // Draw bubbles (optimized)
        this.bubbles.forEach(bubble => bubble.draw(this.ctx));
        
        // Draw active bubble
        if (this.activeBubble) {
            const activeBubbleObj = new Bubble(
                this.activeBubble.x,
                this.activeBubble.y,
                this.activeBubble.color,
                0, 0
            );
            activeBubbleObj.draw(this.ctx);
        }
        
        // Draw particles
        this.particles.forEach(p => p.draw(this.ctx));
        
        // Draw shooter
        this.shooter.draw(this.ctx);
        
        // Draw aim line
        if (!this.activeBubble && this.shooter.currentBubble) {
            this.drawAimLine();
        }
        
        // Draw next bubble preview
        if (this.shooter.nextBubble) {
            this.ctx.font = 'bold 14px Arial';
            this.ctx.fillStyle = '#00d4ff';
            this.ctx.textAlign = 'center';
            this.ctx.fillText('NEXT', CONFIG.canvasWidth - 60, 30);
            
            const nextBubble = new Bubble(
                CONFIG.canvasWidth - 60, 60,
                this.shooter.nextBubble.color, 0, 0
            );
            nextBubble.scale = 0.75;
            nextBubble.draw(this.ctx);
        }
    },
    
    drawBackgroundAnimation() {
        // Draw subtle animated circles instead of grid
        const time = Date.now() * 0.0001;
        this.ctx.globalAlpha = 0.08;
        
        for (let i = 0; i < 3; i++) {
            const radius = 150 + Math.sin(time + i) * 50;
            this.ctx.strokeStyle = '#00d4ff';
            this.ctx.lineWidth = 1;
            this.ctx.beginPath();
            this.ctx.arc(CONFIG.canvasWidth / 2, CONFIG.canvasHeight / 2, radius, 0, Math.PI * 2);
            this.ctx.stroke();
        }
        
        this.ctx.globalAlpha = 1;
    },
    
    drawAimLine() {
        this.ctx.strokeStyle = 'rgba(0, 212, 255, 0.4)';
        this.ctx.lineWidth = 2;
        this.ctx.setLineDash([5, 5]);
        
        this.ctx.beginPath();
        this.ctx.moveTo(this.shooter.x, this.shooter.y);
        
        const lineLength = 300;
        const endX = this.shooter.x + Math.cos(this.shooter.angle) * lineLength;
        const endY = this.shooter.y + Math.sin(this.shooter.angle) * lineLength;
        
        this.ctx.lineTo(endX, endY);
        this.ctx.stroke();
        
        this.ctx.setLineDash([]);
    },
    
    loop() {
        if (GameState.currentScreen !== 'game') return;
        
        if (!GameState.isPaused && !GameState.isGameOver) {
            this.update();
            this.draw();
        } else if (GameState.isPaused) {
            this.draw();
        }
        
        requestAnimationFrame(() => this.loop());
    }
};

// =====================================================
// TIMER SYSTEM
// =====================================================
const Timer = {
    interval: null,
    
    start() {
        this.stop();
        GameState.timeElapsed = 0;
        
        this.interval = setInterval(() => {
            if (!GameState.isPaused) {
                GameState.timeElapsed++;
                this.updateDisplay();
            }
        }, 1000);
    },
    
    stop() {
        if (this.interval) {
            clearInterval(this.interval);
            this.interval = null;
        }
    },
    
    updateDisplay() {
        const minutes = Math.floor(GameState.timeElapsed / 60);
        const seconds = GameState.timeElapsed % 60;
        document.getElementById('timerDisplay').textContent = 
            `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    }
};

// =====================================================
// UI MANAGEMENT
// =====================================================
const UI = {
    currentScreen: 'mainMenu',
    
    showScreen(screenName) {
        const screens = document.querySelectorAll('.screen');
        screens.forEach(s => s.classList.remove('active'));
        
        const screen = document.getElementById(screenName + 'Screen');
        if (screen) {
            screen.classList.add('active');
            this.currentScreen = screenName;
            GameState.currentScreen = screenName;
        } else if (screenName === 'mainMenu') {
            document.getElementById('mainMenu').classList.add('active');
            this.currentScreen = 'mainMenu';
            GameState.currentScreen = 'mainMenu';
        }
        
        if (screenName === 'game') {
            Game.start();
        } else if (screenName === 'leaderboard') {
            this.displayLeaderboard();
        } else if (screenName === 'skins') {
            this.displaySkins();
        } else {
            AudioSystem.stopBGM();
        }
    },
    
    updateDisplay() {
        document.getElementById('levelDisplay').textContent = GameState.level;
        document.getElementById('scoreDisplay').textContent = GameState.score;
        document.getElementById('gameCoins').textContent = GameState.coins;
        document.getElementById('hintCount').textContent = GameState.hintsRemaining;
        this.updateCoinsDisplay();
    },
    
    updateCoinsDisplay() {
        document.getElementById('menuCoins').textContent = GameState.coins;
        const skinsCoins = document.getElementById('skinsCoins');
        if (skinsCoins) {
            skinsCoins.textContent = GameState.coins;
        }
    },
    
    updateMusicButton() {
        const menuBtn = document.getElementById('menuMusicBtn');
        const gameBtn = document.getElementById('musicBtn');
        
        if (menuBtn) {
            menuBtn.textContent = GameState.musicEnabled ? '🔊 MUSIC ON' : '🔇 MUSIC OFF';
        }
        if (gameBtn) {
            gameBtn.textContent = GameState.musicEnabled ? '🔊 MUSIC' : '🔇 MUSIC';
        }
    },
    
    showGameOverModal(won, coinsEarned) {
        const modal = document.getElementById('gameOverModal');
        const title = document.getElementById('gameOverTitle');
        const nextBtn = document.getElementById('nextLevelBtn');
        const restartBtn = document.getElementById('restartFromGameOver');
        
        if (won) {
            title.textContent = 'LEVEL COMPLETE!';
            document.getElementById('coinsEarned').textContent = coinsEarned;
            nextBtn.style.display = 'block';
            restartBtn.textContent = 'RETRY LEVEL';
        } else {
            title.textContent = 'GAME OVER!';
            document.getElementById('coinsEarned').textContent = 0;
            nextBtn.style.display = 'none';
            restartBtn.textContent = 'RETRY';
        }
        
        document.getElementById('finalScore').textContent = GameState.score;
        document.getElementById('finalTime').textContent = 
            document.getElementById('timerDisplay').textContent;
        
        modal.classList.add('active');
    },
    
    closeGameOverModal() {
        document.getElementById('gameOverModal').classList.remove('active');
    },
    
    displayLeaderboard() {
        const list = document.getElementById('leaderboardList');
        list.innerHTML = '';
        
        if (GameState.highScores.length === 0) {
            list.innerHTML = '<p style="text-align: center; color: #8b7355; padding: 40px;">No scores yet. Play to set a record!</p>';
            return;
        }
        
        GameState.highScores.forEach((score, index) => {
            const entry = document.createElement('div');
            entry.className = 'leaderboard-entry' + (index < 3 ? ' top3' : '');
            
            const minutes = Math.floor(score.time / 60);
            const seconds = score.time % 60;
            const timeStr = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
            
            entry.innerHTML = `
                <span class="leaderboard-rank">#${index + 1}</span>
                <span class="leaderboard-score">Score: ${score.score} | Level: ${score.level} | Time: ${timeStr}</span>
            `;
            
            list.appendChild(entry);
        });
    },
    
    displaySkins() {
        const grid = document.getElementById('skinsGrid');
        grid.innerHTML = '';
        
        document.getElementById('skinsCoins').textContent = GameState.coins;
        
        SKINS.forEach((skin, index) => {
            const item = document.createElement('div');
            item.className = 'skin-item';
            
            const isUnlocked = GameState.unlockedSkins.includes(index);
            const isSelected = GameState.currentSkin === index;
            const hasEnoughCoins = GameState.coins >= skin.cost;
            
            if (isSelected) item.classList.add('selected');
            if (!isUnlocked && !hasEnoughCoins) item.classList.add('locked');
            
            item.innerHTML = `
                <div class="skin-preview">${skin.emoji}</div>
                <div class="skin-name">${skin.name}</div>
                ${isUnlocked 
                    ? '<div class="skin-unlocked">✓ UNLOCKED</div>' 
                    : hasEnoughCoins
                        ? `<div class="skin-cost">${skin.cost} 🪙</div>`
                        : `<div class="skin-cost">🔒 ${skin.cost} 🪙</div>`
                }
            `;
            
            item.addEventListener('click', () => this.selectSkin(index));
            grid.appendChild(item);
        });
    },
    
    selectSkin(index) {
        const skin = SKINS[index];
        const isUnlocked = GameState.unlockedSkins.includes(index);
        const hasEnoughCoins = GameState.coins >= skin.cost;
        
        if (isUnlocked) {
            GameState.currentSkin = index;
            GameState.saveProgress();
            AudioSystem.playSFX('click');
            this.displaySkins();
        } else if (hasEnoughCoins) {
            NotificationSystem.confirm(`Unlock ${skin.name} for ${skin.cost} coins?`, (confirmed) => {
                if (confirmed) {
                    GameState.coins -= skin.cost;
                    GameState.unlockedSkins.push(index);
                    GameState.currentSkin = index;
                    GameState.saveProgress();
                    AudioSystem.playSFX('win');
                    this.updateCoinsDisplay();
                    this.displaySkins();
                }
            });
        } else {
            NotificationSystem.alert(`Not enough coins! You need ${skin.cost - GameState.coins} more coins.`);
        }
    }
};

// =====================================================
// HINTS SYSTEM
// =====================================================
const Hints = {
    use() {
        if (GameState.hintsRemaining <= 0) {
            NotificationSystem.alert('No hints remaining!');
            return;
        }
        
        if (Game.activeBubble) return;
        
        // Find best match
        let bestMatch = null;
        let maxMatches = 0;
        
        for (let bubble of Game.bubbles) {
            if (bubble.color === Game.shooter.currentBubble.color) {
                let count = 1;
                for (let other of Game.bubbles) {
                    if (other === bubble) continue;
                    const dist = Math.sqrt(
                        Math.pow(bubble.x - other.x, 2) + 
                        Math.pow(bubble.y - other.y, 2)
                    );
                    if (dist < CONFIG.bubbleRadius * 2.5 && bubble.color === other.color) {
                        count++;
                    }
                }
                if (count > maxMatches) {
                    maxMatches = count;
                    bestMatch = bubble;
                }
            }
        }
        
        if (bestMatch) {
            AudioSystem.playSFX('hint');
            
            const originalColor = bestMatch.color;
            let flashCount = 0;
            const flashInterval = setInterval(() => {
                bestMatch.color = flashCount % 2 === 0 ? '#ffffff' : originalColor;
                flashCount++;
                if (flashCount >= 6) {
                    clearInterval(flashInterval);
                    bestMatch.color = originalColor;
                }
            }, 200);
            
            GameState.hintsRemaining--;
            UI.updateDisplay();
        } else {
            NotificationSystem.alert('No matching bubbles found!');
        }
    }
};

// =====================================================
// EVENT LISTENERS SETUP
// =====================================================
function setupEventListeners() {
    // Main Menu
    document.getElementById('playBtn').addEventListener('click', () => {
        AudioSystem.playSFX('click');
        GameState.level = 1;
        GameState.score = 0;
        UI.showScreen('game');
    });
    
    document.getElementById('leaderboardBtn').addEventListener('click', () => {
        AudioSystem.playSFX('click');
        UI.showScreen('leaderboard');
    });
    
    document.getElementById('skinsBtn').addEventListener('click', () => {
        AudioSystem.playSFX('click');
        UI.showScreen('skins');
    });
    
    document.getElementById('menuMusicBtn').addEventListener('click', () => {
        GameState.musicEnabled = !GameState.musicEnabled;
        GameState.saveProgress();
        AudioSystem.playSFX('click');
        
        if (!GameState.musicEnabled) {
            AudioSystem.stopBGM();
        }
        
        UI.updateMusicButton();
    });
    
    // Game Controls
    document.getElementById('hintBtn').addEventListener('click', () => Hints.use());
    
    document.getElementById('pauseBtn').addEventListener('click', () => {
        GameState.isPaused = !GameState.isPaused;
        if (GameState.isPaused) {
            document.getElementById('pauseModal').classList.add('active');
        } else {
            document.getElementById('pauseModal').classList.remove('active');
        }
    });
    
    document.getElementById('restartBtn').addEventListener('click', () => {
        Timer.stop();
        GameState.timeElapsed = 0;
        Game.start();
    });
    
    document.getElementById('musicBtn').addEventListener('click', () => {
        GameState.musicEnabled = !GameState.musicEnabled;
        GameState.saveProgress();
        AudioSystem.playSFX('click');
        
        if (!GameState.musicEnabled) {
            AudioSystem.stopBGM();
        } else if (!GameState.isPaused && !GameState.isGameOver) {
            AudioSystem.playBGM();
        }
        
        UI.updateMusicButton();
    });
    
    document.getElementById('menuBtn').addEventListener('click', () => {
        Timer.stop();
        AudioSystem.stopBGM();
        UI.showScreen('mainMenu');
    });
    
    // Pause Modal
    document.getElementById('resumeBtn').addEventListener('click', () => {
        GameState.isPaused = false;
        document.getElementById('pauseModal').classList.remove('active');
    });
    
    document.getElementById('restartFromPause').addEventListener('click', () => {
        GameState.isPaused = false;
        document.getElementById('pauseModal').classList.remove('active');
        Timer.stop();
        GameState.timeElapsed = 0;
        Game.start();
    });
    
    document.getElementById('menuFromPause').addEventListener('click', () => {
        GameState.isPaused = false;
        document.getElementById('pauseModal').classList.remove('active');
        Timer.stop();
        UI.showScreen('mainMenu');
    });
    
    // Game Over Modal
    document.getElementById('nextLevelBtn').addEventListener('click', () => {
        GameState.level++;
        UI.closeGameOverModal();
        Timer.stop();
        GameState.timeElapsed = 0;
        Game.start();
    });
    
    document.getElementById('restartFromGameOver').addEventListener('click', () => {
        UI.closeGameOverModal();
        GameState.score = 0;
        GameState.level = 1;
        Timer.stop();
        GameState.timeElapsed = 0;
        Game.start();
    });
    
    document.getElementById('menuFromGameOver').addEventListener('click', () => {
        UI.closeGameOverModal();
        UI.showScreen('mainMenu');
    });
    
    // Leaderboard
    document.getElementById('backFromLeaderboard').addEventListener('click', () => {
        UI.showScreen('mainMenu');
    });
    
    // Skins
    document.getElementById('backFromSkins').addEventListener('click', () => {
        UI.showScreen('mainMenu');
    });
}

// =====================================================
// INITIALIZATION
// =====================================================
window.addEventListener('load', () => {
    GameState.init();
    AudioSystem.init();
    Game.init();
    setupEventListeners();
    UI.updateCoinsDisplay();
    UI.updateMusicButton();
    UI.showScreen('mainMenu');
});
                