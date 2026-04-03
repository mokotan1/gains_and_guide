# Ollama용 SLM 파인튜닝 가이드

레포 정적 데이터로 SFT JSONL을 만들고, 클라우드에서 QLoRA 학습 후 GGUF → Ollama 등록까지의 절차입니다.

## 1. 학습 데이터 JSON 스키마 (ShareGPT / LLaMA-Factory)

LLaMA-Factory `formatting: sharegpt` 기준 한 줄은 JSON 객체 하나입니다.

```json
{
  "conversations": [
    { "from": "system", "value": "…시스템 지시…" },
    { "from": "human", "value": "…사용자…" },
    { "from": "gpt", "value": "…모델 응답…" }
  ]
}
```

- `from`: `system` | `human` | `gpt` (dataset_info의 `tags`와 일치)
- 모델 응답(`gpt`)은 가능한 한 **순수 JSON 문자열** (추가 설명 없음)

### 1.1 코치 챗 태스크 (`/chat` 계약)

최종 assistant 문자열은 **한 개의 JSON 객체**이며, 앱의 [`CoachChatResponse`](d:/gains_and_guide/backend_ai/services/coach_response_schema.py)와 호환됩니다.

| 필드 | 타입 | 설명 |
|------|------|------|
| `response` | string | 필수. 한글 코칭 본문 (비어 있으면 안 됨) |
| `routine` | object \| null | 루틴 제안 시 객체. 일반 질문만 있으면 `null` |
| `progression` | array \| null | `{"name": string, "increase": number}` 배열 또는 `null` |

`routine` 내부 운동 `name`은 카탈로그 영문명과 일치하도록 학습 예시에 맞춥니다.

### 1.2 주간 추천 태스크 (`/recommend` 계약)

assistant는 루트에 `routine` 키를 둔 JSON입니다 (서버가 그대로 파싱).

```json
{
  "routine": {
    "title": "string",
    "rationale": "string",
    "exercises": [
      { "name": "Barbell Squat", "sets": 3, "reps": 10, "weight": 40.0 }
    ]
  }
}
```

`exercises[]`는 `name`, `sets`, `reps`, `weight` 위주로 맞춥니다.

### 1.3 코퍼스 Q&A (선택)

[`backend_ai/corpus/chunks.jsonl`](d:/gains_and_guide/backend_ai/corpus/chunks.jsonl)의 `text`를 짧은 질의·요약 답변 쌍으로 넣어 스타일/지식 보강에 사용합니다.

## 2. 데이터셋 생성

```bash
cd backend_ai
python -m finetune.build_sft_dataset --out finetune/output/gains_coach_sft_sharegpt.json --validate
```

`--validate`는 저장 직후 [`finetune/validate_sft_samples.py`](../backend_ai/finetune/validate_sft_samples.py)로 assistant 쪽 JSON 계약을 검사합니다. 이미 만든 파일만 검사할 때:

```bash
python -m finetune.validate_sft_samples finetune/output/gains_coach_sft_sharegpt.json
```

출력은 LLaMA-Factory에 바로 넣을 수 있는 **JSON 배열** 파일입니다 (또는 JSONL — 빌더 옵션 참고).

## 3. Google Colab (직접 연동 아님)

AI 에이전트는 Colab 계정에 접속하거나 셀을 대신 실행할 수 **없습니다**. 대신 레포에 Colab용 노트북을 두었습니다.

- [`notebooks/colab_gains_coach_sft.ipynb`](../notebooks/colab_gains_coach_sft.ipynb) 를 Colab에 업로드한 뒤, GPU 런타임으로 순서대로 실행하세요.
- 로컬에서 만든 `gains_coach_sft_sharegpt.json` 을 노트북의 업로드 셀에서 선택합니다.

**Colab에서 `CalledProcessError` / `llamafactory-cli` exit code 1**

- 노트북 학습 셀은 실패 시 **stdout/stderr 마지막 구간**을 한 번 더 출력합니다. 그 위쪽 로그에 실제 원인(데이터 경로, 템플릿 이름, OOM, HF 403 등)이 나옵니다.
- 무료 런타임의 **T4**에서는 `bf16: true` 조합이 환경에 따라 바로 실패할 수 있어, 노트북 YAML은 **`fp16: true`, `bf16: false`**, `cutoff_len: 2048` 을 기본으로 둡니다. A100/L4 등이면 `bf16`/`fp16`을 바꿀 수 있습니다.
- **`GatedRepoError` / 403 / “not in the authorized list”** 는 Hugging Face **게이트 모델**(예: `meta-llama/Llama-3.2-3B-Instruct`)에 **접근 승인이 안 된 계정**이거나, 승인은 됐는데 **다른 계정의 토큰**으로 `login` 한 경우입니다. 해결: [해당 모델 페이지](https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct)에서 신청·승인 후 **그 계정** 토큰으로 로그인. 또는 노트북 기본처럼 **게이트 없는 베이스**(예: `Qwen/Qwen2.5-3B-Instruct`, `template: qwen`)로 학습합니다.
- VRAM 부족이면 `per_device_train_batch_size`·`cutoff_len`·`lora_rank`를 더 낮추거나, 더 작은 instruct 모델로 `model_name_or_path`만 교체해 원인 분리를 합니다.

## 4. LLaMA-Factory (클라우드 GPU / 로컬)

1. [LLaMA-Factory](https://github.com/hiyouga/LLaMA-Factory) 클론 후 `pip install -e ".[torch,metrics]"`
2. 생성된 JSON을 `LLaMA-Factory/data/` 아래에 복사
3. 이 레포의 [`backend_ai/finetune/llamafactory/dataset_info.json`](d:/gains_and_guide/backend_ai/finetune/llamafactory/dataset_info.json) 내용을 LLaMA-Factory의 `data/dataset_info.json`에 **병합** 등록
4. [`gains_coach_sft.yaml`](d:/gains_and_guide/backend_ai/finetune/llamafactory/gains_coach_sft.yaml) 을 `examples/train_lora/` 등에 복사한 뒤 `dataset` / `model_name_or_path` / 출력 경로만 환경에 맞게 수정

예시 명령:

```bash
llamafactory-cli train backend_ai/finetune/llamafactory/gains_coach_sft.yaml
```

(실제 CLI는 LLaMA-Factory 버전에 따라 `llamafactory-cli` 또는 `python src/train.py` 일 수 있음 — 공식 README 확인)

베이스 모델 예: `Qwen/Qwen2.5-3B-Instruct` + `template: qwen`(게이트 없음, Colab 기본과 동일). Llama를 쓰려면 `meta-llama/Llama-3.2-3B-Instruct` + `template: llama3` 이며 **HF에서 모델 접근 승인 + 승인 계정 토큰**이 필요합니다(미승인 시 403).

## 5. GGUF 변환 및 Ollama

1. 어댑터 머지 후 Hugging Face 형식 어댑터+베이스 또는 풀 가중치 준비 (LLaMA-Factory `export` 또는 `huggingface-cli` 업로드 후 로컬 클론).
2. [llama.cpp](https://github.com/ggerganov/llama.cpp)에서 `convert_hf_to_gguf.py` 실행 (버전에 따라 경로 상이):

   ```bash
   python convert_hf_to_gguf.py /path/to/merged_model --outfile gains-coach-f16.gguf --outtype f16
   ./llama-quantize gains-coach-f16.gguf gains-coach-q4_k_m.gguf Q4_K_M
   ```

3. Modelfile에서 `FROM` 경로를 위 GGUF로 맞춘 뒤:

   [`backend_ai/finetune/ollama/Modelfile.example`](backend_ai/finetune/ollama/Modelfile.example)

```bash
ollama create gains-coach -f Modelfile
ollama run gains-coach
```

## 6. 백엔드에서 Ollama(OpenAI 호환) 사용

`backend_ai`는 `LLM_CHAT_PROVIDER=openai_compat` 일 때 Groq 대신 OpenAI SDK로 `OPENAI_COMPAT_BASE_URL`(예: `http://localhost:11434/v1`)에 연결합니다. LangGraph **에이전트(도구)** 경로는 여전히 Groq(`ChatGroq`)이므로, Ollama만 쓸 때는 `USE_LEGACY_CHAT=1` 권장.

자세한 변수는 [`backend_ai/.env.example`](d:/gains_and_guide/backend_ai/.env.example) 참고.

## 7. 라이선스·품질

- Meta Llama 가중치 및 상업 이용 약관을 배포 전에 확인하세요.
- hold-out JSON 몇 건으로 `json.loads` 및 필수 키 검증 스크립트를 돌리는 것을 권장합니다.
