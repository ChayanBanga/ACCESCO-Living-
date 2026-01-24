// Blog Archive Management
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";

const supabaseUrl = "https://nfdrnbikwzfmijrqmoqt.supabase.co";
const supabaseKey = "sb_publishable_dVvOYAqamp2BGoI8zvyB5g_NfCSkQ6b";
const supabase = createClient(supabaseUrl, supabaseKey);

let cachedBlogs = [], currentFilter = 'All';

const demoArchive = [
    { id: 'm1', title: 'The Architectures of Digital Solitude', category: 'Innovation', content: 'In an era defined by hyper-connectivity, we find ourselves increasingly isolated within the digital silos of our own making...', image_url: 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800', created_at: new Date().toISOString() }
];

const hideLoading = () => {
  const screen = document.getElementById('loadingScreen');
  if(screen) {
      screen.style.opacity = '0';
      setTimeout(() => screen.style.display = 'none', 800);
  }
};

const handleRouting = () => {
    const hash = window.location.hash;
    if (hash && hash.startsWith('#post-')) {
        const postId = hash.replace('#post-', '');
        if (cachedBlogs.length > 0) window.openNarrative(postId, false);
    } else {
        window.closeModals(false);
    }
};

const loadArchive = async () => {
    try {
        const [dbResponse] = await Promise.all([
            supabase.from('blogs').select('*').order('created_at', { ascending: false }),
            new Promise(resolve => setTimeout(resolve, 2000)) 
        ]);

        cachedBlogs = (dbResponse.error || !dbResponse.data || dbResponse.data.length === 0) ? demoArchive : dbResponse.data;
        renderArchive();
        handleRouting(); 
    } catch (err) {
        cachedBlogs = demoArchive;
        renderArchive();
    } finally {
        hideLoading();
    }
};

const renderArchive = () => {
    const filtered = currentFilter === 'All' ? cachedBlogs : cachedBlogs.filter(b => b.category === currentFilter);
    const container = document.getElementById('storyContainer');
    document.getElementById('itemCount').innerText = `${filtered.length} Narratives`;
    
    if (filtered.length === 0) {
        container.innerHTML = "<div style='grid-column:1/-1; text-align:center; padding: 6rem; border: 1px dashed var(--border); border-radius: 30px;'><p style='font-weight:800; opacity:0.4;'>Archive is currently empty.</p></div>";
        return;
    }

    container.innerHTML = filtered.map(post => `
        <article class="story-card" onclick="window.openNarrative('${post.id}')">
            <div class="story-visual">
                <img src="${post.image_url || 'https://images.unsplash.com/photo-1499750310107-5fef28a66643?w=800'}" alt="Cover">
            </div>
            <span class="story-tag">${post.category}</span>
            <h3 class="story-headline">${post.title}</h3>
            <p class="story-summary">${post.content.substring(0, 150)}...</p>
            <button class="btn-action-text">Read Archive Entry</button>
        </article>
    `).join('');
};

window.filterArchive = (cat) => {
    currentFilter = cat;
    document.getElementById('activeCategory').innerText = cat === 'All' ? 'Latest Collection' : `${cat} Focus`;
    document.querySelectorAll('#mainNav li').forEach(li => li.classList.toggle('active', li.getAttribute('data-cat') === cat));
    renderArchive();
};

window.openNarrative = (id, updateHash = true) => {
    const post = cachedBlogs.find(b => b.id == id);
    if (!post) return;
    if (updateHash) window.location.hash = `post-${id}`;

    document.getElementById('readTag').innerText = post.category;
    document.getElementById('readH1').innerText = post.title;
    document.getElementById('readContent').innerText = post.content;
    
    const hero = document.getElementById('readImg');
    if (post.image_url) { hero.src = post.image_url; hero.style.display = 'block'; } 
    else { hero.style.display = 'none'; }
    
    document.getElementById('readerOverlay').style.display = 'block';
    document.body.style.overflow = 'hidden';
};

// Image Preview
window.previewLocalImage = (event) => {
    const reader = new FileReader();
    const file = event.target.files[0];
    reader.onload = () => {
        const preview = document.getElementById('localImgPreview');
        const placeholder = document.getElementById('previewPlaceholder');
        preview.src = reader.result;
        preview.style.display = 'block';
        placeholder.style.display = 'none';
    };
    if (file) reader.readAsDataURL(file);
};

// Publish Post
window.publishPost = async () => {
    const title = document.getElementById('postTitle').value.trim();
    const content = document.getElementById('postContent').value.trim();
    const category = document.getElementById('postCategory').value;
    const image_url = document.getElementById('localImgPreview').src;

    if (!title || !content) return alert("Please fill in the title and content.");

    const { error } = await supabase.from('blogs').insert([{ 
      title, content, category, 
      image_url: image_url.startsWith('data') ? image_url : 'https://images.unsplash.com/photo-1499750310107-5fef28a66643?w=800', 
      author_name: 'Explorer' 
    }]);

    if (!error) {
        window.closeModals();
        loadArchive();
        document.getElementById('postTitle').value = "";
        document.getElementById('postContent').value = "";
        document.getElementById('localImgPreview').style.display = 'none';
        document.getElementById('previewPlaceholder').style.display = 'block';
    }
};

window.openWriteModal = () => { 
    document.getElementById('writeOverlay').style.display = 'block'; 
    document.body.style.overflow = 'hidden'; 
};

window.closeModals = (clearHash = true) => {
    document.getElementById('writeOverlay').style.display = 'none';
    document.getElementById('readerOverlay').style.display = 'none';
    document.body.style.overflow = 'auto';
    if (clearHash && window.location.hash.includes('post-')) {
        history.pushState("", document.title, window.location.pathname + window.location.search);
    }
};

window.addEventListener('hashchange', handleRouting);
window.addEventListener('load', loadArchive);
