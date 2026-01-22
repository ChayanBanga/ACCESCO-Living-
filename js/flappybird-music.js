// Music Player for Flappy Bird
const musicPlayerData = {
    songs: [
        { title: "Ambient Vibes", duration: "3:45" },
        { title: "Retro Game", duration: "4:12" },
        { title: "Electronic Dream", duration: "3:30" },
        { title: "Chillwave", duration: "3:58" },
        { title: "Synth Wave", duration: "4:05" },
        { title: "Digital Age", duration: "3:22" }
    ]
};

let currentSong = 0;
let isPlaying = false;

const musicPlayer = {
    init() {
        this.setupEventListeners();
        this.updateDisplay();
    },
    
    setupEventListeners() {
        const playBtn = document.getElementById('playBtn');
        const pauseBtn = document.getElementById('pauseBtn');
        const stopBtn = document.getElementById('stopBtn');
        const prevBtn = document.getElementById('prevBtn');
        const nextBtn = document.getElementById('nextBtn');
        const searchInput = document.getElementById('searchInput');
        const volumeSlider = document.getElementById('volumeSlider');
        
        if (playBtn) playBtn.addEventListener('click', () => this.play());
        if (pauseBtn) pauseBtn.addEventListener('click', () => this.pause());
        if (stopBtn) stopBtn.addEventListener('click', () => this.stop());
        if (prevBtn) prevBtn.addEventListener('click', () => this.previous());
        if (nextBtn) nextBtn.addEventListener('click', () => this.next());
        if (searchInput) searchInput.addEventListener('input', () => this.search());
        if (volumeSlider) volumeSlider.addEventListener('input', () => this.setVolume());
    },
    
    play() {
        isPlaying = true;
        this.updateDisplay();
        const playBtn = document.getElementById('playBtn');
        if (playBtn) playBtn.style.display = 'none';
        const pauseBtn = document.getElementById('pauseBtn');
        if (pauseBtn) pauseBtn.style.display = 'inline';
    },
    
    pause() {
        isPlaying = false;
        this.updateDisplay();
        const playBtn = document.getElementById('playBtn');
        if (playBtn) playBtn.style.display = 'inline';
        const pauseBtn = document.getElementById('pauseBtn');
        if (pauseBtn) pauseBtn.style.display = 'none';
    },
    
    stop() {
        isPlaying = false;
        currentSong = 0;
        this.updateDisplay();
        const playBtn = document.getElementById('playBtn');
        if (playBtn) playBtn.style.display = 'inline';
        const pauseBtn = document.getElementById('pauseBtn');
        if (pauseBtn) pauseBtn.style.display = 'none';
    },
    
    next() {
        currentSong = (currentSong + 1) % musicPlayerData.songs.length;
        this.updateDisplay();
    },
    
    previous() {
        currentSong = (currentSong - 1 + musicPlayerData.songs.length) % musicPlayerData.songs.length;
        this.updateDisplay();
    },
    
    search() {
        const searchInput = document.getElementById('searchInput');
        const query = searchInput ? searchInput.value.toLowerCase() : '';
        const filtered = musicPlayerData.songs.filter(song => 
            song.title.toLowerCase().includes(query)
        );
        this.renderPlaylist(filtered);
    },
    
    setVolume() {
        const volumeSlider = document.getElementById('volumeSlider');
        const volumeValue = document.getElementById('volumeValue');
        if (volumeSlider && volumeValue) {
            volumeValue.textContent = volumeSlider.value + '%';
        }
    },
    
    updateDisplay() {
        const currentSongDisplay = document.getElementById('currentSong');
        const currentTime = document.getElementById('currentTime');
        const song = musicPlayerData.songs[currentSong];
        
        if (currentSongDisplay) {
            currentSongDisplay.textContent = `${song.title} (${isPlaying ? 'Playing' : 'Paused'})`;
        }
        if (currentTime) {
            currentTime.textContent = `${currentSong + 1}/${musicPlayerData.songs.length}`;
        }
    },
    
    renderPlaylist(songs = musicPlayerData.songs) {
        const playlist = document.getElementById('playlist');
        if (!playlist) return;
        
        playlist.innerHTML = songs.map((song, index) => `
            <div class="playlist-item" onclick="musicPlayer.playSong(${index})">
                <span>${song.title}</span>
                <span>${song.duration}</span>
            </div>
        `).join('');
    },
    
    playSong(index) {
        currentSong = index;
        this.play();
    }
};

// Initialize music player when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => musicPlayer.init());
} else {
    musicPlayer.init();
}
