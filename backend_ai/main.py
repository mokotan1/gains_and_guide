from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os
from groq import Groq
import google.generativeai as genai
from dotenv import load_dotenv
import logging

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

app = FastAPI()

# API 키 설정
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")

# Groq 클라이언트 초기화 (Primary)
groq_client = None
if GROQ_API_KEY:
    groq_client = Groq(api_key=GROQ_API_KEY)
    logger.info("✅ Groq API Key가 로드되었습니다. (Llama 3 활성화)")

# Gemini 설정 (Fallback용)
if GOOGLE_API_KEY:
    genai.configure(api_key=GOOGLE_API_KEY)
    logger.info("✅ Google API Key가 로드되었습니다. (Gemini 활성화)")

# 페르소나 로드
current_dir = os.path.dirname(os.path.abspath(__file__))
persona_path = os.path.join(current_dir, "persona.txt")

try:
    with open(persona_path, "r", encoding="utf-8") as f:
        SYSTEM_PROMPT = f.read()
    logger.info("✅ 페르소나 파일을 성공적으로 읽었습니다.")
except FileNotFoundError:
    SYSTEM_PROMPT = "당신은 전문 헬스 트레이너입니다."
    logger.warning("⚠️ persona.txt를 찾지 못해 기본 페르소나를 사용합니다.")

class ChatRequest(BaseModel):
    user_id: str
    message: str
    context: str = ""

@app.get("/")
def read_root():
    return {"status": "online", "message": "Gains & Guide AI (Groq + Gemini) Server is Running!"}

@app.post("/chat")
async def chat_with_coach(request: ChatRequest):
    full_prompt = f"{SYSTEM_PROMPT}\n\n[사용자 정보]\n{request.context}\n\n[질문]\n{request.message}"

    # 1순위: Groq (Llama 3 70B) 사용 - 초고속 응답
    if groq_client:
        try:
            logger.info("🚀 Groq (Llama 3) 엔진으로 응답 생성 중...")
            completion = groq_client.chat.completions.create(
                model="llama3-70b-8192",
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": f"[데이터]\n{request.context}\n\n[질문]\n{request.message}"}
                ],
                temperature=0.7,
                max_tokens=1024,
            )
            return {"response": completion.choices[0].message.content, "engine": "groq"}
        except Exception as e:
            logger.error(f"❌ Groq 오류 발생, Gemini로 전환합니다: {str(e)}")

    # 2순위: Gemini (Fallback) 사용
    if GOOGLE_API_KEY:
        try:
            logger.info("Fallback: Gemini 엔진으로 응답 생성 중...")
            model = genai.GenerativeModel('gemini-1.5-flash-latest')
            response = model.generate_content(full_prompt)
            return {"response": response.text, "engine": "gemini"}
        except Exception as e:
            logger.error(f"❌ Gemini 오류 발생: {str(e)}")
            raise HTTPException(status_code=500, detail="모든 AI 엔진이 응답하지 않습니다.")

    raise HTTPException(status_code=500, detail="API 키가 설정되지 않았습니다.")

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
