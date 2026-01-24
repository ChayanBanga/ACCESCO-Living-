let chart;
function inr(v) { return "₹" + Math.round(v).toLocaleString("en-IN"); }

async function generate() {
    const payload = {
        income: +document.getElementById('income').value,
        rent: +document.getElementById('rent').value,
        cost_index: +document.getElementById('cost_index').value,
        family_members: +document.getElementById('family_members').value
    };

    try {
        const res = await fetch("/predict", {
            method: "POST",
            headers: {"Content-Type": "application/json"},
            body: JSON.stringify(payload)
        });
        const d = await res.json();
        
        // Save transport value for Emergency Fund first
        const transportVal = d.transport || 0;
        const travelVal = d.travel || 0;

        // 1. Set Emergency Fund (using the original logic)
        d.emergency_fund = transportVal;

        // 2. Create the combined "Travel + Transport" label
        d['travel_and_transport'] = travelVal + transportVal;

        // 3. Clean up the individual transport/travel keys for the table display
        delete d.transport;
        delete d.travel;

        // Needs calculation
        const needsVal = payload.rent + (d.grocery_and_essentials || 0) + (d.education || 0) + (d.healthcare || 0) + (d.emergency_fund || 0);
        
        // Wants calculation (using the combined field)
        const wantsVal = (d.travel_and_transport || 0) + (d.entertainment || 0);

        document.getElementById('needs').textContent = inr(needsVal);
        document.getElementById('wants').textContent = inr(wantsVal);
        document.getElementById('savings').textContent = inr(d.savings || 0);

        const table = document.getElementById('table');
        table.innerHTML = "";
        Object.entries(d).forEach(([k, v]) => {
            table.innerHTML += `<tr><td>${k.replace(/_/g, " ")}</td><td>${inr(v)}</td></tr>`;
        });

        const ctx = document.getElementById('chart').getContext('2d');
        if (chart) chart.destroy();
        chart = new Chart(ctx, {
            type: "doughnut",
            data: {
                labels: ["Needs", "Wants", "Savings"],
                datasets: [{
                    data: [needsVal, wantsVal, d.savings || 0],
                    backgroundColor: ["rgb(112,4,87)", "rgba(112,4,87,0.6)", "rgba(112,4,87,0.35)"]
                }]
            },
            options: { cutout: "70%", plugins: { legend: { position: "bottom" } } }
        });
        document.getElementById("result").classList.remove("hidden");
    } catch (e) { console.error(e); }
}
