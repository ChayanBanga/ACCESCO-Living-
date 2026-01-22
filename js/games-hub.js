lucide.createIcons();

// 1. SUPABASE CONFIG
const supabaseUrl = "https://nfdrnbikwzfmijrqmoqt.supabase.co";
const supabaseKey = "sb_publishable_dVvOYAqamp2BGoI8zvyB5g_NfCSkQ6b";
const supabaseClient = supabase.createClient(supabaseUrl, supabaseKey);

// 2. WALLET SYNC
async function syncCoins() {
    const { data: { user } } = await supabaseClient.auth.getUser();
    const walletBalance = document.getElementById('wallet-balance');
    const walletStatus = document.getElementById('wallet-status');

    if (!user) return;

    const { data, error } = await supabaseClient
        .from('user_profiles')
        .select('total_rp')
        .eq('id', user.id)
        .single();

    if (data) {
        walletBalance.innerHTML = `${data.total_rp.toLocaleString()} <span class="text-xl">RP</span>`;
        walletStatus.innerText = "Coins Synced Successfully";
    }
}

// 3. NAVIGATION & CATEGORY LOGIC
const navBtns = document.querySelectorAll('.nav-btn');
const tabContents = document.querySelectorAll('.tab-content');
const filterBtns = document.querySelectorAll('.filter-btn');
const gameCards = document.querySelectorAll('.game-card');

navBtns.forEach(btn => {
    btn.addEventListener('click', () => {
        const target = btn.getAttribute('data-target');
        navBtns.forEach(b => b.classList.replace('text-amber-500', 'text-slate-500'));
        btn.classList.replace('text-slate-500', 'text-amber-500');
        tabContents.forEach(c => c.classList.add('hidden-section'));
        document.getElementById(target).classList.remove('hidden-section');
        if(target === 'wallet-section') syncCoins();
        lucide.createIcons();
    });
});

filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
        const filter = btn.getAttribute('data-filter');
        filterBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        gameCards.forEach(card => {
            const cat = card.getAttribute('data-category');
            if (filter === 'all' || cat.includes(filter)) card.classList.remove('hidden');
            else card.classList.add('hidden');
        });
    });
});

syncCoins();
