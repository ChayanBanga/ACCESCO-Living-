const dfMessenger = document.querySelector('df-messenger');

// 1. Listen for the 'df-messenger-opened' event
dfMessenger.addEventListener('df-messenger-opened', () => {
  // 2. Small timeout ensures internal Shadow DOM components are rendered
  setTimeout(() => {
    const chat = dfMessenger.shadowRoot?.querySelector('df-messenger-chat');
    const titlebar = chat?.shadowRoot?.querySelector('df-messenger-titlebar');
    const header = titlebar?.shadowRoot?.querySelector('header');

    if (header && !header.querySelector('.custom-back-btn')) {
      // 3. Create the button
      const backBtn = document.createElement('button');
      backBtn.className = 'custom-back-btn';
      backBtn.innerHTML = '←';
      
      // 4. Match your bright UI theme
      backBtn.style.cssText = `
        background: none;
        border: none;
        font-size: 24px;
        cursor: pointer;
        color: #000000;
        padding: 0 12px 0 4px;
        display: flex;
        align-items: center;
        font-weight: bold;
      `;

      // 5. Close the chat on click
      backBtn.onclick = (e) => {
        e.stopPropagation(); // Prevent titlebar events
        dfMessenger.opened = false;
      };

      // 6. Insert at the very start of the header
      header.prepend(backBtn);
    }
  }, 100);
});
