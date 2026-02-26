from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os
from groq import Groq
from dotenv import load_dotenv
import logging
import json

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

app = FastAPI()

# 1. GROQ_API_KEY 설정
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
if GROQ_API_KEY:
    client = Groq(api_key=GROQ_API_KEY)
    logger.info("✅ Groq API Key가 로드되었습니다. (Llama 3 활성화 완료)")
else:
    logger.error("❌ Groq API Key를 찾을 수 없습니다!")
    client = None

# 2. 페르소나 및 운동 카탈로그 로드
current_dir = os.path.dirname(os.path.abspath(__file__))
persona_path = os.path.join(current_dir, "persona.txt")
exercises_json_path = os.path.join(current_dir, "exercises.json")

try:
    with open(persona_path, "r", encoding="utf-8") as f:
        SYSTEM_PROMPT = f.read()
    logger.info("✅ 페르소나 파일을 성공적으로 읽었습니다.")
except FileNotFoundError:
    SYSTEM_PROMPT = "당신은 전문 헬스 트레이너입니다."
    logger.warning("⚠️ persona.txt를 찾지 못해 기본 페르소나를 사용합니다.")

# 운동 카탈로그 로드 및 텍스트화
exercise_catalog_text = ""
try:
    if os.path.exists(exercises_json_path):
        with open(exercises_json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            exercises = data.get("exercises", [])
            
            # primary_muscles 기준으로 그룹화
            grouped = {}
            for ex in exercises:
                muscles = ex.get("primary_muscles", ["unknown"])
                name = ex.get("name", "Unknown Exercise")
                for muscle in muscles:
                    if muscle not in grouped:
                        grouped[muscle] = []
                    grouped[muscle].append(name)
            
            # 텍스트 생성
            catalog_lines = ["[Available Exercise Catalog]"]
            for muscle, names in grouped.items():
                catalog_lines.append(f"{muscle}: {', '.join(names)}")
            exercise_catalog_text = "\n".join(catalog_lines)
            logger.info("✅ 운동 카탈로그를 성공적으로 로드하고 그룹화했습니다.")
    else:
        logger.warning(f"⚠️ {exercises_json_path} 파일이 없어 카탈로그를 로드하지 못했습니다.")
except Exception as e:
    logger.error(f"❌ 운동 카탈로그 로드 중 오류 발생: {e}")

class ChatRequest(BaseModel):
    user_id: str
    message: str
    context: str = ""

@app.get("/")
def read_root():
    return {"status": "online", "message": "Gains & Guide AI Coach Server is Running!"}

@app.post("/chat")
async def chat_with_coach(request: ChatRequest):
    if not client:
        raise HTTPException(status_code=500, detail="서버에 Groq API 키가 없습니다.")

    try:
        full_system_prompt = SYSTEM_PROMPT
        if exercise_catalog_text:
            full_system_prompt += f"\n\n{exercise_catalog_text}"

        messages = [
            {"role": "system", "content": full_system_prompt},
            {"role": "user", "content": f"[과거 운동 기록]\n{request.context}\n\n[질문]\n{request.message}"}
        ]

        chat_completion = client.chat.completions.create(
            messages=messages,
            model="llama-3.1-8b-instant",
            temperature=0.7,
            max_tokens=1024,
            response_format={"type": "json_object"}
        )

        reply = chat_completion.choices[0].message.content

        try:
            parsed_reply = json.loads(reply)
            text_response = parsed_reply.get("response") or parsed_reply.get("message") or "답변 내용을 찾을 수 없습니다."

            return {
                "response": text_response,
                # 👇 루틴 객체를 그대로 반환
                "routine": parsed_reply.get("routine")
            }
        except json.JSONDecodeError:
            return {"response": reply, "routine": None}

    except Exception as e:
        logger.exception("❌ 답변 생성 중 오류 발생:")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)