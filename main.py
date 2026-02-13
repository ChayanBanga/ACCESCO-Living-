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
    <title>AI Gift Assistant</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <style>
        .loading-spinner {
            border: 3px solid #f3f3f3;
            border-top: 3px solid #3498db;
            border-radius: 50%;
            width: 20px;
            height: 20px;
            animation: spin 1s linear infinite;
            display: inline-block;
            margin-right: 10px;
        }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    </style>
</head>
<body class="bg-gray-50 min-h-screen">
    <div class="max-w-3xl mx-auto py-12 px-4">
        <div class="text-center mb-10">
            <h1 class="text-4xl font-extrabold text-gray-900 mb-2">🎁 GiftGPT</h1>
            <p class="text-gray-600">Autonomous AI Gift Consultant powered by gpt-oss</p>
        </div>

        <div class="bg-white p-6 rounded-xl shadow-md mb-8">
            <form method="POST" id="giftForm" class="flex flex-col sm:flex-row gap-3">
                <input type="text" name="query" 
                       placeholder="e.g. Gift for grandfather who loves gardening..." 
                       class="flex-1 p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none"
                       value="{{ query }}" required>
                <button type="submit" id="submitBtn" 
                        class="bg-blue-600 hover:bg-blue-700 text-white font-bold py-3 px-6 rounded-lg transition duration-200 flex items-center justify-center">
                    <span id="btnText">Get Suggestions</span>
                    <div id="spinner" class="loading-spinner hidden"></div>
                </button>
            </form>
        </div>

        {% if suggestions %}
        <div class="space-y-6">
            <h2 class="text-xl font-semibold text-gray-800 border-b pb-2">Top Ideas for "{{ query }}"</h2>
            {% for item in suggestions %}
            <div class="bg-white p-6 rounded-xl shadow-sm border border-gray-100 hover:shadow-md transition-shadow">
                <div class="flex justify-between items-start mb-3">
                    <h3 class="text-lg font-bold text-blue-600">{{ item.name }}</h3>
                    <span class="bg-blue-50 text-blue-700 text-xs font-semibold px-2.5 py-0.5 rounded">AI Choice</span>
                </div>
                <p class="text-gray-600 mb-4 leading-relaxed">{{ item.reason }}</p>
                <a href="https://www.amazon.com/s?k={{ item.name|replace(' ', '+') }}" 
                    target="_blank" 
                    class="inline-flex items-center text-sm font-semibold text-orange-600 hover:text-orange-700">
                        <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 24 24">
                            <path d="M15.936 11.715c-.118-.12-.245-.244-.383-.372l-.37-.348-.363-.33c-.116-.104-.24-.216-.367-.323l-.36-.31c-.12-.1-.24-.194-.36-.29l-.35-.27-.34-.25c-.11-.082-.23-.162-.33-.242l-.32-.22-.31-.21-.31-.19-.3-.18-.28-.16-.28-.15-.26-.14-.25-.13-.24-.11-.22-.1-.21-.08-.2-.07-.19-.06-.18-.04-.15-.03-.15-.02-.13-.01h-.25l-.12.01-.12.02-.12.03-.1.04-.1.05-.09.06-.08.07-.07.08-.06.09-.05.11-.03.11-.02.13-.01.14v.15l.01.14.02.14.03.13.04.13.05.12.07.12.08.11.08.1.1.1.1.09.11.08.12.07.13.07.13.06.14.05.14.04.15.03.15.02.16.01.17.01h.33l.16-.01.16-.02.15-.03.14-.04.14-.05.13-.06.12-.07.11-.08.1-.09.1-.1.08-.11.07-.12.06-.13.04-.13.03-.14.02-.14.01-.15v-.15l-.01-.14-.02-.14-.03-.13-.04-.13-.06-.12-.07-.12-.08-.11-.09-.1-.1-.1-.11-.09-.12-.08-.13-.07-.14-.07-.14-.06-.16-.05-.16-.04-.17-.03-.18-.02-.19-.01-.19-.01h-.4l-.19.01-.19.01-.18.02-.18.03-.17.04-.16.05-.15.06-.14.07-.13.08-.12.09-.11.1-.1.11-.09.12-.08.12-.06.13-.05.13-.04.14-.03.14-.01.15-.01.15v.16l.01.15.02.15.03.14.05.14.06.13.07.13.09.12.1.11.11.1.12.09.13.08.14.07.16.06.16.05.18.04.18.03.19.02.19.01.2.01h.41l.19-.01.19-.01.19-.02.18-.03.17-.04.16-.05.15-.06.14-.07.13-.08.12-.09.11-.1.1-.11.09-.12.08-.12.06-.13.05-.13.03-.14.02-.14.01-.15.01-.15v-.16l-.01-.15-.02-.15-.03-.14-.05-.14-.06-.13-.07-.13-.09-.12-.1-.11-.11-.1-.12-.09-.13-.08-.14-.07-.16-.06-.16-.05-.18-.04-.18-.03-.19-.02-.19-.01-.2-.01h-.41l-.19.01-.19.01-.19.02-.18.03-.17.04-.16.05-.15.06-.14.07-.13.08-.12.09-.11.1-.1.11-.09.12-.08.12-.06.13-.05.13-.03.14-.02.14-.01.15-.01.15v.16l.01.15.02.15.03.14.05.14.06.13.07.13.09.12.1.11.11.1.12.09.13.08.14.07.16.06.16.05.18.04.18.03.19.02.19.01.2.01h.41zm-13.844 7.21c-2.32 0-3.92-1.42-3.92-3.66 0-3.32 3.42-4.58 6.54-4.58.56 0 1.04.04 1.5.08v.76c0 1.5-.78 3.54-3.34 3.54-.78 0-1.4-.24-1.4-.82 0-.58.46-1.02 1.4-1.02.58 0 .96.22 1.12.56h.04c-.06-.6-.1-1.22-.1-1.72 0-.32.02-.68.04-1.04-2.22.14-4.66.92-4.66 2.94 0 1.34.92 2.14 2.22 2.14 1.3 0 2.22-.72 2.66-1.64h.04c.14.88.94 1.64 2.16 1.64 1.32 0 2.22-.72 2.22-1.92 0-1.54-1.12-2.18-2.6-2.38l-.66-.08c-1.02-.12-1.52-.36-1.52-.96 0-.64.6-.98 1.48-.98 1.14 0 1.76.44 1.86 1.3h2.32c-.14-1.98-1.7-3.24-4.14-3.24-2.52 0-4.1 1.44-4.1 3.2 0 1.32.74 2.24 2.08 2.58l.74.18c1.1.28 1.54.44 1.54 1.1 0 .66-.66.96-1.5.96-1.28 0-1.94-.5-2.02-1.56h-2.32c.1 1.94 1.74 3.24 4.3 3.24.48 0 .94-.04 1.38-.14-.52 1.04-1.64 1.74-3.08 1.74zM24 20.18c-3.56 2.44-8.94 3.82-13.48 3.82-5.46 0-10.46-1.94-10.52-1.98-.12-.04-.18-.16-.14-.28.04-.12.16-.18.28-.14 0 0 4.96 1.88 10.38 1.88 4.4 0 9.72-1.34 13.2-3.7.12-.08.28-.04.34.08.08.12.04.28-.06.32z"/>
                        </svg>
                        Find on Amazon →
                </a>
            </div>
            {% endfor %}
        </div>
        {% endif %}
    </div>

    <script>
        // UI logic for the loading state
        const form = document.getElementById('giftForm');
        const btn = document.getElementById('submitBtn');
        const spinner = document.getElementById('spinner');
        const btnText = document.getElementById('btnText');

        form.onsubmit = function() {
            btn.disabled = true;
            btn.classList.add('opacity-75', 'cursor-not-allowed');
            spinner.classList.remove('hidden');
            btnText.innerText = 'Thinking...';
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