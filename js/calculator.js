// ⬇️⬇️ PASTE YOUR API KEY HERE ⬇️⬇️
const apiKey = "YOUR_API_KEY_HERE"; 

let distributionChart, breakdownChart;
const apiCache = new Map();

window.onload = () => { initCharts(); };

function showToast(message, type = 'info') {
  const container = document.getElementById('toast-container');
  const toast = document.createElement('div');
  toast.className = 'toast';
  let icon = '<i class="fa-solid fa-circle-info text-white"></i>';
  if (type === 'error') icon = '<i class="fa-solid fa-circle-exclamation"></i>';
  if (type === 'success') icon = '<i class="fa-solid fa-circle-check"></i>';
  toast.innerHTML = `${icon} <span>${message}</span>`;
  container.appendChild(toast);
  setTimeout(() => toast.classList.add('show'), 10);
  setTimeout(() => { toast.classList.remove('show'); setTimeout(()=>toast.remove(),300); }, 3000);
}

function initCharts() {
  const ctx1 = document.getElementById('distributionChart').getContext('2d');
  const ctx2 = document.getElementById('breakdownChart').getContext('2d');
  distributionChart = new Chart(ctx1, {
    type: 'doughnut',
    data: { labels: ['Needs', 'Wants', 'Savings'], datasets: [{ data: [1,1,1], backgroundColor: ['#800000','#b91c1c','#16a34a'], borderWidth:0 }] },
    options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'bottom', labels: { usePointStyle: true, font: { family: 'Inter', weight: 'bold' }, color: '#333' } } }, cutout: '70%' }
  });
  breakdownChart = new Chart(ctx2, {
    type: 'bar',
    data: { labels: ['Rent', 'Groc', 'Trav', 'Fun', 'Save'], datasets: [{ label: '₹', data: [0,0,0,0,0], backgroundColor: '#800000', borderRadius: 6 }] },
    options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: true, grid: { display: false }, ticks: {color:'#666'} }, x: { grid: { display: false }, ticks: {color:'#666'} } }, plugins: { legend: { display: false } } }
  });
}

async function performSmartResearchAndCalc() {
  const income = parseFloat(document.getElementById('incomeInput').value);
  const setupRent = parseFloat(document.getElementById('setupRentInput').value) || 0;
  const city = document.getElementById('cityInput').value;
  const lifeStyle = document.getElementById('lifeStyle').value;
  const members = parseInt(document.getElementById('headCountInput').value) || 1;
  const errEl = document.getElementById('incomeError');

  if(!income || income < 500) {
    errEl.classList.remove('hidden');
    showToast("Income must be at least ₹500", "error");
    return;
  }
  errEl.classList.add('hidden');
  if(!city){ showToast("Please enter a city!", "error"); return; }

  const btn = document.getElementById('generateBtn');
  const origText = btn.innerHTML;
  btn.disabled = true;
  btn.innerHTML = `<i class="fa-solid fa-circle-notch fa-spin"></i> ANALYZING...`;
  document.getElementById('logicStatus').classList.add('hidden');

  // 1. OFFLINE FALLBACK LOGIC
  // We calculate this first so even if API fails, the user gets a result
  const incomePerCapita = income / members;
  let baseFoodCost = lifeStyle === 'frugal' ? 2500 : (lifeStyle === 'luxury' ? 5000 : 3000);
  let scaleFactor = 1;
  if (members > 1) scaleFactor += 0.7;
  if (members > 2) scaleFactor += (members - 2) * 0.6;
  let idealGrocery = Math.floor(baseFoodCost * scaleFactor);

  let baseUtil = lifeStyle === 'frugal' ? 600 : (lifeStyle === 'luxury' ? 2000 : 1000);
  let utilScale = 1 + ((members-1) * 0.3);
  let idealUtility = Math.floor(baseUtil * utilScale);

  let baseTrans = 1500;
  let transScale = members > 2 ? members * 0.8 : members;
  let idealTransport = Math.floor(baseTrans * transScale);

  const disposable = Math.max(0, income - (setupRent > 0 ? setupRent : 0));
  let remaining = disposable - (idealGrocery + idealUtility + idealTransport);
  let shopping = 0, dining = 0, entertainment = 0;

  if (remaining > 0) {
    shopping = Math.floor(remaining * 0.2);
    dining = Math.floor(remaining * 0.2);
    entertainment = Math.floor(remaining * 0.1);
  } else {
    let totalNeeds = idealGrocery + idealUtility + idealTransport;
    let scaleDown = disposable / totalNeeds;
    idealGrocery = Math.floor(idealGrocery * scaleDown);
    idealUtility = Math.floor(idealUtility * scaleDown);
    idealTransport = Math.floor(idealTransport * scaleDown);
  }

  let budget = {
    rent: setupRent > 0 ? setupRent : Math.floor(income * 0.30),
    grocery: idealGrocery,
    transport: idealTransport,
    utility: idealUtility,
    shopping: shopping,
    dining: dining,
    entertainment: entertainment,
    reasoning: `Budget tailored for ${lifeStyle} lifestyle with ${members} member(s).`
  };

  // 2. API CALL
  let aiSuccess = false;
  try {
    if(apiKey && apiKey.length > 10) {
      const rentInstruction = setupRent > 0 ? `Rent is FIXED at ₹${setupRent}.` : `Estimate rent for ${city}.`;
      const prompt = `Act as an Indian financial planner. Create a monthly budget for a family of ${members} in ${city} with Income ₹${income} and lifestyle '${lifeStyle}'. ${rentInstruction}
      CRITICAL INSTRUCTION:
      1. Prioritize Grocery & Utilities.
      2. Ensure total expenses do not exceed ₹${income}.
      3. Return STRICT JSON format only: { "rent": int, "grocery": int, "transport": int, "utility": int, "shopping": int, "dining": int, "entertainment": int, "reasoning": "short sentence" }`;

      const data = await callGeminiJSON(prompt);
      if(data && data.rent !== undefined) {
        budget = data;
        if (setupRent > 0) budget.rent = setupRent;
        aiSuccess = true;
      }
    }
  } catch(e) {
    console.error("AI Failed", e);
  }

  // 3. APPLY RESULTS
  if(!aiSuccess) {
     if(!apiKey || apiKey === "YOUR_API_KEY_HERE") {
         showToast("⚠️ Using offline logic. Add API Key for AI results.", "info");
     } else {
         showToast("⚠️ API Offline. Using calculated estimate.", "error");
     }
  } else {
      showToast("AI Budget Generated!", "success");
  }

  const set = (id, val) => { const el = document.getElementById(id); if(el) el.value = val; };

  set('rentInput', budget.rent);
  set('grocInput', budget.grocery);
  set('transInput', budget.transport);
  set('utilInput', budget.utility);
  set('shopInput', budget.shopping);
  set('dineInput', budget.dining);
  set('hobInput', budget.entertainment);

  const statusEl = document.getElementById('logicStatus');
  statusEl.classList.remove('hidden');
  statusEl.innerHTML = `<strong>${aiSuccess ? 'AI' : 'Standard'} Insight:</strong> ${budget.reasoning}`;

  // Show the results section (This was the bug before!)
  document.getElementById('breakdownCards').classList.remove('hidden');
  document.getElementById('analyzeBtn').classList.remove('hidden');

  autoBalanceInvest();

  btn.disabled = false;
  btn.innerHTML = origText;
}

function autoBalanceInvest() {
  const get = (id) => parseFloat(document.getElementById(id).value)||0;
  const income = parseFloat(document.getElementById('incomeInput').value)||0;

  const rent=get('rentInput'), groc=get('grocInput'), trans=get('transInput'), util=get('utilInput');
  const shop=get('shopInput'), dine=get('dineInput'), hob=get('hobInput');

  const expenses = rent+groc+trans+util+shop+dine+hob;
  const invest = income - expenses;

  const invField = document.getElementById('invInput');
  invField.value = invest;

  invField.className = `w-full text-center text-3xl font-black outline-none bg-transparent ${invest<0 ? 'text-red-600' : 'text-green-600'} inv-large`;

  document.getElementById('needsTotalDisp').innerText = '₹'+(rent+groc+trans+util).toLocaleString();
  document.getElementById('wantsTotalDisp').innerText = '₹'+(shop+dine+hob).toLocaleString();
  document.getElementById('savingsTotalDisp').innerText = '₹'+Math.max(0,invest).toLocaleString();

  distributionChart.data.datasets[0].data = [rent+groc+trans+util, shop+dine+hob, Math.max(0,invest)];
  distributionChart.update();
  breakdownChart.data.datasets[0].data = [rent, groc, trans, shop, Math.max(0,invest)];
  breakdownChart.update();
}

function checkSavingsGoal(){ showToast("Goal planner coming soon!", "info"); }
function getAIAnalysis(){ showToast("AI Audit requires Pro version", "info"); }

// REAL AI CALL FUNCTION
async function callGeminiJSON(prompt) {
  if(apiCache.has(prompt)) return apiCache.get(prompt);

  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=${apiKey}`;
  const payload = {
    contents: [{ parts: [{ text: prompt }] }]
  };

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const data = await response.json();
    const text = data.candidates[0].content.parts[0].text;
    
    // Clean markdown if present
    const jsonStr = text.replace(/```json/g, '').replace(/```/g, '');
    const json = JSON.parse(jsonStr);
    
    apiCache.set(prompt, json);
    return json;
  } catch (error) {
    console.error("Gemini API Error:", error);
    return null;
  }
}
