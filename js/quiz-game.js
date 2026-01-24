import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";
const supabaseUrl = "https://nfdrnbikwzfmijrqmoqt.supabase.co";
const supabaseKey = "sb_publishable_dVvOYAqamp2BGoI8zvyB5g_NfCSkQ6b";
const supabase = createClient(supabaseUrl, supabaseKey);

let selectedFile = null, currentFilter = 'All', cachedBlogs = [], activePostId = null, imgSourceMode = 'local';

// Apply saved theme on load
const savedTheme = localStorage.getItem('accesco_theme') || 'light';
document.documentElement.setAttribute('data-theme', savedTheme);
document.addEventListener('DOMContentLoaded', () => {
    const icon = document.getElementById('themeToggle').querySelector('i');
    if (icon) icon.className = savedTheme === 'light' ? 'ri-moon-line' : 'ri-sun-line';
});

window.toggleTheme = () => {
    const current = document.documentElement.getAttribute('data-theme');
    const next = current === 'light' ? 'dark' : 'light';
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('accesco_theme', next);
    document.getElementById('themeToggle').querySelector('i').className = next === 'light' ? 'ri-moon-line' : 'ri-sun-line';
};

window.switchImgTab = (mode) => {
    imgSourceMode = mode;
    document.getElementById('tabLocal').classList.toggle('active', mode === 'local');
    document.getElementById('tabLink').classList.toggle('active', mode === 'link');
    document.getElementById('uiLocal').style.display = mode === 'local' ? 'block' : 'none';
    document.getElementById('uiLink').style.display = mode === 'link' ? 'block' : 'none';
    document.getElementById('writePreview').style.display = 'none';
    selectedFile = null;
};

window.previewFile = (input) => {
    selectedFile = input.files[0];
    if (selectedFile) {
        const reader = new FileReader();
        reader.onload = (e) => {
            document.getElementById('writePreview').src = e.target.result;
            document.getElementById('writePreview').style.display = 'block';
        };
        reader.readAsDataURL(selectedFile);
    }
};

window.previewUrl = (url) => { if(url.startsWith('http')) { document.getElementById('writePreview').src = url; document.getElementById('writePreview').style.display = 'block'; } };

window.onload = async () => loadBlogs(true);

async function loadBlogs(forceFetch = false) {
    if (forceFetch || cachedBlogs.length === 0) {
        const { data, error } = await supabase.from('blogs').select('*, blog_likes(count), blog_comments(count)').order('created_at', { ascending: false });
        if (!error) cachedBlogs = data;
    }
    const displayed = currentFilter === 'All' ? cachedBlogs : cachedBlogs.filter(b => b.category === currentFilter);
    renderBlogs(displayed);
}

function renderBlogs(blogs) {
    document.getElementById('blogContainer').innerHTML = blogs.map(post => {
        const dateStr = new Date(post.created_at).toLocaleDateString('en-IN', { day:'numeric', month: 'long', year: 'numeric' });
        return `
        <div class="card">
            <div class="card-img-wrapper" onclick="openStory('${post.id}')"><img src="${post.image_url || 'https://images.unsplash.com/photo-1499750310107-5fef28a66643?w=800'}" alt="Cover"></div>
            <div class="card-meta"><span class="category">${post.category}</span><span class="date">— ${dateStr}</span></div>
            <h3 class="card-title" onclick="openStory('${post.id}')">${post.title}</h3>
            <p class="card-excerpt">${post.content.substring(0, 140)}...</p>
            <div class="card-actions-row">
                <div class="stats-group"><span><i class="ri-heart-line"></i> ${post.blog_likes[0]?.count || 0}</span><span><i class="ri-chat-3-line"></i> ${post.blog_comments[0]?.count || 0}</span></div>
                <i class="ri-share-line share-icon-btn" onclick="handleCardShare('${post.id}', '${post.title}')"></i>
            </div>
            <button class="btn-read" onclick="openStory('${post.id}')">Read Full Story</button>
        </div>`;
    }).join('');
}

window.publishPost = async () => {
    const btn = document.getElementById('publishBtn');
    const title = document.getElementById('postTitle').value.trim();
    const content = document.getElementById('postContent').value.trim();
    if (!title || !content) return alert("Headline and story are required.");
    btn.disabled = true; btn.innerText = "Synchronizing...";
    let image_url = document.getElementById('imageUrlInput').value.trim();
    try {
        if (imgSourceMode === 'local' && selectedFile) {
            const name = `${Date.now()}-${selectedFile.name.replace(/[^a-zA-Z0-9.]/g, '_')}`;
            const { data: stData, error: stError } = await supabase.storage.from('blog-images').upload(name, selectedFile);
            if (stError) {
                const reader = new FileReader();
                image_url = await new Promise(res => { reader.onload = e => res(e.target.result); reader.readAsDataURL(selectedFile); });
            } else { image_url = supabase.storage.from('blog-images').getPublicUrl(name).data.publicUrl; }
        }
        const { error: dbError } = await supabase.from('blogs').insert({ 
            title, content, category: document.getElementById('postCategory').value, image_url, author_name: 'Explorer' 
        });
        if (dbError) throw dbError;
        closeWriteModal(); await loadBlogs(true);
    } catch (e) { alert("Publication failed. Check Supabase connection."); }
    btn.disabled = false; btn.innerText = "Publish to ACCESCO";
};

window.openStory = async (id) => {
    activePostId = id; const story = cachedBlogs.find(b => b.id == id); if (!story) return;
    const { data: comments } = await supabase.from('blog_comments').select('*').eq('blog_id', id).order('created_at', { ascending: false });
    const dateStr = new Date(story.created_at).toLocaleDateString('en-IN', { day:'numeric', month: 'long', year: 'numeric' });
    document.getElementById('readCat').innerText = story.category; document.getElementById('readTitle').innerText = story.title;
    document.getElementById('readHero').src = story.image_url || 'https://images.unsplash.com/photo-1499750310107-5fef28a66643?w=800';
    document.getElementById('readContent').innerText = story.content; document.getElementById('readDate').innerText = dateStr;
    document.getElementById('readLikeCount').innerText = story.blog_likes[0]?.count || 0; document.getElementById('readCommCount').innerText = comments?.length || 0;
    const liked = JSON.parse(localStorage.getItem('accesco_liked') || '[]');
    document.getElementById('readerLikeBtn').classList.toggle('active', liked.includes(id));
    document.getElementById('commentList').innerHTML = (comments || []).map(c => `<div class="comment-item"><span class="user">Explorer</span><div class="text">${c.content}</div></div>`).join('') || '<p style="text-align:center; color:#999;">No discussions yet.</p>';
    document.getElementById('readerOverlay').style.display = 'block'; document.body.style.overflow = 'hidden';
};

window.handleCardShare = (id, title) => { event.stopPropagation(); const url = window.location.href; if (navigator.share) navigator.share({ title, url }); else { alert("Link copied!"); } };
window.handleShareActive = () => handleCardShare(activePostId, document.getElementById('readTitle').innerText);
window.handleReaderLike = async () => { let liked = JSON.parse(localStorage.getItem('accesco_liked') || '[]'); if (liked.includes(activePostId)) return; liked.push(activePostId); localStorage.setItem('accesco_liked', JSON.stringify(liked)); await supabase.from('blog_likes').insert({ blog_id: activePostId }); document.getElementById('readLikeCount').innerText = parseInt(document.getElementById('readLikeCount').innerText) + 1; document.getElementById('readerLikeBtn').classList.add('active'); loadBlogs(true); };
window.submitComment = async () => { const text = document.getElementById('commText').value.trim(); if (!text) return; await supabase.from('blog_comments').insert({ blog_id: activePostId, content: text }); document.getElementById('commText').value = ""; await loadBlogs(true); openStory(activePostId); };
window.filterBlogs = (cat) => { currentFilter = cat; document.getElementById('currentCategory').innerText = cat === 'All' ? "Explore" : cat; document.querySelectorAll('#navLinks li').forEach(li => li.classList.toggle('active', li.getAttribute('data-cat') === cat)); loadBlogs(false); };
window.openWriteModal = () => { document.getElementById('writeOverlay').style.display = 'block'; document.body.style.overflow = 'hidden'; };
window.closeWriteModal = () => { document.getElementById('writeOverlay').style.display = 'none'; document.getElementById('writePreview').style.display = 'none'; selectedFile = null; document.body.style.overflow = 'auto'; };
window.closeReader = () => { document.getElementById('readerOverlay').style.display = 'none'; document.body.style.overflow = 'auto'; };
