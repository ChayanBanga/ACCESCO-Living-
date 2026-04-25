# This script processes a PDF document, splits it into manageable chunks, generates embeddings using a HuggingFace model, and builds a FAISS index for efficient similarity search.

from langchain_community.document_loaders import PyPDFLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_community.vectorstores import FAISS

def build_faiss_index(pdf_path, vectorstore_path):
    print("Loading PDF...")
    loader = PyPDFLoader("dog_book.pdf")
    documents = loader.load()

    print("Splitting text into chunks...")
    # Chunking strategy: 1500 characters per chunk with a 200-character overlap 
    # to maintain context between chunks.
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=1500,
        chunk_overlap=200,
        length_function=len
    )
    chunks = text_splitter.split_documents(documents)
    print(f"Created {len(chunks)} chunks.")

    print("Generating embeddings and building FAISS index...")
    # Using a fast, local embedding model from HuggingFace
    embeddings = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")
    
    # Create the vector store
    vectorstore = FAISS.from_documents(chunks, embeddings)
    
    # Save the index locally so we don't have to rebuild it every time
    vectorstore.save_local(vectorstore_path)
    print(f"FAISS index successfully saved to '{vectorstore_path}'.")

if __name__ == "__main__":
    # Replace with your actual PDF file name
    PDF_FILE = "dogs_book.pdf" 
    FAISS_DB_DIR = "faiss_dog_index"
    
    build_faiss_index(PDF_FILE, FAISS_DB_DIR)