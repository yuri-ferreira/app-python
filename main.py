from fastapi import FastAPI 
app = FastAPI() 
@app.get("/") 
async def root(): 
    return {"message": "Aoba mundo! Essa é uma nova mensagem para testar se está tudo funcionando! 🥳"} 
