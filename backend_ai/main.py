from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os
import google.generativeai as genai
from dotenv import load_dotenv
import logging

# 로깅 설정 (Render 로그에서 상세히 보기 위함)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

app = FastAPI()

# GOOGLE_API_KEY 설정 및 확인
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
if GOOGLE_API_KEY:
    genai.configure(api_key=GOOGLE_API_KEY)
    logger.info("✅ Google API Key가 성공적으로 로드되었습니다.")
else:
    logger.error("❌ Google API Key를 찾을 수 없습니다! Render 환경 변수를 확인하세요.")

# 페르소나 로드 (경로 문제 방지)
current_dir = os.path.dirname(os.path.abspath(__file__))
persona_path = os.path.join(current_dir, "persona.txt")

try:
    with open(persona_path, "r", encoding="utf-8") as f:
        SYSTEM_PROMPT = f.read()
    logger.info("✅ 페르소나 파일을 성공적으로 읽었습니다.")
except FileNotFoundError:
    SYSTEM_PROMPT = "당신은 전문 헬스 트레이너입니다."
    logger.warning("⚠️ persona.txt를 찾지 못해 기본 페르소나를 사용합니다.")

# AI 모델 설정 (Gemini 1.5 Flash + 안전 설정 완화)
generation_config = {
    "temperature": 0.7,
    "top_p": 0.95,
    "top_k": 64,
    "max_output_tokens": 1024,
}

safety_settings = [
    {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
    {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
    {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
    {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"},
]

model = genai.GenerativeModel(
    model_name='gemini-1.5-flash-latest',
    generation_config=generation_config,
    safety_settings=safety_settings
)

class ChatRequest(BaseModel):
    user_id: str
    message: str
    context: str = ""

@app.get("/")
def read_root():
    return {"status": "online", "message": "Gains & Guide AI Coach Server is Running! 🏋️‍♂️"}

@app.post("/chat")
async def chat_with_coach(request: ChatRequest):
    if not GOOGLE_API_KEY:
        logger.error("API Key 미설정 상태에서 요청이 들어왔습니다.")
        raise HTTPException(status_code=500, detail="서버에 API 키가 설정되지 않았습니다.")

    try:
        logger.info(f"요청 수신 - User: {request.user_id}, Message: {request.message[:20]}...")
        
        full_prompt = f"""
{SYSTEM_PROMPT}

[사용자 정보 및 과거 데이터]
운동 기록 컨텍스트: {request.context}

[사용자 질문/요청]
{request.message}

[답변 가이드]
데이터 기반으로 성실히 답변하고, 필요한 경우 증량이나 휴식을 권고하세요.
"""
        response = model.generate_content(full_prompt)
        
        if not response.text:
            logger.error("AI 응답 텍스트가 비어있습니다.")
            return {"response": "AI가 답변을 생성하지 못했습니다. 다시 시도해 주세요."}

        return {"response": response.text}

    except Exception as e:
        logger.exception("❌ 답변 생성 중 치명적 오류 발생:")
        raise HTTPException(status_code=500, detail=f"AI 분석 중 오류가 발생했습니다: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
