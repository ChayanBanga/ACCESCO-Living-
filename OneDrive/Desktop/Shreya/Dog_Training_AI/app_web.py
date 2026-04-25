# This FastAPI application serves as the backend for a dog training assistant. It integrates a FAISS vector store for local document 
# retrieval and uses the Ollama LLM to generate responses. If the local vector store does not provide a confident answer, it falls 
# back to a custom web search using Scrapling's StealthyFetcher to gather relevant information from DuckDuckGo Lite.

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel

from langchain_huggingface import HuggingFaceEmbeddings
from langchain_community.vectorstores import FAISS
from langchain_ollama import OllamaLLM
from langchain_core.prompts import ChatPromptTemplate

# 1. Import Scrapling instead of DuckDuckGoSearchRun
from scrapling.fetchers import StealthyFetcher

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatRequest(BaseModel):
    query: str
    language: str

print("Loading embeddings and FAISS index...")
embeddings = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")

vectorstore = FAISS.load_local(
    "faiss_dog_index", 
    embeddings,
    allow_dangerous_deserialization=True
)

print("Initializing Llama 3 (8b) via Ollama...")
llm = OllamaLLM(model="llama3:latest", temperature=0.3)

prompt = ChatPromptTemplate.from_template(
    """You are an expert dog trainer. Answer the question using ONLY the provided context.
    Provide direct, actionable steps. Do NOT output any conversational filler or greetings.
    
    CRITICAL INSTRUCTION: You MUST write your entire answer in the following language: {language}
    
    Context: {context}
    
    Question: {question}
    
    Answer:"""
)

# 2. Add the custom Scrapling search function
def custom_web_search(query: str, limit: int = 5) -> str:
    """Uses Scrapling StealthFetcher to get context from DuckDuckGo Lite."""
    results = []
    # Format query for URL
    search_url = f"https://duckduckgo.com/lite/?q={query.replace(' ', '+')}"
    
    try:
        # Fetch headlessly to avoid detection/pop-ups
        page = StealthyFetcher.fetch(search_url, headless=True)
        
        # Target result rows
        rows = page.css('tr')
        
        count = 0
        for row in rows:
            title_node = row.css('a.result-snippet') or row.css('a.result-link')
            snippet_node = row.css('td.result-snippet')
            
            if title_node and count < limit:
                title = title_node[0].text.strip()
                snippet = snippet_node[0].text.strip() if snippet_node else "No snippet available."
                results.append(f"Source: {title}\nSnippet: {snippet}")
                count += 1
                
        if not results:
            return "No relevant information found on the web."
            
        return "\n\n".join(results)
    except Exception as e:
        print(f"Scrapling Error: {e}")
        return "Failed to fetch web results."


# 3. Update context retrieval to use the new custom search
def get_context(inputs):
    query = inputs["question"]
    
    docs_and_scores = vectorstore.similarity_search_with_score(query, k=4)
    search_query = f"dog training {query}" # Ensure crawler stays on topic
    
    # If the DB is completely empty
    if not docs_and_scores:
        print("-> Vector DB empty. Scraping the web with Scrapling...")
        return custom_web_search(search_query)
        
    best_doc, best_score = docs_and_scores[0]
    
    # Threshold for deciding if the Vector DB answer is "good enough"
    DISTANCE_THRESHOLD = 1.2 
    
    if best_score > DISTANCE_THRESHOLD:
        print(f"-> Poor match in Vector DB (distance score: {best_score:.2f}). Scraping web with Scrapling...")
        web_results = custom_web_search(search_query)
        return f"Information from Web Search:\n{web_results}"
    else:
        print(f"-> High confidence in Vector DB (distance score: {best_score:.2f}). Using local data.")
        return "\n\n".join(doc.page_content for doc, _ in docs_and_scores)


rag_chain = (
    {
        "context": get_context,
        "question": lambda x: x["question"],
        "language": lambda x: x["language"]
    }
    | prompt
    | llm
)

@app.get("/")
async def get_ui():
    return FileResponse("templates/index.html")

@app.post("/chat")
async def chat_endpoint(request: ChatRequest):
    user_query = request.query
    target_lang = request.language
    
    print(f"\nReceived Question: {user_query}")
    print(f"Target Language: {target_lang}")
    print("Thinking...")
    
    final_response = rag_chain.invoke({
        "question": user_query,
        "language": target_lang
    })
    
    print("Answer Generated.")
    return {"answer": final_response}

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)