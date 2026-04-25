# This script fetches data from specified Google Sheets, processes the text into manageable chunks, generates embeddings 
# and builds a FAISS index for efficient similarity search.
import pandas as pd
from langchain_community.document_loaders import DataFrameLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_community.vectorstores import FAISS

def build_faiss_index(sheet_urls, vectorstore_path):
    print("Loading data from Google Sheets...")
    
    all_documents = []
    
    # Iterate through the provided Google Sheet URLs
    for i, url in enumerate(sheet_urls):
        print(f"Fetching Sheet {i + 1}...")
        
        # Read the Google Sheet directly into a pandas DataFrame using the CSV export URL
        df = pd.read_csv(url)
        
        # Vector stores need a single text block to embed. 
        # Here, we combine all columns in a row into a single string called 'combined_text'.
        # (Alternatively, you can specify a specific column name if your sheet has a dedicated text column).
        df['combined_text'] = df.apply(lambda row: ' | '.join(row.dropna().astype(str)), axis=1)
        
        # Load the DataFrame into LangChain Document objects
        loader = DataFrameLoader(df, page_content_column="combined_text")
        documents = loader.load()
        all_documents.extend(documents)

    print("Splitting text into chunks...")
    # Chunking strategy: 1500 characters per chunk with a 200-character overlap 
    # to maintain context between chunks.
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=1500,
        chunk_overlap=200,
        length_function=len
    )
    chunks = text_splitter.split_documents(all_documents)
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
    # NOTE: We modified the URLs slightly. 
    # Changed "/edit?gid=" to "/export?format=csv&gid=" so Pandas can download the data as CSV.
    SHEET_URLS = [
        "https://docs.google.com/spreadsheets/d/1BGz-mDo9P-sOj48Tf8l5_uG808ugLJIqAPu8A39fi-c/export?format=csv&gid=732052864",
        "https://docs.google.com/spreadsheets/d/1BGz-mDo9P-sOj48Tf8l5_uG808ugLJIqAPu8A39fi-c/export?format=csv&gid=1907136209"
    ]
    
    FAISS_DB_DIR = "faiss_dog_index"
    
    build_faiss_index(SHEET_URLS, FAISS_DB_DIR)