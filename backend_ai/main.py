from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os
import google.generativeai as genai
from dotenv import load_dotenv

# 환경 변수 로드 (.env)
load_dotenv()

app = FastAPI()

# GOOGLE_API_KEY 설정
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
if GOOGLE_API_KEY:
    genai.configure(api_key=GOOGLE_API_KEY)

# 페르소나 로드
try:
    with open("persona.txt", "r", encoding="utf-8") as f:
        SYSTEM_PROMPT = f.read()
except FileNotFoundError:
    SYSTEM_PROMPT = "당신은 전문 헬스 트레이너입니다."

# AI 모델 설정 (Gemini 1.5 Flash로 업그레이드)
model = genai.GenerativeModel('gemini-1.5-flash')

class ChatRequest(BaseModel):
    user_id: str
    message: str
    context: str = "" # 이전 대화나 운동 기록 등 추가 정보

@app.get("/")
def read_root():
    return {"message": "Gains & Guide AI Coach Server is Running! 🏋️‍♂️"}

@app.post("/chat")
async def chat_with_coach(request: ChatRequest):
    if not GOOGLE_API_KEY:
        raise HTTPException(status_code=500, detail="Google API Key is missing on server.")

    try:
        # 프롬프트 구성: 페르소나 + 사용자 질문 + 데이터 분석 지침
        full_prompt = f"""
{SYSTEM_PROMPT}

당신은 사용자의 운동 기록(무게, 횟수, RPE 강도)을 분석하여 다음 훈련을 설계하는 전문 코치입니다.
RPE(자각적 운동 강도)는 1에서 10까지이며, 10은 더 이상 할 수 없는 상태를 의미합니다.

[사용자 정보 및 과거 데이터]
ID: {request.user_id}
운동 기록 컨텍스트: {request.context}

[사용자 질문/요청]
{request.message}

[분석 및 추천 가이드]
1. 사용자가 기록한 RPE가 7 이하이면 다음 훈련 때 무게를 2.5kg~5kg 증량하도록 추천하세요.
2. RPE가 9~10이면 무게를 유지하거나 세트수를 줄여 회복을 도우세요.
3. 데이터를 바탕으로 내일의 추천 운동 종목과 강도를 구체적으로 제안하세요.

[답변]
"""
        response = model.generate_content(full_prompt)
        return {"response": response.text}

    except Exception as e:
        print(f"Error generating content: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
