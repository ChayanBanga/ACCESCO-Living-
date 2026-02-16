from flask import Flask, render_template_string, request
import ollama
import json

app = Flask(__name__)

# HTML Template for the Index Page
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gift Oracle - AI Gift Recommendations</title>
    
    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@400;600&family=Work+Sans:wght@300;400;500;600&family=Roboto:wght@400;500;700&display=swap" rel="stylesheet">
    
    <style>
        :root {
            /* Backgrounds */
            --bg-deep: #120309;
            --bg-wine: #2a0a18;
            --bg-gradient: radial-gradient(circle at 50% -20%, #4a0e25 0%, #120309 80%);
            
            /* Glass Panels */
            --glass-bg: rgba(60, 10, 30, 0.55);
            
            /* Gold Accents (Champagne/Bronze) */
            --gold-base: #c5a059;
            --gold-light: #e0c8a0;
            --gold-dark: #8f7034;
            --gold-metallic: linear-gradient(135deg, #ad8b47, #d4be8d 50%, #ad8b47 100%);
            
            /* Text */
            --txt: #fdfcfd;
            --txt-dim: rgba(253, 252, 253, 0.65);
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Work Sans', sans-serif;
            background: var(--bg-gradient) fixed;
            background-color: var(--bg-deep);
            color: var(--txt);
            min-height: 100vh;
            overflow-x: hidden;
            position: relative;
        }

        /* Gold Dust Canvas */
        #goldDustCanvas {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
            z-index: 1;
        }

        /* Main Container */
        .container {
            position: relative;
            z-index: 10;
            max-width: 1400px;
            margin: 0 auto;
            padding: 40px 20px;
        }

        /* Header */
        .header {
            text-align: center;
            padding: 20px 0 60px;
        }

        .brand {
            font-family: 'Work Sans', sans-serif;
            font-size: 0.7rem;
            font-weight: 500;
            letter-spacing: 0.25em;
            text-transform: uppercase;
            color: var(--gold-light);
            margin-bottom: 20px;
            opacity: 0.8;
        }

        .title {
            font-family: 'Cinzel', serif;
            font-size: 80px;
            font-weight: 600;
            letter-spacing: 0.15em;
            text-transform: uppercase;
            background: var(--gold-metallic);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 20px;
            text-shadow: 0 4px 12px rgba(197, 160, 89, 0.3);
            filter: drop-shadow(0 2px 8px rgba(197, 160, 89, 0.2));
        }

        .subtitle {
            font-family: 'Work Sans', sans-serif;
            font-size: 0.75rem;
            font-weight: 400;
            letter-spacing: 0.2em;
            text-transform: uppercase;
            color: var(--txt-dim);
        }

        /* Search Section - Glassmorphic Panel */
        .search-section {
            max-width: 900px;
            margin: 0 auto 80px;
            background: var(--glass-bg);
            backdrop-filter: blur(16px);
            border-radius: 16px;
            padding: 50px;
            box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
            position: relative;
            overflow: hidden;
        }

        /* Glass Panel Sheen Effect */
        .search-section::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 1px;
            background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
            z-index: 1;
        }

        .search-section::after {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            box-shadow: inset 0 1px 2px rgba(255, 255, 255, 0.1);
            border-radius: 16px;
            pointer-events: none;
        }

        .search-content {
            position: relative;
            z-index: 2;
        }

        .search-title {
            font-family: 'Cinzel', serif;
            font-size: 32px;
            font-weight: 600;
            letter-spacing: 0.1em;
            text-transform: uppercase;
            color: var(--gold-light);
            margin-bottom: 12px;
            text-align: center;
        }

        .search-subtitle {
            font-family: 'Work Sans', sans-serif;
            font-size: 0.7rem;
            font-weight: 400;
            letter-spacing: 0.12em;
            text-transform: uppercase;
            color: var(--gold-light);
            text-align: center;
            margin-bottom: 40px;
            opacity: 0.8;
        }

        /* Search Form */
        .search-form {
            display: flex;
            gap: 20px;
            align-items: stretch;
        }

        /* Input Field */
        .search-input {
            flex: 1;
            font-family: 'Work Sans', sans-serif;
            font-size: 15px;
            font-weight: 400;
            background: rgba(20, 4, 10, 0.4);
            border: 1px solid rgba(197, 160, 89, 0.2);
            border-radius: 8px;
            padding: 18px 24px;
            color: var(--txt);
            transition: all 0.3s ease;
        }

        .search-input::placeholder {
            color: var(--txt-dim);
            font-weight: 300;
        }

        .search-input:focus {
            outline: none;
            border-color: var(--gold-base);
            background: rgba(20, 4, 10, 0.6);
            box-shadow: 0 0 20px rgba(197, 160, 89, 0.15);
        }

        /* Button */
        .search-button {
            font-family: 'Cinzel', serif;
            font-size: 13px;
            font-weight: 600;
            letter-spacing: 0.15em;
            text-transform: uppercase;
            color: var(--gold-light);
            background: linear-gradient(135deg, #591b38 0%, #3d0d21 100%);
            border: 1px solid rgba(197, 160, 89, 0.3);
            border-radius: 8px;
            padding: 18px 40px;
            cursor: pointer;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }

        .search-button::before {
            content: '';
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 100%;
            background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
            transition: left 0.5s ease;
        }

        .search-button:hover {
            background: linear-gradient(135deg, #6b2144 0%, #4a1028 100%);
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(0, 0, 0, 0.4);
        }

        .search-button:hover::before {
            left: 100%;
        }

        .search-button:disabled {
            opacity: 0.6;
            cursor: not-allowed;
            transform: none;
        }

        /* Loading Spinner */
        .loading-spinner {
            display: inline-block;
            width: 14px;
            height: 14px;
            border: 2px solid rgba(224, 200, 160, 0.3);
            border-top: 2px solid var(--gold-light);
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin-right: 10px;
            vertical-align: middle;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        /* Results Section */
        .results-section {
            max-width: 1000px;
            margin: 0 auto;
        }

        .results-header {
            text-align: center;
            margin-bottom: 50px;
        }

        .results-header .diamond {
            width: 10px;
            height: 10px;
            background: var(--gold-base);
            transform: rotate(45deg);
            margin: 0 auto 25px;
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0%, 100% { opacity: 0.6; transform: rotate(45deg) scale(1); }
            50% { opacity: 1; transform: rotate(45deg) scale(1.3); }
        }

        .results-title {
            font-family: 'Cinzel', serif;
            font-size: 36px;
            font-weight: 600;
            letter-spacing: 0.1em;
            text-transform: uppercase;
            color: var(--gold-light);
            margin-bottom: 15px;
        }

        .results-subtitle {
            font-family: 'Work Sans', sans-serif;
            font-size: 0.7rem;
            font-weight: 400;
            letter-spacing: 0.12em;
            text-transform: uppercase;
            color: var(--txt-dim);
        }

        /* Gift Card - Glassmorphic Panel */
        .gift-card {
            background: var(--glass-bg);
            backdrop-filter: blur(16px);
            border-radius: 16px;
            padding: 40px;
            margin-bottom: 30px;
            box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
            position: relative;
            overflow: hidden;
            transition: all 0.3s ease;
        }

        .gift-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 1px;
            background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
        }

        .gift-card::after {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            box-shadow: inset 0 1px 2px rgba(255, 255, 255, 0.1);
            border-radius: 16px;
            pointer-events: none;
        }

        .gift-card:hover {
            transform: translateY(-4px);
            box-shadow: 0 25px 60px rgba(0, 0, 0, 0.7);
        }

        .gift-content {
            position: relative;
            z-index: 2;
        }

        .gift-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 20px;
            gap: 20px;
        }

        .gift-name {
            font-family: 'Cinzel', serif;
            font-size: 24px;
            font-weight: 600;
            letter-spacing: 0.05em;
            color: var(--gold-light);
            margin: 0;
            line-height: 1.4;
        }

        .gift-badge {
            font-family: 'Work Sans', sans-serif;
            font-size: 0.65rem;
            font-weight: 600;
            letter-spacing: 0.12em;
            text-transform: uppercase;
            background: rgba(197, 160, 89, 0.15);
            border: 1px solid rgba(197, 160, 89, 0.3);
            color: var(--gold-light);
            padding: 8px 16px;
            border-radius: 20px;
            white-space: nowrap;
        }

        .gift-reason {
            font-family: 'Work Sans', sans-serif;
            font-size: 15px;
            font-weight: 300;
            line-height: 1.8;
            color: var(--txt-dim);
            margin-bottom: 30px;
            letter-spacing: 0.02em;
        }

        .gift-link {
            display: inline-flex;
            align-items: center;
            font-family: 'Work Sans', sans-serif;
            font-size: 0.75rem;
            font-weight: 600;
            letter-spacing: 0.12em;
            text-transform: uppercase;
            color: var(--gold-base);
            text-decoration: none;
            border-bottom: 1px solid rgba(197, 160, 89, 0.3);
            padding-bottom: 4px;
            transition: all 0.3s ease;
        }

        .gift-link:hover {
            color: var(--gold-light);
            border-color: var(--gold-light);
            padding-left: 8px;
        }

        .gift-link svg {
            width: 16px;
            height: 16px;
            margin-right: 10px;
            transition: transform 0.3s ease;
        }

        .gift-link:hover svg {
            transform: translateX(4px);
        }

        /* Responsive */
        @media (max-width: 768px) {
            .title {
                font-size: 48px;
                letter-spacing: 0.1em;
            }

            .search-section {
                padding: 35px 25px;
            }

            .search-form {
                flex-direction: column;
            }

            .search-button {
                width: 100%;
            }

            .gift-card {
                padding: 30px 25px;
            }

            .gift-header {
                flex-direction: column;
            }

            .gift-badge {
                align-self: flex-start;
            }
        }
    </style>
</head>
<body>
    <!-- Gold Dust Canvas -->
    <canvas id="goldDustCanvas"></canvas>

    <div class="container">
        <!-- Header -->
        <div class="header">
            <div class="brand">ACCESCO LIVING</div>
            <h1 class="title">Gift Oracle</h1>
            <div class="subtitle">Curated. Intelligent. Luxurious.</div>
        </div>

        <!-- Search Section -->
        <div class="search-section">
            <div class="search-content">
                <h2 class="search-title">Discover Perfection</h2>
                <p class="search-subtitle">Tell us about the recipient</p>
                
                <form method="POST" id="giftForm" class="search-form">
                    <input 
                        type="text" 
                        name="query" 
                        class="search-input"
                        placeholder="e.g., Gift for grandfather who loves gardening..." 
                        value="{{ query }}"
                        required
                    >
                    <button type="submit" id="submitBtn" class="search-button">
                        <span id="btnText">Get Suggestions</span>
                    </button>
                </form>
            </div>
        </div>

        <!-- Results Section -->
        {% if suggestions %}
        <div class="results-section">
            <div class="results-header">
                <div class="diamond"></div>
                <h2 class="results-title">Recommendations</h2>
                <p class="results-subtitle">Curated picks for you</p>
            </div>

            {% for item in suggestions %}
            <div class="gift-card">
                <div class="gift-content">
                    <div class="gift-header">
                        <h3 class="gift-name">{{ item.name }}</h3>
                        <span class="gift-badge">AI Curated</span>
                    </div>
                    <p class="gift-reason">{{ item.reason }}</p>
                    <a href="https://www.amazon.com/s?k={{ item.name|replace(' ', '+') }}" 
                       target="_blank" 
                       class="gift-link">
                        <svg fill="currentColor" viewBox="0 0 24 24">
                            <path d="M15.936 11.715c-.118-.12-.245-.244-.383-.372l-.37-.348-.363-.33c-.116-.104-.24-.216-.367-.323l-.36-.31c-.12-.1-.24-.194-.36-.29l-.35-.27-.34-.25c-.11-.082-.23-.162-.33-.242l-.32-.22-.31-.21-.31-.19-.3-.18-.28-.16-.28-.15-.26-.14-.25-.13-.24-.11-.22-.1-.21-.08-.2-.07-.19-.06-.18-.04-.15-.03-.15-.02-.13-.01h-.25l-.12.01-.12.02-.12.03-.1.04-.1.05-.09.06-.08.07-.07.08-.06.09-.05.11-.03.11-.02.13-.01.14v.15l.01.14.02.14.03.13.04.13.05.12.07.12.08.11.08.1.1.1.1.09.11.08.12.07.13.07.13.06.14.05.14.04.15.03.15.02.16.01.17.01h.33l.16-.01.16-.02.15-.03.14-.04.14-.05.13-.06.12-.07.11-.08.1-.09.1-.1.08-.11.07-.12.06-.13.04-.13.03-.14.02-.14.01-.15v-.15l-.01-.14-.02-.14-.03-.13-.04-.13-.06-.12-.07-.12-.08-.11-.09-.1-.1-.1-.11-.09-.12-.08-.13-.07-.14-.07-.14-.06-.16-.05-.16-.04-.17-.03-.18-.02-.19-.01-.19-.01h-.4l-.19.01-.19.01-.18.02-.18.03-.17.04-.16.05-.15.06-.14.07-.13.08-.12.09-.11.1-.1.11-.09.12-.08.12-.06.13-.05.13-.04.14-.03.14-.01.15-.01.15v.16l.01.15.02.15.03.14.05.14.06.13.07.13.09.12.1.11.11.1.12.09.13.08.14.07.16.06.16.05.18.04.18.03.19.02.19.01.2.01h.41l.19-.01.19-.01.19-.02.18-.03.17-.04.16-.05.15-.06.14-.07.13-.08.12-.09.11-.1.1-.11.09-.12.08-.12.06-.13.05-.13.03-.14.02-.14.01-.15.01-.15v-.16l-.01-.15-.02-.15-.03-.14-.05-.14-.06-.13-.07-.13-.09-.12-.1-.11-.11-.1-.12-.09-.13-.08-.14-.07-.16-.06-.16-.05-.18-.04-.18-.03-.19-.02-.19-.01-.2-.01h-.41l-.19.01-.19.01-.19.02-.18.03-.17.04-.16.05-.15.06-.14.07-.13.08-.12.09-.11.1-.1.11-.09.12-.08.12-.06.13-.05.13-.03.14-.02.14-.01.15-.01.15v.16l.01.15.02.15.03.14.05.14.06.13.07.13.09.12.1.11.11.1.12.09.13.08.14.07.16.06.16.05.18.04.18.03.19.02.19.01.2.01h.41zm-13.844 7.21c-2.32 0-3.92-1.42-3.92-3.66 0-3.32 3.42-4.58 6.54-4.58.56 0 1.04.04 1.5.08v.76c0 1.5-.78 3.54-3.34 3.54-.78 0-1.4-.24-1.4-.82 0-.58.46-1.02 1.4-1.02.58 0 .96.22 1.12.56h.04c-.06-.6-.1-1.22-.1-1.72 0-.32.02-.68.04-1.04-2.22.14-4.66.92-4.66 2.94 0 1.34.92 2.14 2.22 2.14 1.3 0 2.22-.72 2.66-1.64h.04c.14.88.94 1.64 2.16 1.64 1.32 0 2.22-.72 2.22-1.92 0-1.54-1.12-2.18-2.6-2.38l-.66-.08c-1.02-.12-1.52-.36-1.52-.96 0-.64.6-.98 1.48-.98 1.14 0 1.76.44 1.86 1.3h2.32c-.14-1.98-1.7-3.24-4.14-3.24-2.52 0-4.1 1.44-4.1 3.2 0 1.32.74 2.24 2.08 2.58l.74.18c1.1.28 1.54.44 1.54 1.1 0 .66-.66.96-1.5.96-1.28 0-1.94-.5-2.02-1.56h-2.32c.1 1.94 1.74 3.24 4.3 3.24.48 0 .94-.04 1.38-.14-.52 1.04-1.64 1.74-3.08 1.74zM24 20.18c-3.56 2.44-8.94 3.82-13.48 3.82-5.46 0-10.46-1.94-10.52-1.98-.12-.04-.18-.16-.14-.28.04-.12.16-.18.28-.14 0 0 4.96 1.88 10.38 1.88 4.4 0 9.72-1.34 13.2-3.7.12-.08.28-.04.34.08.08.12.04.28-.06.32z"/>
                        </svg>
                        View on Amazon
                    </a>
                </div>
            </div>
            {% endfor %}
        </div>
        {% endif %}
    </div>

    <script>
        // Gold Dust Particle Animation
        const canvas = document.getElementById('goldDustCanvas');
        const ctx = canvas.getContext('2d');

        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;

        const particles = [];
        const particleCount = 60;

        class Particle {
            constructor() {
                this.reset();
            }

            reset() {
                this.x = Math.random() * canvas.width;
                this.y = canvas.height + Math.random() * 100;
                this.size = Math.random() * 2 + 1;
                this.speedY = Math.random() * 0.5 + 0.3;
                this.speedX = (Math.random() - 0.5) * 0.2;
                this.opacity = Math.random() * 0.5 + 0.3;
                this.color = Math.random() > 0.5 ? '#c5a059' : '#e0c8a0';
            }

            update() {
                this.y -= this.speedY;
                this.x += this.speedX;
                this.opacity += (Math.random() - 0.5) * 0.05;
                this.opacity = Math.max(0.1, Math.min(0.8, this.opacity));

                if (this.y < -10 || this.x < 0 || this.x > canvas.width) {
                    this.reset();
                }
            }

            draw() {
                ctx.fillStyle = this.color;
                ctx.globalAlpha = this.opacity;
                ctx.beginPath();
                ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
                ctx.fill();
            }
        }

        // Initialize particles
        for (let i = 0; i < particleCount; i++) {
            particles.push(new Particle());
        }

        function animate() {
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            
            particles.forEach(particle => {
                particle.update();
                particle.draw();
            });

            requestAnimationFrame(animate);
        }

        animate();

        // Resize canvas on window resize
        window.addEventListener('resize', () => {
            canvas.width = window.innerWidth;
            canvas.height = window.innerHeight;
        });

        // Form submission handling
        const form = document.getElementById('giftForm');
        const btn = document.getElementById('submitBtn');
        const btnText = document.getElementById('btnText');

        form.onsubmit = function() {
            btn.disabled = true;
            btnText.innerHTML = '<span class="loading-spinner"></span>Thinking...';
        };
    </script>
</body>
</html>
"""

def get_ai_suggestions(user_query):
    # Prompting gpt-oss to reason and output JSON for easy parsing
    prompt = f"""
    The user wants a gift for: {user_query}.
    Think about 3 unique gifts. 
    Output ONLY a JSON array of objects with 'name' and 'reason' keys.
    Example: [{{"name": "Item Name", "reason": "Why it fits"}}]
    """
    
    response = ollama.chat(model='gpt-oss:20b-cloud', messages=[{'role': 'user', 'content': prompt}])
    
    # Simple cleaning in case the model adds extra text
    content = response['message']['content'].strip()
    try:
        # Finding the JSON part of the response
        start = content.find('[')
        end = content.rfind(']') + 1
        return json.loads(content[start:end])
    except:
        return [{"name": "Error", "reason": "Could not parse AI response. Please try again."}]

@app.route("/", methods=["GET", "POST"])
def index():
    query = ""
    suggestions = []
    if request.method == "POST":
        query = request.form.get("query")
        suggestions = get_ai_suggestions(query)
    return render_template_string(HTML_TEMPLATE, query=query, suggestions=suggestions)

if __name__ == "__main__":
    app.run(debug=True, port=5000)
