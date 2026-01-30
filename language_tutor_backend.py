import asyncio
from fastapi import FastAPI, UploadFile, File, HTTPException, Body, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from typing import List, Optional, Literal
import os
import json
import httpx
from typing import Dict, Any
import subprocess  # для whisper STT и piper CLI
import logging
import tempfile  # для временного файла в /stt
import hashlib
from pathlib import Path
import time

logger = logging.getLogger("language_tutor_backend")


# ==================   PIPER TTS НАПРЯМУЮ В БЭКЕНДЕ   ==================

# Путь к моделям Piper (проверь, что у тебя реально так!)
PIPER_MODELS_DIR = "/workspace/langapp/piper_models"

# Язык -> конкретный onnx-файл из твоей папки
LANG_TO_MODEL: Dict[str, str] = {
    # Немецкий
    "de": os.path.join(PIPER_MODELS_DIR, "de_DE-thorsten-medium.onnx"),

    # Английский (британский)
    "en": os.path.join(PIPER_MODELS_DIR, "en_GB-alba-medium.onnx"),

    # Французский
    "fr": os.path.join(PIPER_MODELS_DIR, "fr_FR-upmc-medium.onnx"),

    # Испанский
    "es": os.path.join(PIPER_MODELS_DIR, "es_ES-mls_10246-low.onnx"),

    # Итальянский
    "it": os.path.join(PIPER_MODELS_DIR, "it_IT-paola-medium.onnx"),

    # Корейский
    "ko": os.path.join(PIPER_MODELS_DIR, "ko_KR-hajun-medium.onnx"),
}

# Алиасы языков, чтобы работало и с English/German, и с "английский"/"немецкий"
LANG_ALIASES: Dict[str, list[str]] = {
    "en": ["en", "en-us", "en-gb", "english", "английский", "англ"],
    "de": ["de", "de-de", "deutsch", "german", "немецкий", "нем"],
    "fr": ["fr", "fr-fr", "français", "french", "французский", "франц"],
    "es": ["es", "es-es", "español", "spanish", "испанский", "исп"],
    "it": ["it", "it-it", "italiano", "italian", "итальянский", "итал"],
    "ko": ["ko", "ko-kr", "korean", "한국어", "корейский", "кор"],
}

def _piper_model_path_for_language(language: str) -> str:
    lang = normalize_lang_code(language)
    model_path = LANG_TO_MODEL.get(lang)
    if model_path:
        return model_path
    # Fallback на английский, если язык не найден
    return LANG_TO_MODEL.get("en") or ""


def normalize_lang_code(language: str) -> str:
    """
    Приводим произвольное название языка к коду "de", "en", "fr" и т.д.
    Поддерживает варианты:
    - en, en-US, english
    - Deutsch, German, Немецкий
    - Английский, Французский и т.п.
    """
    if not language:
        return "en"

    lang = language.strip().lower()

    # Сначала пробуем по алиасам
    for code, aliases in LANG_ALIASES.items():
        if lang == code or lang in aliases:
            return code

    # Дальше — старый механизм: отрезаем регион
    for sep in ("-", "_"):
        if sep in lang:
            lang = lang.split(sep)[0]
            break

    # И берём первые 2 буквы
    if len(lang) > 2:
        lang = lang[:2]

    return lang


def synthesize_tts_piper(text: str, model_path: str) -> bytes:
    """
    Piper -> WAV (temp) -> MP3 (ffmpeg).
    Возвращает MP3 bytes.
    """
    import tempfile
    import subprocess
    import os

    PIPER_BIN = "/workspace/langapp/piper_bin/piper/piper"

    if not os.path.exists(PIPER_BIN):
        raise RuntimeError(f"piper binary not found: {PIPER_BIN}")
    if not os.path.exists(model_path):
        raise RuntimeError(f"piper model not found: {model_path}")

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        wav_path = f.name

    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as f:
        mp3_path = f.name

    try:
        # 1️⃣ Piper -> WAV
        proc = subprocess.run(
            [PIPER_BIN, "--model", model_path, "--output_file", wav_path],
            input=text.encode("utf-8"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=os.environ.copy(),
        )

        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.decode("utf-8", "ignore")[:1000])

        if not os.path.exists(wav_path) or os.path.getsize(wav_path) < 200:
            raise RuntimeError("piper produced empty wav")

        # 2️⃣ WAV -> MP3 (ffmpeg из workspace)
        proc2 = subprocess.run(
            [
                FFMPEG_BIN,
                "-y",
                "-i", wav_path,
                "-codec:a", "libmp3lame",
                "-b:a", "64k",
                mp3_path,
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        if proc2.returncode != 0:
            raise RuntimeError(proc2.stderr.decode("utf-8", "ignore")[:1000])

        if not os.path.exists(mp3_path) or os.path.getsize(mp3_path) < 200:
            raise RuntimeError("ffmpeg produced empty mp3")

        with open(mp3_path, "rb") as f:
            return f.read()

    finally:
        for p in (wav_path, mp3_path):
            try:
                os.remove(p)
            except Exception:
                pass



def synthesize_with_piper(text: str, language: str, voice: Optional[str] = None) -> bytes:
    """
    Озвучка текста через Piper бинарник.
    """
    text = (text or "").strip()
    if not text:
        return b""

    model_path = None
    if voice:
        if os.path.isfile(voice):
            model_path = voice
        else:
            voice_code = normalize_lang_code(voice)
            model_path = LANG_TO_MODEL.get(voice) or LANG_TO_MODEL.get(voice_code)

    if not model_path:
        model_path = _piper_model_path_for_language(language)

    t0 = time.time()
    audio = synthesize_tts_piper(text, model_path)
    logger.info(
        "[TTS] Piper synth took %.2fs bytes=%d model=%s",
        time.time() - t0,
        len(audio),
        model_path,
    )
    return audio


def _build_tts_cache_filename(
    text: str,
    language: Optional[str],
    voice: Optional[str],
    sample_rate: Optional[int],
) -> str:
    cache_key_raw = f"{voice or ''}|{sample_rate or ''}|{language or ''}|{text}"
    cache_key = hashlib.sha1(cache_key_raw.encode("utf-8")).hexdigest()
    return f"{cache_key}.mp3"


def _ensure_cached_tts_file(
    text: str,
    language: Optional[str],
    voice: Optional[str],
    sample_rate: Optional[int],
) -> Path:
    """
    Returns path to cached wav file for given TTS params, generating it if needed.
    """
    filename = _build_tts_cache_filename(text, language, voice, sample_rate)
    filepath = AUDIO_CACHE_DIR / filename

    if filepath.exists():
        return filepath

    model_path = _piper_model_path_for_language(language or "en")
    logger.info(
        "[TTS] Piper synthesis start model=%s text_len=%d",
        model_path,
        len(text),
    )
    audio_bytes = synthesize_with_piper(text, language or "en", voice=voice)
    filepath.write_bytes(audio_bytes)
    return filepath


def _build_audio_url(filename: str) -> str:
    return f"{AUDIO_BASE_URL}/audio/{filename}"


# ==================   КОНЕЦ БЛОКА PIPER   ==================

# ------------------ LOCAL WHISPER STT (whisper.cpp) ------------------

WHISPER_BIN = "/workspace/langapp/whisper.cpp/build/bin/whisper-cli"
WHISPER_MODEL = "/workspace/langapp/whisper.cpp/models/ggml-base.bin"

try:
    # Используем OpenAI только для STT, если он установлен и настроен
    from openai import OpenAI
except Exception:
    OpenAI = None

# ---------- Config via environment ----------
# These settings let us move the service without changing code.
AUDIO_CACHE_DIR = Path(os.getenv("AUDIO_CACHE_DIR", "/workspace/langapp/audio_cache"))
AUDIO_CACHE_DIR.mkdir(parents=True, exist_ok=True)
AUDIO_BASE_URL = os.getenv("AUDIO_BASE_URL", "https://api.languagetutorapp.org").rstrip("/")

FFMPEG_BIN = os.getenv("FFMPEG_BIN", "/workspace/langapp/tools/ffmpeg/ffmpeg")

COURSES_V2_DIR = Path(os.getenv("COURSES_V2_DIR", "/workspace/langapp/courses_v2"))

SKILL_META = {
    "listening": {"title": "Listening", "description": "Train comprehension through audio-first tasks."},
    "speaking": {"title": "Speaking", "description": "Practice speaking with prompts and dialogues."},
    "grammar": {"title": "Grammar", "description": "Solidify grammar patterns with focused drills."},
    "vocabulary": {"title": "Vocabulary", "description": "Grow your word bank with themed practice."},
    "writing": {"title": "Writing", "description": "Write and polish texts for different scenarios."},
    "error_correction": {"title": "Error correction", "description": "Spot and fix mistakes to build accuracy."},
}

SKILL_ORDER = [
    "vocabulary",
    "grammar",
    "listening",
    "speaking",
    "writing",
    "error_correction",
]

DEFAULT_SKILL = "vocabulary"


BACKEND_HOST = os.getenv("BACKEND_HOST", "0.0.0.0")
BACKEND_PORT = int(os.getenv("BACKEND_PORT", "8000"))

LLM_TYPE = os.getenv("LLM_TYPE", "ollama")

# адрес ollama внутри сервера
LLM_BASE_URL = "http://127.0.0.1:11434"

# имя модели в ollama
LLM_MODEL = os.getenv("LLM_MODEL", "llama3.1:8b")

# новый URL для ollama 0.3+ (НЕ /v1/chat/completions!)
LLM_CHAT_COMPLETIONS_URL = LLM_BASE_URL + "/api/chat"

LLM_API_KEY = os.getenv("LLM_API_KEY")
LLM_TIMEOUT = float(os.getenv("LLM_TIMEOUT", "60"))



# Env guide:
# - BACKEND_HOST / BACKEND_PORT — где стартует FastAPI.
# - LLM_BASE_URL / LLM_MODEL / LLM_API_KEY — параметры нового чат-LLM.
# - OPENAI_API_KEY — остаётся только для STT.

# OpenAI используется только для STT, чтобы не ломать существующие фронтовые вызовы.

# ---------- System prompts ----------

COURSE_PLAN_SYSTEM_PROMPT = """
Ты — методист международной языковой школы и автор современных игровых курсов по иностранным языкам.

Твоя задача — создать СТРУКТУРИРОВАННЫЙ, ИНТЕРЕСНЫЙ и ЖИВОЙ ПЛАН КУРСА для конкретного ученика.

ВХОДНЫЕ ДАННЫЕ (ты получаешь их в user-сообщении в формате JSON):
- language: какой язык изучает ученик (например, "English", "German").
- level_hint: примерный уровень ученика (A1, A2, B1, B2, C1, C2 или пусто).
- age, gender: возраст и пол (нужны только для стилистики примеров).
- goals: цели ученика (например: переезд, учеба за границей, общение в путешествиях).
- interests (если есть в запросе): темы, которые нравятся ученику (путешествия, IT, спорт, фильмы, музыка и т.д.).

ТВОЯ ЗАДАЧА:
1. Разбить обучение на уровни (CourseLevel), согласованные с входным level_hint.
2. Для каждого уровня:
   - Придумать понятный title и description.
   - Задать общий список target_grammar (грамматические темы уровня).
   - Задать общий список target_vocab (лексические темы уровня).
   - Сформировать список lessons (уроков), где каждый урок — отдельная коммуникативная ситуация.

3. Для КАЖДОГО урока (Lesson) внутри уровня ОБЯЗАТЕЛЬНО укажи:
   - id: уникальная строка (можно просто "L1", "L2" и т.п. — главное, чтобы были разные).
   - title: короткое название урока.
   - type: "dialog", "vocab", "grammar" или "mixed" — в соответствии с текущей моделью кода.
   - description: краткое описание реальной жизненной ситуации с лёгким юмором (например, неловкое знакомство, смешной заказ в кафе и т.п.).
   - grammar_topics: список конкретных грамматических ПОДТЕМ именно этого урока (подмножество или детализация target_grammar).
   - vocab_topics: список конкретных лексических ПОДТЕМ именно этого урока (подмножество или детализация target_vocab).
   - experience_line: 1 строка про ожидаемый опыт/XP (например, "Опыт: закрепишь Future Simple и лексику встреч (+15 XP)").

ВАЖНО:
- target_grammar и target_vocab в CourseLevel — это ОБЩИЕ темы всего уровня.
- lesson.grammar_topics и lesson.vocab_topics — это ТЕМЫ КОНКРЕТНОГО УРОКА.
- Уроки одного уровня НЕ должны иметь идентичные списки grammar_topics и vocab_topics. Каждый урок отвечает за свою часть материала.
- Если level_hint относится к C1 или C2:
    * В target_grammar и lesson.grammar_topics НЕ добавляй базовую грамматику.
    * Основной фокус — на лексике и стилях: устойчивые выражения, идиомы, коллокации, академическая и профессиональная лексика, нюансы значений.
    * В vocab_topics делай акцент на сложных темах: общество, культура, технологии, профессия, дискуссии, искусство.

УЧЁТ ИНТЕРЕСОВ УЧЕНИКА:
- Если interests переданы, старайся, чтобы как минимум 60–70% уроков напрямую или косвенно касались этих интересов.
  Например:
    * "путешествия" → аэропорт, отель, экскурсии, переезд, новые города;
    * "IT" → встречи, проекты, удалённая работа, приложения, стартапы;
    * "спорт" → тренировки, соревнования, обсуждение матчей;
    * "фильмы и сериалы" → сюжеты, герои, жанры, рекомендации и т.д.
- Оставшиеся уроки могут покрывать общие бытовые и общественные темы, важные для языка.

СТИЛЬ:
- План курса должен быть живым и мотивирующим.
- Описания уроков допускают лёгкий юмор и жизненные ситуации, но без грубости и токсичности.
- Темы должны быть практичными: чтобы ученик понимал, где он сможет использовать этот язык в жизни.

ЛЕКСИЧЕСКАЯ НАГРУЗКА (ориентиры, чтобы равномерно распределять material по урокам):
- A1–A2: в каждом уроке 15–25 новых слов/выражений (определяешь через vocab_topics).
- B1: 25–40 слов/выражений.
- B2: 40–60 слов/выражений.
- C1–C2: 70–100 слов/выражений, в т.ч. устойчивые фразы, профессионализмы, идиомы.

ВЫВОД:
- Ты ВСЕГДА возвращаешь СТРОГО JSON БЕЗ какого-либо пояснительного текста.
- Структура JSON должна точно соответствовать Pydantic-моделям CoursePlan, CourseLevel и Lesson, которые уже есть в коде:
    * CoursePlan содержит список levels.
    * Каждый CourseLevel содержит level_index, title, description, target_grammar, target_vocab, lessons.
    * Каждый Lesson содержит id, title, type, description, grammar_topics, vocab_topics.
"""

LESSON_SYSTEM_PROMPT = """
You are an expert language teacher and course designer.

Your task is to generate a FULL, RICH language lesson in STRICT JSON format.
The lesson will be used inside a mobile language-learning app similar to Duolingo.

────────────────────────────────
MANDATORY RULES (CRITICAL)
────────────────────────────────

1. You MUST generate **8 to 10 exercises**.
   - Less than 8 exercises is NOT allowed.
   - More than 10 exercises is NOT allowed.

2. Output ONLY valid JSON.
   - No markdown
   - No explanations
   - No comments
   - No extra text

3. The JSON MUST strictly match this structure:

{
  "lesson_id": string,
  "lesson_title": string,
  "description": string,
  "exercises": [ ... ]
}

────────────────────────────────
ALLOWED EXERCISE TYPES
────────────────────────────────

You MUST use a MIX of the following exercise types.
Do NOT repeat the same type more than 2 times in a row.

1) multiple_choice
2) translate_sentence
3) fill_in_blank
4) choose_correct_form
5) sentence_order
6) open_answer   (checked later by AI)

────────────────────────────────
EXERCISE FORMAT
────────────────────────────────

1) multiple_choice
{
  "id": string,
  "type": "multiple_choice",
  "instruction": string,
  "question": string,
  "options": [string, string, string, string],
  "correct_index": number,
  "explanation": string
}

2) translate_sentence
{
  "id": string,
  "type": "translate_sentence",
  "instruction": string,
  "question": string,
  "correct_answer": string,
  "explanation": string
}

3) fill_in_blank
{
  "id": string,
  "type": "fill_in_blank",
  "instruction": string,
  "question": string,
  "correct_answer": string,
  "explanation": string
}

4) choose_correct_form
{
  "id": string,
  "type": "choose_correct_form",
  "instruction": string,
  "question": string,
  "options": [string, string, string],
  "correct_index": number,
  "explanation": string
}

5) sentence_order
{
  "id": string,
  "type": "sentence_order",
  "instruction": string,
  "words": [string, string, string, string],
  "correct_sentence": string,
  "explanation": string
}

6) open_answer
{
  "id": string,
  "type": "open_answer",
  "instruction": string,
  "question": string,
  "sample_answer": string,
  "evaluation_criteria": string
}

────────────────────────────────
CONTENT GUIDELINES
────────────────────────────────

• Главный фокус урока — грамматика (времена, порядок слов, согласование, формы глаголов). Даже словарные задания должны подкреплять грамматический паттерн.
• Exercises should gradually increase in difficulty.
• Focus on practical, real-life language usage.
• Use natural, spoken language.
• Avoid childish or trivial examples.
• Do NOT repeat the same sentence with small variations.
• Grammar and vocabulary must match the lesson topic.
• В каждом уроке используй минимум 3 разных типа упражнений.
• Для exercise type "translate_sentence":
  - Инструкция ОБЯЗАТЕЛЬНО на русском языке (например, "Переведите предложение на английский язык.").
  - В question помещай предложение на русском языке с кириллицей. Никакой латинской транслитерации.

────────────────────────────────
QUALITY REQUIREMENTS
────────────────────────────────

• The lesson should feel like a REAL mini-course.
• At least:
  - 2 grammar-focused tasks
  - 2 vocabulary-focused tasks
  - 2 sentence-level tasks
• The final exercises should combine grammar + vocabulary.

FINAL EXERCISE RULE:
• The LAST exercise MUST be an "open_answer"
• This is the BOSS TASK
• It must combine grammar + vocabulary
• It should simulate a real-life situation
• Difficulty: higher than previous exercises

────────────────────────────────
FINAL CHECK BEFORE OUTPUT
────────────────────────────────

Before producing output, internally verify:
✓ JSON is valid
✓ 8–10 exercises included
✓ Exercise formats are correct
✓ Language matches lesson language
✓ No forbidden text outside JSON
"""


app = FastAPI()

# Разрешаем запросы с фронтенда (Flutter Web / мобильный)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # при желании можно сузить до конкретных доменов
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Раздаём сгенерированные аудиофайлы
app.mount("/audio", StaticFiles(directory=AUDIO_CACHE_DIR), name="audio")

# ---------- Модели запросов/ответов ----------


class SituationContext(BaseModel):
    my_role: str = Field(..., alias="my_role")
    partner_role: str = Field(..., alias="partner_role")
    circumstances: str

    class Config:
        allow_population_by_field_name = True


class GenerateSituationRequest(BaseModel):
    language: str
    level: str
    character: str
    topic_hint: Optional[str] = Field(default=None, alias="topic_hint")


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str


class ChatRequest(BaseModel):
    language: str
    level: Optional[str] = "B1"              # A1–C2
    topic: Optional[str] = "General conversation"
    user_gender: Optional[str] = "unspecified"   # "male" / "female" / "unspecified"
    user_age: Optional[int] = None
    partner_gender: Optional[str] = "female"     # "male" / "female"
    messages: List[ChatMessage]
    character: Optional[str] = None
    situation: Optional[SituationContext] = None

class LegacyChatRequest(BaseModel):
    # Старый формат, который посылает Flutter
    language: str
    student_message: str
    level: Optional[str] = "B1"
    words_learned: Optional[int] = 0


class ChatResponse(BaseModel):
    reply: str
    corrections_text: str
    partner_name: str
    audio_url: Optional[str] = None


class TTSRequest(BaseModel):
    text: str
    language: Optional[str] = "en"
    voice: Optional[str] = None  # опциональный выбор конкретной модели
    character: Optional[str] = None
    speed: Optional[float] = None
    sample_rate: Optional[int] = None


class STTResponse(BaseModel):
    text: str          # распознанный текст
    language: str      # язык, который мы ожидали



class TranslateRequest(BaseModel):
    word: str
    language: Optional[str] = "English"
    with_audio: Optional[bool] = False


class TranslateResponse(BaseModel):
    translation: str
    example: str
    example_translation: str
    audio_url: Optional[str] = None


class CoursePreferences(BaseModel):
    """Параметры ученика для генерации плана курса."""
    language: str                       # например: "English", "German"
    level_hint: Optional[str] = None    # например: "A2", "beginner"
    age: Optional[int] = None
    gender: Optional[Literal["male", "female", "other"]] = None
    goals: Optional[str] = None         # свободный текст: "переезд", "экзамен" и т.д.
    interests: List[str] = Field(
        default_factory=list,
        description="Темы и сферы, которые интересны ученику (например: путешествия, работа, отношения, спорт, IT, искусство)",
    )


class Lesson(BaseModel):
    """Один урок внутри уровня."""
    id: str
    title: str
    type: Literal["dialog", "vocab", "grammar", "mixed"]
    description: str
    grammar_topics: List[str] = []
    vocab_topics: List[str] = []
    experience_line: str = Field(
        default="",
        description="Краткая строка о том, какой опыт/XP даст урок.",
    )


class CourseLevel(BaseModel):
    """Один уровень курса (ступень)."""
    level_index: int                    # 1, 2, 3...
    title: str
    description: str
    target_grammar: List[str]
    target_vocab: List[str]
    lessons: List[Lesson]


class CoursePlan(BaseModel):
    """Полный план курса из нескольких уровней."""
    language: str
    overall_level: str                  # например "A2", "B1"
    levels: List[CourseLevel]



class LessonRequest(BaseModel):
    """Запрос на генерацию конкретного урока."""
    language: str
    level_hint: Optional[str] = None
    lesson_title: str                 # название из CoursePlan
    grammar_topics: Optional[List[str]] = None
    vocab_topics: Optional[List[str]] = None
    interests: Optional[List[str]] = None


class LessonExercise(BaseModel):
    """
    Одно упражнение в уроке.

    type:
      - multiple_choice      — выбор правильного варианта
      - choose_correct_form  — выбор правильной формы (такой же формат, как multiple_choice)
      - translate_sentence   — перевод предложения целиком
      - fill_in_blank        — пропуск в предложении
      - reorder_words        — расставить слова в правильном порядке
      - sentence_order       — собрать предложение из слов
      - open_answer          — развёрнутый ответ, проверяется LLM
    """
    id: str
    type: Literal[
        "multiple_choice",
        "choose_correct_form",
        "translate_sentence",
        "fill_in_blank",
        "reorder_words",
        "sentence_order",
        "open_answer",
    ]

    # Общие поля
    instruction: Optional[str] = None
    question: str                          # что показываем пользователю (основный текст задания)
    explanation: str                       # короткое объяснение / разбор

    # Для multiple_choice
    options: Optional[List[str]] = None    # варианты ответа
    correct_index: Optional[int] = None    # индекс правильного варианта

    # Для translate_sentence / fill_in_blank
    correct_answer: Optional[str] = None   # правильный ответ / правильный перевод

    # Для fill_in_blank
    sentence_with_gap: Optional[str] = None  # строка с пропуском, например: "I ____ to school yesterday."

    # Для reorder_words
    reorder_words: Optional[List[str]] = None      # список слов в случайном порядке
    reorder_correct: Optional[List[str]] = None    # тот же список, но в правильном порядке

    # Для open_answer (и умной проверки)
    sample_answer: Optional[str] = None
    evaluation_criteria: Optional[str] = None


class LessonContent(BaseModel):
    """Контент целого урока: список упражнений."""
    lesson_id: str
    lesson_title: str
    description: str
    exercises: List[LessonExercise]


# ---------- Вспомогательные функции ----------


def _llm_headers() -> Dict[str, str]:
    headers = {"Content-Type": "application/json"}
    if LLM_API_KEY:
        headers["Authorization"] = f"Bearer {LLM_API_KEY}"
    return headers


LLM_HTTP = httpx.Client(
    timeout=LLM_TIMEOUT,
    trust_env=False,  # игнорируем proxy из окружения, чтобы не тормозить localhost
    headers=_llm_headers(),
)

@app.on_event("shutdown")
async def _shutdown():
    try:
        LLM_HTTP.close()
    except Exception:
        pass


def _parse_json_content(content: str) -> Dict:
    """Пытаемся извлечь JSON даже если модель обернула его в текст/markdown."""
    if not content:
        return {}
    content = content.strip()
    try:
        return json.loads(content)
    except Exception:
        pass

    try:
        start = content.find("{")
        end = content.rfind("}")
        if start != -1 and end != -1 and end > start:
            return json.loads(content[start : end + 1])
    except Exception:
        pass

    return {}


def _parse_textual_reply(content: str) -> Dict[str, str]:
    """
    Если модель вернула текст вида "reply: ... corrections_text: ...",
    пытаемся выдрать поля из строки. Возвращает {"reply": ..., "corrections_text": ...}.
    """
    reply = ""
    corrections = ""
    if not content:
        return {"reply": reply, "corrections_text": corrections}

    lower = content.lower()
    reply_idx = lower.find("reply:")
    corr_idx = lower.find("corrections_text:")

    def _trim(val: str) -> str:
        return val.strip(" \n\r\t.:")

    if reply_idx != -1 and corr_idx != -1:
        if reply_idx < corr_idx:
            reply = _trim(content[reply_idx + len("reply:") : corr_idx])
            corrections = _trim(content[corr_idx + len("corrections_text:") :])
        else:
            corrections = _trim(content[corr_idx + len("corrections_text:") : reply_idx])
            reply = _trim(content[reply_idx + len("reply:") :])
    elif reply_idx != -1:
        reply = _trim(content[reply_idx + len("reply:") :])
    elif corr_idx != -1:
        corrections = _trim(content[corr_idx + len("corrections_text:") :])
    else:
        reply = content.strip()

    return {
        "reply": reply,
        "corrections_text": corrections,
    }


def _build_chat_request_from_payload(payload: dict) -> ChatRequest:
    if "messages" in payload:
        return ChatRequest(**payload)

    if "message" in payload:
        student_text = payload.get("message", "")
        if not student_text:
            raise HTTPException(status_code=422, detail="Empty 'message'")

        return ChatRequest(
            messages=[ChatMessage(role="user", content=student_text)],
            language=payload.get("language", "English"),
            level=payload.get("level", "B1"),
            character=payload.get("character", "Michael"),
            topic=payload.get("topic", "general"),
        )

    if "student_message" in payload:
        legacy = LegacyChatRequest(**payload)
        student_text = legacy.student_message
        if not student_text:
            raise HTTPException(status_code=422, detail="Empty 'student_message'")

        return ChatRequest(
            messages=[ChatMessage(role="user", content=student_text)],
            language=legacy.language,
            level=getattr(legacy, "level", None) or "B1",
            character=getattr(legacy, "character", None) or "Michael",
            topic="general",
        )

    raise HTTPException(
        status_code=422,
        detail="Unsupported request format: need 'messages' or 'message' or 'student_message'",
    )


def _prepare_chat_messages(
    req: ChatRequest,
) -> tuple[str, List[Dict[str, str]], bool, bool]:
    partner_name = (req.character or "").strip() or get_partner_name(
        req.language,
        req.partner_gender or "female",
    )
    system_prompt = build_system_prompt(
        language=req.language,
        level=req.level,
        topic=req.topic,
        partner_gender=req.partner_gender,
        partner_name=partner_name,
        situation=req.situation,
    )

    history_messages = [
        {"role": msg.role, "content": msg.content}
        for msg in req.messages
    ]
    history_messages = history_messages[-5:]

    has_user_message = any(msg.role == "user" for msg in req.messages)
    last_message_from_user = bool(req.messages and req.messages[-1].role == "user")

    messages = [{"role": "system", "content": system_prompt}]
    messages.extend(history_messages)

    logger.info("[CHAT] situation present: %s", "yes" if req.situation else "no")
    return partner_name, messages, has_user_message, last_message_from_user


def llm_chat_completion(
    messages: List[Dict[str, str]],
    temperature: float = 0.4,
) -> str:
    payload: Dict[str, Any] = {
        "model": LLM_MODEL,
        "messages": messages,
        # иначе ollama будет стримить кусочками
        "stream": False,
        "options": {
            "temperature": temperature,
        },
    }

    t0 = time.time()
    try:
        resp = LLM_HTTP.post(
            LLM_CHAT_COMPLETIONS_URL,      # http://127.0.0.1:11434/api/chat
            json=payload,
        )

        dt_ms = (time.time() - t0) * 1000
        resp.raise_for_status()
        data = resp.json()

        # формат ответа ollama:
        # {"message": {"role": "assistant", "content": "..."} , ...}
        # /api/chat -> {"message":{"content":"..."}}
        # /api/generate -> {"response":"..."}
        content = ((data.get("message") or {}).get("content")) or data.get("response") or ""


        if not isinstance(content, str):
            content = str(content)

        logger.info(
            "[LLM] POST %s %s in %.0fms text_len=%d",
            LLM_CHAT_COMPLETIONS_URL,
            resp.status_code,
            dt_ms,
            len(content),
        )
        return content.strip()

    except Exception:
        dt_ms = (time.time() - t0) * 1000
        logger.exception("[LLM] error while calling chat completion (%.0fms)", dt_ms)
        return "Sorry, something went wrong. Could you write that again?"







def get_partner_name(language: str, partner_gender: str) -> str:
    """Подбираем имя собеседника под язык и пол."""
    female_names = {
        "English": "Emily",
        "German": "Anna",
        "French": "Marie",
        "Spanish": "Sofía",
        "Italian": "Giulia",
        "Korean": "Ji-woo",
    }
    male_names = {
        "English": "Jack",
        "German": "Lukas",
        "French": "Pierre",
        "Spanish": "Carlos",
        "Italian": "Luca",
        "Korean": "Min-jun",
    }

    if partner_gender == "male":
        return male_names.get(language, "Alex")
    else:
        return female_names.get(language, "Alex")


def build_system_prompt(
    language: str,
    level: Optional[str],
    topic: Optional[str],
    partner_gender: Optional[str],
    partner_name: str,
    situation: Optional[SituationContext] = None,
) -> str:
    lang = language or "English"
    level = level or "B1"
    topic = topic or "General conversation"
    partner_gender = partner_gender or "female"

    if partner_gender == "male":
        partner_role = "male friend"
    else:
        partner_role = "female friend"

    situation_contract = ""
    if situation:
        situation_contract = f"""
SITUATION CONTRACT:
- Learner role: {situation.my_role}
- Your role: {situation.partner_role}
- Circumstances: {situation.circumstances}

Obligations:
- Reply strictly as {situation.partner_role}; never say you are an AI.
- Stay inside the described circumstances and tone; use fitting vocabulary.
- If the user goes off-topic, gently steer back and suggest an in-context reply.
- Keep answers concise and natural (1–3 sentences).
- Corrections: brief, helpful, and stay in the scene.
"""

    return f"""
You are a friendly, professional {lang} tutor for a {level} learner. Your name is {partner_name}, a {partner_role} native speaker. Topic: {topic}.

Goals:
- Reply only in {lang} with short, natural answers (1-3 sentences) that keep the conversation moving.
- Be concise and relevant; avoid introductions, sign-offs, and filler.
- Encourage dialogue with occasional brief follow-up questions.

Error correction:
- Correct only the learner's LAST user message; ignore assistant/system/your own messages.
- Preserve the user's meaning: do NOT change intent, nouns, key phrases, or add/remove information.
- Fix only grammar, spelling/typos, word form/choice, and word order. Avoid style rewrites or tone changes.
- If something is unclear, do minimal fixes and keep the original wording; do not guess new meaning.
- First give the corrected version, then a short plain-language note on the fix.
- Ignore minor casing/punctuation unless meaning changes.
- If there are no real mistakes, leave "corrections_text" empty and do not invent issues.
- Do not repeat the user's original sentence verbatim.
- If the last message is NOT from the user, leave "corrections_text" empty.

Style:
- Sound human, not like a textbook or AI; never say you are an AI or language model.
- Avoid repetitive explanations and meta-commentary.
{situation_contract}
Output:
Return STRICT JSON only:
{{"reply":"...","corrections_text":"..."}}
"""


def topics_for_language(language: str) -> List[str]:
    """Список готовых топиков для выбора во фронтенде."""
    base_topics = [
        "Daily life",
        "Friends and relationships",
        "Studies and university",
        "Work and career",
        "Travel and countries",
        "Hobbies and free time",
        "Movies, books and music",
        "Plans for the future",
    ]

    # Можно при желании делать локализацию,
    # пока просто возвращаем один и тот же список
    return base_topics


def _normalize_situation_from_dict(
    raw: Dict[str, Any],
    req: Optional[GenerateSituationRequest] = None,
) -> SituationContext:
    def _field(keys, default=""):
        for key in keys:
            val = raw.get(key)
            if val is None:
                continue
            text = str(val).strip()
            if text:
                return text
        return default

    lang = req.language if req else "English"
    level = req.level if req else "B1"
    partner_name = req.character if req else "conversation partner"
    hint = req.topic_hint if req else ""

    my_role_default = f"{lang} learner at level {level}"
    partner_role_default = f"{partner_name}, a native speaker helping with practice"
    circumstances_default = f"Practicing {lang} about {hint or 'a realistic daily scenario'}"

    my_role = _field(["my_role", "myRole"], my_role_default)
    partner_role = _field(["partner_role", "partnerRole"], partner_role_default)
    circumstances = _field(
        ["circumstances", "context", "situation"],
        circumstances_default,
    )

    return SituationContext(
        my_role=my_role,
        partner_role=partner_role,
        circumstances=circumstances,
    )


def call_llm_chat(req: ChatRequest) -> ChatResponse:
    """Вызов новой LLM для чат-диалога с коррекциями."""
    (
        partner_name,
        messages,
        has_user_message,
        last_message_from_user,
    ) = _prepare_chat_messages(req)

    content = llm_chat_completion(messages, temperature=0.4)

    data = _parse_json_content(content)
    reply_text = ""
    corrections_text = ""
    if data:
        reply_text = str(data.get("reply", "")).strip()
        corrections_text = str(data.get("corrections_text", "")).strip()
        # Если модель вернула только corrections_text в JSON, а сам ответ оставила снаружи,
        # пытаемся взять текст до первого JSON-блока как reply.
        if not reply_text and content:
            bracket_idx = content.find("{")
            if bracket_idx > 0:
                reply_text = content[:bracket_idx].strip()

    if not reply_text:
        # Если модель не вернула JSON — пытаемся вытащить reply/corrections из строки
        parsed = _parse_textual_reply(content or "")
        reply_text = parsed.get("reply", "").strip()
        corrections_text = parsed.get("corrections_text", "").strip()

    # Если reply содержит corrections_text внутри JSON — достанем и разделим.
    if "corrections_text" in (reply_text or ""):
        parsed = _parse_json_content(reply_text)
        if parsed:
            embedded_reply = str(parsed.get("reply", "")).strip()
            embedded_corr = str(parsed.get("corrections_text", "")).strip()
            if embedded_reply:
                reply_text = embedded_reply
            if embedded_corr:
                corrections_text = corrections_text or embedded_corr
        else:
            brace_idx = reply_text.find("{")
            if brace_idx != -1:
                before = reply_text[:brace_idx].strip()
                parsed_brace = _parse_json_content(reply_text[brace_idx:])
                if before:
                    reply_text = before
                if parsed_brace:
                    embedded_corr = str(parsed_brace.get("corrections_text", "")).strip()
                    if embedded_corr:
                        corrections_text = corrections_text or embedded_corr

    # Если ученик ещё ни разу не писал (только первое приветствие) —
    # не показываем никаких исправлений
    if not has_user_message or not last_message_from_user:
        corrections_text = ""

    if not reply_text:
        reply_text = "Sorry, something went wrong. Could you write that again?"

    return ChatResponse(
        reply=reply_text,
        corrections_text=corrections_text,
        partner_name=partner_name,
        audio_url=None,
    )


def call_generate_situation(req: GenerateSituationRequest) -> SituationContext:
    """Генерация ситуации диалога через тот же LLM."""
    system_prompt = f"""
Ты придумываешь неожиданные, забавные, иногда слегка абсурдные ситуации для диалогов.
Сгенерируй 3 строки (каждая 6-20 слов):
- my_role
- partner_role
- circumstances (место/цель/обстоятельства/настроение)

Входные параметры:
- language: {req.language}
- level: {req.level}
- partner persona/name: {req.character}

Требования:
- Сделай сценарий необычным и весёлым, но безопасным (без насилия/секса/политики/токсичности).
- Соответствуй языку и уровню; вплети персонажа в partner_role и обстоятельства.
- Добавляй рандомные неожиданные элементы (например: странные места, юморные ограничения, любопытные цели).
- Верни ТОЛЬКО JSON без дополнительного текста:
{{"my_role":"...","partner_role":"...","circumstances":"..."}}
"""

    user_payload = {
        "language": req.language,
        "level": req.level,
        "character": req.character,
        "topic_hint": req.topic_hint,
    }

    content = llm_chat_completion(
        [
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": json.dumps(user_payload, ensure_ascii=False),
            },
        ],
        temperature=0.7,
    )

    data = _parse_json_content(content)
    return _normalize_situation_from_dict(data or {}, req)



def call_llm_translate(
    language: str,
    word: str,
    include_audio: bool = False,
) -> TranslateResponse:
    """
    Перевод одного слова/фразы на русский + пример и перевод примера.
    Озвучка слова через Piper (если include_audio = True).
    """

    # ---------- 1. Получаем перевод и пример через LLM ----------
    system_prompt = f"""
You are a translator.
Your task: translate ONE word or a very short phrase from {language} to Russian
and give ONE short example sentence in {language} with this word,
AND also provide a Russian translation of this example sentence.

Answer STRICTLY as JSON, without any extra text:

{{
  "translation": "перевод на русский",
  "example": "пример предложения на {language}",
  "example_translation": "перевод примера на русский"
}}
"""

    user_prompt = f"Word: {word}\nLanguage: {language}\nTarget: Russian"

    content = llm_chat_completion(
        [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        temperature=0.2,
    )

    data = _parse_json_content(content)
    if data:
        translation = str(data.get("translation", "")).strip()
        example = str(data.get("example", "")).strip()
        example_translation = str(data.get("example_translation", "")).strip()
    else:
        # fallback: просто отдать весь текст в перевод
        translation = (content or "").strip()
        example = ""
        example_translation = ""

    # Подстраховка, чтобы не возвращать пустые строки
    if not translation:
        translation = word

    if not example:
        example = word

    if not example_translation:
        example_translation = "перевод примера не указан"

    # ---------- 2. Озвучка через Piper + кеш  ----------
    audio_url: Optional[str] = None

    if include_audio:
        try:
            text = (word or "").strip()
            if text:
                filepath = _ensure_cached_tts_file(
                    text,
                    language,
                    voice=None,
                    sample_rate=None,
                )
                audio_url = _build_audio_url(filepath.name)
        except Exception:
            logger.exception("TTS ERROR (Piper) language=%s text=%r", language, word)
            audio_url = None

    return TranslateResponse(
        translation=translation,
        example=example,
        example_translation=example_translation,
        audio_url=audio_url,
    )




# ---------- Эндпоинты FastAPI ----------


def _run_whisper_stt(lang_code: str, audio_bytes: bytes, suffix: str) -> STTResponse:
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=True) as tmp:
        tmp.write(audio_bytes)
        tmp.flush()

        cmd = [
            WHISPER_BIN,
            "-m", WHISPER_MODEL,
            "-f", tmp.name,
            "-l", lang_code,
        ]

        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
        )

        if proc.returncode != 0:
            logging.error(
                f"Whisper STT error (code {proc.returncode}): {proc.stderr}"
            )
            raise HTTPException(status_code=500, detail="Whisper STT failed")

        text = proc.stdout.strip()

        return STTResponse(
            text=text,
            language=lang_code,
        )


@app.get("/health")
async def health_check():
    return {"status": "ok"}

@app.post("/stt", response_model=STTResponse)
async def stt_endpoint(
    language_code: str = Query("en", alias="language_code"),
    file: UploadFile = File(...),
):
    """
    Speech-to-text через локальный whisper.cpp.

    Фронт шлёт:
      POST /stt?language_code=xx
      multipart/form-data с полем 'file' (аудиофайл .wav / .m4a / .webm и т.п.)

    Возвращаем:
      {"text": "...", "language": "xx"}
    """

    contents = await file.read()
    if not contents:
        raise HTTPException(status_code=400, detail="Empty audio file")

    orig_name = file.filename or ""
    _, ext = os.path.splitext(orig_name)
    if not ext:
        ext = ".wav"

    try:
        return await asyncio.to_thread(_run_whisper_stt, language_code, contents, ext)
    except HTTPException:
        raise
    except Exception as e:
        logging.exception("Whisper STT exception")
        raise HTTPException(status_code=500, detail=f"STT internal error: {e}")


@app.get("/topics")
async def get_topics(language: str = "English"):
    return {
        "language": language,
        "topics": topics_for_language(language),
    }


@app.post("/generate_situation", response_model=SituationContext)
async def generate_situation_endpoint(req: GenerateSituationRequest):
    t0 = time.time()
    try:
        situation = await asyncio.to_thread(call_generate_situation, req)
        return situation
    except Exception as e:
        logger.exception("[GENERATE_SITUATION] failed: %s", e)
        return _normalize_situation_from_dict({}, req)
    finally:
        logger.info(
            "[GENERATE_SITUATION] took %.0fms hint=%s",
            (time.time() - t0) * 1000,
            req.topic_hint or "",
        )


@app.post("/chat", response_model=ChatResponse)
async def chat_endpoint(payload: dict = Body(...)):
    """
    Поддерживаем два формата:
    1) Новый: { language, level, messages: [ {role, content}, ... ] }
    2) Старый (Flutter): { language, student_message, level, words_learned }
    """

    req = _build_chat_request_from_payload(payload)


    # НОВЫЙ ВЫЗОВ
    response = await asyncio.to_thread(call_llm_chat, req)
    return response


@app.post("/tts")
async def tts_endpoint(req: TTSRequest):
    text = (req.text or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="Text is required for TTS")

    tts_server_url = os.getenv("TTS_SERVER_URL", "http://127.0.0.1:9010").rstrip("/")

    voice_raw = (req.voice or "").strip().lower()
    voice = "af_heart" if not voice_raw or voice_raw == "default" else (req.voice or "af_heart")
    speed = req.speed if req.speed is not None else 1.0

    payload = {
        "text": text,
        "language": (req.language or "en"),
        "voice": voice,
        "speed": speed,
        "sample_rate": req.sample_rate,
    }

    try:
        async with httpx.AsyncClient(timeout=120) as client:
            r = await client.post(f"{tts_server_url}/synthesize", json=payload)

        if r.status_code != 200:
            # покажем текст ошибки, чтобы было понятно что сломалось
            raise HTTPException(
                status_code=500,
                detail=f"TTS server error {r.status_code}: {r.text[:300]}",
            )

        data = r.json()
        audio_url = data.get("audio_url")
        if not audio_url:
            raise HTTPException(status_code=500, detail=f"TTS server returned no audio_url: {data}")

        # вернём cached тоже (полезно для отладки/метрик)
        return {"audio_url": audio_url, "cached": bool(data.get("cached", False))}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"TTS failed: {e}")


@app.post("/translate-word", response_model=TranslateResponse)
async def translate_word_endpoint(payload: TranslateRequest):
    lang = payload.language or "English"
    return await asyncio.to_thread(
        call_llm_translate,
        lang,
        payload.word,
        bool(payload.with_audio),
    )

def _courses_lang_dir(lang: str) -> Path:
    """Return the best-matching path for a language, trying aliases."""
    normalized = normalize_lang_code(lang or "")
    candidates = [
        COURSES_V2_DIR / (lang or ""),
        COURSES_V2_DIR / normalized,
    ]
    for path in candidates:
        if path.exists():
            return path
    return candidates[0]


def _iter_lesson_files(lang_dir: Path) -> List[Path]:
    return sorted(
        [p for p in lang_dir.rglob("lessons/*.json") if p.is_file()],
        key=lambda p: str(p),
    )


def _normalize_lesson_skill(skill_raw: Optional[str]) -> str:
    skill = (skill_raw or "").strip().lower()
    if skill in SKILL_META:
        return skill
    return DEFAULT_SKILL


def _lesson_summary_from_file(lesson_path: Path) -> Optional[Dict[str, str]]:
    try:
        data = json.loads(lesson_path.read_text(encoding="utf-8"))
    except Exception as e:
        logger.warning("[SKILLS] failed to read lesson %s: %s", lesson_path, e)
        return None

    if not isinstance(data, dict):
        return None

    lesson_id = str(
        data.get("lessonId")
        or data.get("lesson_id")
        or lesson_path.stem
    ).strip() or lesson_path.stem

    title = str(
        data.get("title")
        or data.get("lesson_title")
        or f"Lesson {lesson_id}"
    ).strip() or f"Lesson {lesson_id}"

    skill = _normalize_lesson_skill(data.get("skill"))

    return {
        "lessonId": lesson_id,
        "title": title,
        "skill": skill,
    }


def _load_lessons_grouped_by_skill(lang: str) -> Dict[str, List[Dict[str, str]]]:
    lang_dir = _courses_lang_dir(lang)

    grouped: Dict[str, List[Dict[str, str]]] = {k: [] for k in SKILL_META.keys()}

    if not lang_dir.exists():
        logger.warning("[SKILLS] language dir not found: %s", lang_dir)
        return grouped

    for lesson_path in _iter_lesson_files(lang_dir):
        summary = _lesson_summary_from_file(lesson_path)
        if not summary:
            continue
        grouped.setdefault(summary["skill"], []).append(summary)

    return grouped


@app.get("/skills/{lang}")
def list_skills(lang: str):
    lessons_by_skill = _load_lessons_grouped_by_skill(lang)

    tracks = []
    for skill_id in SKILL_ORDER:
        meta = SKILL_META.get(skill_id, {})
        lessons = lessons_by_skill.get(skill_id, [])
        lessons_count = len(lessons)

        tracks.append(
            {
                "id": skill_id,
                "title": meta.get("title", skill_id.title()),
                "description": meta.get("description", ""),
                "lessonsCount": lessons_count,
                "xp": 0,
                "xpGoal": max(100, lessons_count * 50),
            }
        )

    return tracks


@app.get("/skills/{lang}/{skill_id}")
def list_lessons_for_skill(lang: str, skill_id: str):
    skill_key = (skill_id or "").strip().lower()
    if skill_key not in SKILL_META:
        return []

    lessons_by_skill = _load_lessons_grouped_by_skill(lang)
    lessons = lessons_by_skill.get(skill_key, [])

    return [
        {
            "lessonId": lesson["lessonId"],
            "title": lesson["title"],
            "progress": 0,
        }
        for lesson in lessons
    ]

def _fallback_course_plan(prefs: CoursePreferences) -> CoursePlan:
    # Минимальный валидный план, чтобы фронт не падал
    lvl = CourseLevel(
        level_index=1,
        title=f"Starter ({(prefs.level_hint or '').strip() or 'A1'})",
        description="Auto-generated fallback plan (LLM unavailable or invalid JSON).",
        target_grammar=["present simple", "basic questions"],
        target_vocab=["greetings", "daily routine"],
        lessons=[
            Lesson(
                id="lesson_1",
                title="Making Plans",
                type="mixed",
                description="Basic phrases for making plans and invitations.",
                grammar_topics=["future arrangements"],
                vocab_topics=["schedule", "meet", "time"],
                experience_line="Опыт: научишься строить планы и приглашения (12 XP).",
            ),
            Lesson(
                id="lesson_2",
                title="Inviting Someone",
                type="mixed",
                description="Invitations and responses.",
                grammar_topics=["polite requests"],
                vocab_topics=["invite", "accept", "decline"],
                experience_line="Опыт: уверенно делаешь приглашения и отвечаешь (12 XP).",
            ),
            Lesson(
                id="lesson_3",
                title="Agreeing on Time",
                type="mixed",
                description="Time expressions and confirmations.",
                grammar_topics=["prepositions of time"],
                vocab_topics=["at", "on", "in", "o'clock"],
                experience_line="Опыт: закрепляешь время и согласование встреч (12 XP).",
            ),
            Lesson(
                id="lesson_4",
                title="Changing Plans",
                type="mixed",
                description="Rescheduling and apologizing.",
                grammar_topics=["can/could", "sorry + reason"],
                vocab_topics=["reschedule", "busy", "free"],
                experience_line="Опыт: учишься переносить планы и извиняться (12 XP).",
            ),
            Lesson(
                id="lesson_5",
                title="Making Suggestions",
                type="mixed",
                description="Suggestions and preferences.",
                grammar_topics=["let's", "why don't we"],
                vocab_topics=["suggest", "prefer", "rather"],
                experience_line="Опыт: предлагаешь идеи и обсуждаешь предпочтения (12 XP).",
            ),
            Lesson(
                id="lesson_6",
                title="Final Practice",
                type="mixed",
                description="Mixed practice for the topic.",
                grammar_topics=["review"],
                vocab_topics=["review"],
                experience_line="Опыт: итоговая практика темы (15 XP).",
            ),
        ],
    ) 

    return CoursePlan(
        language=prefs.language,
        overall_level=(prefs.level_hint or "").strip(),
        levels=[lvl],
    )


def _ensure_min_lessons(
    plan: CoursePlan,
    prefs: CoursePreferences,
    min_lessons: int = 6
) -> CoursePlan:
    if not plan.levels:
        return _fallback_course_plan(prefs)

    level = plan.levels[0]

    if not level.lessons:
        level.lessons = []

    if len(level.lessons) >= min_lessons:
        return plan

    base_title = level.lessons[0].title if level.lessons else "Lesson"

    while len(level.lessons) < min_lessons:
        idx = len(level.lessons) + 1
        level.lessons.append(
                Lesson(
                    id=f"lesson_{idx}",
                    title=f"{base_title} #{idx}",
                    type="mixed",
                    description="Auto-added lesson",
                    grammar_topics=["review"],
                    vocab_topics=["review"],
                    experience_line="Опыт: повторение ключевых тем (10 XP).",
                )
        )

    plan.levels[0] = level
    return plan



def _fallback_lesson(req: LessonRequest) -> LessonContent:
    # Минимальный валидный урок, чтобы экран урока всегда открывался
    title = (req.lesson_title or "Lesson").strip() or "Lesson"
    return LessonContent(
        lesson_id=title.replace(" ", "_").lower(),
        lesson_title=title,
        description="Fallback lesson (LLM unavailable or invalid JSON).",
        exercises=[
            LessonExercise(
                id="ex_1",
                type="multiple_choice",
                instruction="Choose the best option.",
                question="You want to invite a friend. What do you say?",
                options=["Let's make plans for tomorrow.", "I ate a sandwich.", "The weather is blue."],
                correct_index=0,
                explanation="Use an invitation / planning phrase.",
            ),
            LessonExercise(
                id="ex_2",
                type="translate_sentence",
                instruction="Translate into the target language.",
                question="Давай встретимся в 7 вечера.",
                correct_answer="Let's meet at 7 pm.",
                explanation="Simple invitation + time.",
            ),
        ],
    )



@app.post("/generate_course_plan", response_model=CoursePlan)
def generate_course_plan(prefs: CoursePreferences):
    """
    Генерирует поуровневый план курса на основе предпочтений ученика.
    """
    try:
        user_content = json.dumps(prefs.dict(), ensure_ascii=False)

        content = llm_chat_completion(
            [
                {"role": "system", "content": COURSE_PLAN_SYSTEM_PROMPT},
                {"role": "user", "content": f"Вот данные ученика в JSON:\n{user_content}"},
            ],
            temperature=0.4,
        )

        data = _parse_json_content(content)
        if not data or not isinstance(data, dict):
            raise ValueError("Failed to parse course plan JSON from model")

        if ("language" not in data) or (not isinstance(data.get("language"), str)):
            data["language"] = prefs.language

        if ("overall_level" not in data) or (not isinstance(data.get("overall_level"), str)):
            data["overall_level"] = (prefs.level_hint or "").strip()

        if "levels" not in data or not isinstance(data["levels"], list):
            raise ValueError("Model did not provide 'levels' list in course plan")

        plan = CoursePlan(**data)
        plan = _ensure_min_lessons(plan, prefs, min_lessons=6)
        return plan


    except Exception as e:
        logger.exception("[COURSE_PLAN] failed, returning fallback: %s", e)
        return _fallback_course_plan(prefs)



@app.post("/generate_lesson", response_model=LessonContent)
def generate_lesson(req: LessonRequest):
    try:
        user_payload = {
            "language": req.language,
            "level_hint": req.level_hint,
            "lesson_title": req.lesson_title,
            "grammar_topics": req.grammar_topics,
            "vocab_topics": req.vocab_topics,
            "interests": req.interests,
        }

        content = llm_chat_completion(
            [
                {"role": "system", "content": LESSON_SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": f"Сгенерируй урок строго в JSON формате.\nВходные данные:\n{json.dumps(user_payload, ensure_ascii=False)}",
                },
            ],
            temperature=0.5,
        )

        data = _parse_json_content(content)
        if not data or not isinstance(data, dict):
            raise ValueError("Invalid lesson JSON")

        # --- нормализация базовых полей ---
        data.setdefault("lesson_title", req.lesson_title or "Lesson")
        data.setdefault("description", "Auto-generated lesson")
        data.setdefault(
            "lesson_id",
            (data["lesson_title"] or "lesson").replace(" ", "_").lower(),
        )

        raw_exercises = data.get("exercises", [])
        fixed_exercises = []

        for i, ex in enumerate(raw_exercises):
            if not isinstance(ex, dict):
                continue

            ex_type = str(ex.get("type") or "").strip().lower()
            if not ex_type:
                continue

            instruction = str(ex.get("instruction") or "").strip()
            question = str(ex.get("question") or "").strip()
            explanation = str(ex.get("explanation") or "").strip()

            if ex_type == "translate_sentence" and not instruction:
                instruction = "Переведите предложение на английский язык."

            ex_fixed: Dict[str, Any] = {
                "id": ex.get("id", f"ex_{i+1}"),
                "type": ex_type,
                "instruction": instruction or "Выполните задание.",
                "question": question,
                "explanation": explanation or "Разбор будет показан после проверки.",
            }

            if ex_type in ("multiple_choice", "choose_correct_form"):
                options = ex.get("options", [])
                correct = ex.get("correct_index")

                if (
                    isinstance(options, list)
                    and len(options) >= 2
                    and isinstance(correct, int)
                ):
                    ex_fixed["options"] = [str(opt) for opt in options]
                    ex_fixed["correct_index"] = correct
                else:
                    continue

            elif ex_type in ("translate_sentence", "fill_in_blank"):
                answer = ex.get("correct_answer")
                if isinstance(answer, str) and answer.strip():
                    ex_fixed["correct_answer"] = answer
                    if ex_type == "fill_in_blank":
                        gap_sentence = ex.get("sentence_with_gap")
                        if isinstance(gap_sentence, str) and gap_sentence.strip():
                            ex_fixed["sentence_with_gap"] = gap_sentence
                else:
                    continue

            elif ex_type in ("reorder_words", "sentence_order"):
                words = ex.get("reorder_words") or ex.get("words")
                correct_order = ex.get("reorder_correct")
                correct_sentence = ex.get("correct_sentence") or ex.get("correct_answer")

                if not isinstance(words, list) or len(words) < 2:
                    continue

                if not isinstance(correct_order, list) and isinstance(correct_sentence, str):
                    tokens = [w.strip() for w in correct_sentence.split() if w.strip()]
                    correct_order = tokens

                if not isinstance(correct_order, list) or not correct_order:
                    continue

                ex_fixed["reorder_words"] = [str(w) for w in words]
                ex_fixed["reorder_correct"] = [str(w) for w in correct_order]
                if isinstance(correct_sentence, str) and correct_sentence.strip():
                    ex_fixed["correct_answer"] = correct_sentence.strip()

            elif ex_type == "open_answer":
                sample_answer = ex.get("sample_answer") or ex.get("sampleAnswer")
                evaluation = ex.get("evaluation_criteria") or ex.get("evaluationCriteria")
                if not isinstance(sample_answer, str) or not sample_answer.strip():
                    continue

                ex_fixed["sample_answer"] = sample_answer.strip()
                ex_fixed["evaluation_criteria"] = (
                    evaluation.strip()
                    if isinstance(evaluation, str) and evaluation.strip()
                    else "Оцените грамматику, лексику и связность ответа."
                )

            else:
                # неизвестный тип — пропускаем
                continue

            fixed_exercises.append(LessonExercise(**ex_fixed))

        if not fixed_exercises:
            logger.warning("[LESSON] no valid exercises, returning fallback lesson")
            return _fallback_lesson(req)

        return LessonContent(
            lesson_id=data["lesson_id"],
            lesson_title=data["lesson_title"],
            description=data["description"],
            exercises=fixed_exercises,
        )

    except Exception as e:
        logger.exception("[LESSON] generation failed, returning fallback: %s", e)
        return _fallback_lesson(req)
    
class CheckAnswerRequest(BaseModel):
    exercise_type: str
    question: str
    user_answer: str
    correct_answer: Optional[str] = None
    sample_answer: Optional[str] = None
    evaluation_criteria: Optional[str] = None
    language: str

class CheckAnswerResponse(BaseModel):
    is_correct: bool
    score: int  # 0–100
    feedback: str

@app.post("/check_answer", response_model=CheckAnswerResponse)
def check_answer(req: CheckAnswerRequest):
    try:
        user_payload = {
            "exercise_type": req.exercise_type,
            "question": req.question,
            "user_answer": req.user_answer,
            "correct_answer": req.correct_answer,
            "sample_answer": req.sample_answer,
            "evaluation_criteria": req.evaluation_criteria,
            "language": req.language,
        }

        content = llm_chat_completion(
            [
                {"role": "system", "content": ANSWER_CHECK_SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": json.dumps(user_payload, ensure_ascii=False),
                },
            ],
            temperature=0.2,
        )

        data = _parse_json_content(content)

        return CheckAnswerResponse(
            is_correct=bool(data.get("is_correct")),
            score=int(data.get("score", 0)),
            feedback=data.get("feedback", "No feedback"),
        )

    except Exception as e:
        logger.exception("[CHECK_ANSWER] failed: %s", e)
        return CheckAnswerResponse(
            is_correct=False,
            score=0,
            feedback="Could not evaluate answer. Please try again.",
        )




# ---------- Локальный запуск ----------

if __name__ == "__main__":
    import uvicorn

uvicorn.run(app, host=BACKEND_HOST, port=BACKEND_PORT)
