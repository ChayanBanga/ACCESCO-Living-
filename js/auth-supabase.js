/* ======================================================
   SUPABASE SETUP
====================================================== */
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";

const supabaseUrl = "https://nfdrnbikwzfmijrqmoqt.supabase.co";
const supabaseKey = "sb_publishable_dVvOYAqamp2BGoI8zvyB5g_NfCSkQ6b";
const supabase = createClient(supabaseUrl, supabaseKey);

/* ======================================================
   DYNAMIC BLOG FETCH (DISABLED FOR HARDCODED CONTENT)
====================================================== */
/* async function fetchHomeBlogs() {
    const blogContainer = document.getElementById('dynamicBlogGrid');
    try {
        const { data: blogs, error } = await supabase
            .from('blogs')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(3);

        if (error) throw error;

        if (blogs && blogs.length > 0) {
            blogContainer.innerHTML = blogs.map(post => {
                const dateStr = new Date(post.created_at).toLocaleDateString('en-IN', { 
                    day: 'numeric', 
                    month: 'short', 
                    year: 'numeric' 
                });
                return `
                <article class="blog-card">
                    <div class="blog-img">
                        <span class="blog-tag">${post.category || 'Lifestyle'}</span>
                        <img src="${post.image_url || 'https://images.unsplash.com/photo-1499750310107-5fef28a66643?w=800'}" alt="${post.title}">
                    </div>
                    <div class="blog-content">
                        <div class="blog-date"><i class="ri-calendar-line"></i> ${dateStr}</div>
                        <h4>${post.title}</h4>
                        <p>${post.content.substring(0, 100)}...</p>
                        <a href="BLOGS_PAGE/blogs.html" class="blog-link">Read Article <i class="ri-arrow-right-line"></i></a>
                    </div>
                </article>`;
            }).join('');
        } else {
            blogContainer.innerHTML = '<p style="color: var(--muted);">No current highlights found.</p>';
        }
    } catch (err) {
        console.error("Home blog fetch failed:", err);
        blogContainer.innerHTML = '<p style="color: var(--muted);">Unable to load latest insights.</p>';
    }
}
window.addEventListener('DOMContentLoaded', fetchHomeBlogs);
*/

/* ======================================================
   DOM ELEMENTS (AUTH)
====================================================== */
const loginOverlay = document.getElementById("loginOverlay");
const navLoginBtn = document.getElementById("navLoginBtn");
const navProfileWrapper = document.getElementById("navProfileWrapper");
const navProfileImg = document.getElementById("navProfileImg");
const profilePopup = document.getElementById("profilePopup");

/* ======================================================
   UI HELPERS (AUTH)
====================================================== */
function showLoggedInUI(user) {
  if (navLoginBtn) navLoginBtn.style.display = "none";

  if (navProfileWrapper && navProfileImg) {
    navProfileImg.src =
      user.user_metadata?.avatar_url || "images/accesco.png";
    navProfileWrapper.style.display = "block";
  }

  if (loginOverlay) loginOverlay.style.display = "none";
}

function showLoggedOutUI() {
  if (navProfileWrapper) navProfileWrapper.style.display = "none";
  if (navLoginBtn) navLoginBtn.style.display = "inline-flex";
  if (profilePopup) profilePopup.style.display = "none";
}

/* ======================================================
   SESSION CHECK (ON PAGE LOAD)
====================================================== */
try {
  const { data } = await supabase.auth.getSession();

  if (data?.session?.user) {
    showLoggedInUI(data.session.user);
  } else {
    showLoggedOutUI();
  }
} catch (err) {
  console.warn("Auth check failed:", err);
  showLoggedOutUI();
}

/* ======================================================
   AUTH STATE CHANGE LISTENER
====================================================== */
supabase.auth.onAuthStateChange((event, session) => {
  if (event === "SIGNED_IN" && session?.user) {
    showLoggedInUI(session.user);
  }

  if (event === "SIGNED_OUT") {
    showLoggedOutUI();
  }
});

/* ======================================================
   EXPOSE FUNCTIONS TO HTML (MODULE SAFE)
====================================================== */
window.openLoginModal = function () {
  if (loginOverlay) loginOverlay.style.display = "flex";
};

window.closeLoginModal = function () {
  if (loginOverlay) loginOverlay.style.display = "none";
};

window.toggleProfilePopup = function () {
  if (!profilePopup) return;

  profilePopup.style.display =
    profilePopup.style.display === "block" ? "none" : "block";
};

window.logoutUser = async function () {
  await supabase.auth.signOut();
  showLoggedOutUI();
};

/* ======================================================
   CLOSE PROFILE POPUP ON OUTSIDE CLICK
====================================================== */
document.addEventListener("click", (e) => {
  if (
    navProfileWrapper &&
    profilePopup &&
    !navProfileWrapper.contains(e.target)
  ) {
    profilePopup.style.display = "none";
  }
});
