from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os
from groq import Groq
from dotenv import load_dotenv
import logging

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

app = FastAPI()

# 1. GROQ_API_KEY 설정 및 클라이언트 생성
# 렌더 환경변수나 .env 파일에 GROQ_API_KEY를 꼭 넣어주세요!
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
if GROQ_API_KEY:
    client = Groq(api_key=GROQ_API_KEY)
    logger.info("✅ Groq API Key가 로드되었습니다. (Llama 3 활성화 완료)")
else:
    logger.error("❌ Groq API Key를 찾을 수 없습니다!")
    client = None

# 2. 페르소나 로드
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
    return {"status": "online", "message": "Gains & Guide AI Coach Server (Llama 3) is Running! 🏋️‍♂️"}

@app.post("/chat")
async def chat_with_coach(request: ChatRequest):
    if not client:
        logger.error("API Key 미설정 상태")
        raise HTTPException(status_code=500, detail="서버에 Groq API 키가 없습니다.")

    try:
        logger.info(f"요청 수신 - User: {request.user_id}, Message: {request.message[:20]}...")

        # 3. Groq (Llama 3) 형식에 맞춰 메시지 조립
        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"[과거 운동 기록]\n{request.context}\n\n[질문]\n{request.message}"}
        ]

        chat_completion = client.chat.completions.create(
            messages=messages,
            model="llama-3.1-8b-instant", # 👈 "llama3-70b-8192" 대신 이 이름을 넣으세요!
            temperature=0.7,
            max_tokens=1024,
        )

        reply = chat_completion.choices[0].message.content

        if not reply:
            return {"response": "AI가 답변을 생성하지 못했습니다."}

        return {"response": reply}

    except Exception as e:
        logger.exception("❌ 답변 생성 중 치명적 오류 발생:")
        raise HTTPException(status_code=500, detail=f"AI 분석 중 오류가 발생했습니다: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)