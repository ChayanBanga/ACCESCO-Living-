import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel

from langchain_huggingface import HuggingFaceEmbeddings
from langchain_community.vectorstores import FAISS
from langchain_ollama import OllamaLLM
from langchain_core.prompts import ChatPromptTemplate

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
retriever = vectorstore.as_retriever(search_kwargs={"k": 4})

print("Initializing Ollama...")
llm = OllamaLLM(model="llama3:latest", temperature=0.3)

prompt = ChatPromptTemplate.from_template(
    """You are an expert dog trainer. Answer the question using ONLY the provided context.
    Provide direct, actionable steps. Do NOT output any conversational filler or greetings.
    
    CRITICAL INSTRUCTION: You MUST write your entire answer in the following language: {language}
    
    Context: {context}
    Question: {question}
    Answer:"""
)

@app.get("/")
async def get_ui():
    return FileResponse("templates/index.html")

@app.post("/chat")
async def chat_endpoint(request: ChatRequest):
    # Step 1: Get Chunks (This is very fast)
    docs = retriever.invoke(request.query)
    chunks = [doc.page_content for doc in docs]
    context_text = "\n\n".join(chunks)
    
    # Step 2: Generate Answer (This takes longer)
    chain = prompt | llm
    final_response = chain.invoke({
        "context": context_text,
        "question": request.query,
        "language": request.language
    })
    
    return {
        "answer": final_response,
        "sources": chunks
    }

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)