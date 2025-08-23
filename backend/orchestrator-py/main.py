from fastapi import FastAPI

app = FastAPI(root_path="/api")

@app.get("/")
def read_root():
    return {"message": "Orchestrator-py is running"}
    

@app.get("/health")
def health_check():
    return {"status": "ok"}