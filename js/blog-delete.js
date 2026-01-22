const API_URL = "http://localhost:5000/api/blogs";
async function loadDeleteList() {
  const res = await fetch(API_URL);
  const blogs = await res.json();
  const container = document.getElementById("delete-list");
  if (!blogs.length) {
    container.innerHTML = '<p class="muted">No blogs found.</p>';
    return;
  }
  container.innerHTML = blogs.map(b => `
    <div class="blog-card" style="margin-bottom:18px;">
      <h3>${b.title}</h3>
      <p>${b.content}</p>
      <button class="danger" style="margin-top:8px;" onclick="deleteBlog('${b.id}')">🗑️ Delete</button>
    </div>
  `).join("");
}
async function deleteBlog(blogId) {
  if (!confirm("Delete this blog? This cannot be undone.")) return;
  const res = await fetch(`${API_URL}/${blogId}`, { method: "DELETE" });
  if (!res.ok) {
    let msg = "Delete failed";
    try { const data = await res.json(); if (data?.error) msg = data.error; } catch {}
    alert(msg); return;
  }
  loadDeleteList();
}
loadDeleteList();
