const videoData = [
    { title: "About US", cat: "About", dur: "00:26", asset: "assets/video_1.mp4", thumb: "assets/thumbnail_1.jpeg" },
    { title: "Delivery Process Overview", cat: "Riders", dur: "00:25", asset: "assets/video_3.mp4", thumb: "assets/thumbnail_3.jpeg" }
]; 

let filteredVideos = [...videoData];

function renderGrid(data = filteredVideos) {
    const grid = document.getElementById('videoGrid');
    const videoList = Array.isArray(data) ? data : filteredVideos;

    if (videoList.length === 0) {
        grid.innerHTML = `<div class="col-span-full py-20 text-center border-2 border-dashed border-slate-200 rounded-[32px]"><p class="font-poppins text-xl font-800 text-slate-300">No results found</p></div>`;
        return;
    }

    grid.innerHTML = videoList.map(v => `
        <div class="video-card p-4 cursor-pointer" onclick='playVideo(${JSON.stringify(v)})'>
            <div class="video-thumbnail relative mb-6">
                <img src="${v.thumb}" alt="${v.title} thumbnail" loading="lazy" onerror="this.src='https://images.unsplash.com/photo-1611162617474-5b21e879e113?w=800'">
                <div class="absolute inset-0 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity bg-black/20 backdrop-blur-[2px]">
                    <div class="w-14 h-14 bg-white rounded-full flex items-center justify-center shadow-2xl"><i class="ri-play-fill text-2xl ml-1"></i></div>
                </div>
                <div class="absolute bottom-4 right-4 bg-black/80 text-white text-[10px] font-bold px-2 py-1 rounded">${v.dur}</div>
            </div>
            <div class="px-2 pb-2">
                <span class="tag">${v.cat}</span>
                <h3 class="font-poppins text-lg font-800 leading-tight mb-3 mt-3">${v.title}</h3>
                <p class="text-xs text-slate-400 font-medium leading-relaxed line-clamp-2">Internal resource session for global operations teams.</p>
            </div>
        </div>
    `).join('');
}

document.getElementById('searchInput').addEventListener('input', (e) => {
    const query = e.target.value.toLowerCase();
    const results = videoData.filter(v => v.title.toLowerCase().includes(query) || v.cat.toLowerCase().includes(query));
    renderGrid(results);
});

function filterVideos(category) {
    const btns = document.querySelectorAll('.filter-btn');
    btns.forEach(btn => {
        if (btn.innerText === category) {
            btn.classList.add('bg-black', 'text-white');
            btn.classList.remove('bg-white', 'text-slate-900');
        } else {
            btn.classList.remove('bg-black', 'text-white');
            btn.classList.add('bg-white', 'text-slate-900');
        }
    });
    filteredVideos = category === 'All' ? [...videoData] : videoData.filter(v => v.cat === category);
    renderGrid(filteredVideos);
}

function toggleModal(id) {
    const el = document.getElementById(id);
    el.classList.toggle('hidden');
    document.body.style.overflow = el.classList.contains('hidden') ? 'auto' : 'hidden';
    if(id === 'playerModal' && el.classList.contains('hidden')) document.getElementById('mainPlayer').pause();
}

function playVideo(v) {
    document.getElementById('playerTitle').innerText = v.title;
    document.getElementById('playerMeta').innerText = `${v.cat} • ${v.dur}`;
    const player = document.getElementById('mainPlayer');
    player.src = v.asset;
    player.load();
    player.play();
    toggleModal('playerModal');
}

window.onload = () => renderGrid();
