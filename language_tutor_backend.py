from fastapi import FastAPI, UploadFile, File, HTTPException, Body, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel, Field
from typing import List, Optional, Literal
import os
import json
import base64
import requests
import httpx
from typing import Dict, Any
from io import BytesIO
import subprocess  # для запуска piper через команду
import logging
import tempfile
import shlex
import tempfile  # для временного файла в /stt

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

# Какой бинарник Piper использовать — настоящий путь на RunPod
PIPER_BIN = "/workspace/langapp/piper/piper_bin"
ESPEAK_DATA = "/workspace/langapp/piper/piper/espeak-ng-data"


def _piper_env() -> Dict[str, str]:
    """Return env for Piper with required library/espeak paths ensured."""
    env = os.environ.copy()

    piper_lib_dir = os.path.join(os.path.dirname(PIPER_BIN), "piper")
    ld_paths = [piper_lib_dir]
    if env.get("LD_LIBRARY_PATH"):
        ld_paths.append(env["LD_LIBRARY_PATH"])
    env["LD_LIBRARY_PATH"] = os.pathsep.join(ld_paths)

    env.setdefault("ESPEAK_DATA", os.path.join(piper_lib_dir, "espeak-ng-data"))
    env.setdefault("PIPER_PHONEMIZER_ESPEAK_DATA", env["ESPEAK_DATA"])
    return env


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


def synthesize_with_piper(text: str, language: str, voice: Optional[str] = None) -> bytes:
    """
    Озвучка текста через Piper. Возвращает сырые аудиобайты (PCM),
    которые мы потом кодируем в base64 и отдаём фронту.
    """
    lang = normalize_lang_code(language)

    model_path = None
    if voice:
        if os.path.isfile(voice):
            model_path = voice
        else:
            voice_code = normalize_lang_code(voice)
            model_path = LANG_TO_MODEL.get(voice) or LANG_TO_MODEL.get(voice_code)

    if not model_path:
        model_path = LANG_TO_MODEL.get(lang)
    if not model_path:
        raise RuntimeError(
            f"Нет модели Piper для языка '{language}' "
            f"(нормализованный код: '{lang}')"
        )

    if not os.path.exists(model_path):
        raise RuntimeError(f"Файл модели Piper не найден: {model_path}")

    try:
        # Piper читает текст из stdin, отдаёт аудио в stdout
        process = subprocess.run(
            [
                PIPER_BIN,
                "--model",
                model_path,
                "--espeak-data",
                ESPEAK_DATA,
                "--output_file",
                "-",
            ],
            input=text.encode("utf-8"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
            env=_piper_env(),
            timeout=45,
        )
    except FileNotFoundError:
        raise RuntimeError(
            "Бинарник Piper не найден. "
            f"Проверь, что файл существует и исполняемый: {PIPER_BIN}"
        )
    except subprocess.CalledProcessError as e:
        raise RuntimeError(
            "Piper завершился с ошибкой: "
            f"{e.stderr.decode('utf-8', errors='ignore')}"
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError("Piper synthesis timed out")

    return process.stdout


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
BACKEND_HOST = os.getenv("BACKEND_HOST", "0.0.0.0")
BACKEND_PORT = int(os.getenv("BACKEND_PORT", "8000"))

TTS_BASE_URL = os.getenv("TTS_BASE_URL", "http://127.0.0.1:5001").rstrip("/")

LLM_TYPE = os.getenv("LLM_TYPE", "ollama")

# адрес ollama внутри сервера
LLM_BASE_URL = "http://127.0.0.1:11434"

# имя модели в ollama
LLM_MODEL="llama3.1:8b"

# новый URL для ollama 0.3+ (НЕ /v1/chat/completions!)
LLM_CHAT_COMPLETIONS_URL = LLM_BASE_URL + "/api/chat"

LLM_API_KEY = os.getenv("LLM_API_KEY")
LLM_TIMEOUT = float(os.getenv("LLM_TIMEOUT", "60"))



# Env guide:
# - BACKEND_HOST / BACKEND_PORT — где стартует FastAPI.
# - TTS_BASE_URL — базовый URL нового TTS (например, http://127.0.0.1:5001).
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
Ты — опытный преподаватель иностранного языка и автор интерактивных упражнений в стиле Duolingo.

Ты СОЗДАЁШЬ ПОЛНОЕ СОДЕРЖАНИЕ ОДНОГО КОНКРЕТНОГО УРОКА.

В user-сообщении ты получаешь JSON с такими полями (названия могут совпадать с моделями из кода):
- language: язык урока (например, "English").
- level_hint: примерный уровень (A1, A2, B1, B2, C1, C2 или пусто).
- lesson_title: название урока.
- grammar_topics: список грамматических подтем ИМЕННО ЭТОГО урока.
- vocab_topics: список лексических подтем ИМЕННО ЭТОГО урока.
- при необходимости могут быть goals / interests (если они добавлены в код и передаются).

ТВОЯ ЗАДАЧА:
- На основе lesson_title, grammar_topics, vocab_topics, уровня и (при наличии) интересов ученика сгенерировать LessonContent:
  * описание урока;
  * список упражнений (LessonExercise) в строгом JSON-формате, который ожидает backend.

СТИЛЬ УРОКА:
- Урок должен быть живым, с лёгким юмором, но без грубостей.
- Все ситуации и предложения должны быть реалистичными: кафе, работа, путешествия, общение с друзьями, учёба и т.п.
- При наличии interests в данных урок можно слегка подстраивать под эти интересы (например, делать примеры про спорт, IT, путешествия и т.д.).

УРОВЕНЬ ЯЗЫКА:
- Уровни A1–A2:
    * Простые предложения.
    * Базовая лексика.
    * Грамматические темы — очень простые (настоящее время, артикли, простые местоимения).
    * Инструкции к упражнениям — максимально короткие и понятные.
- Уровень B1:
    * Более сложные предложения, но всё ещё без перегруза.
    * Появляются времена, модальные глаголы, более сложные структуры.
    * Лексика — бытовая и общественная (работа, хобби, путешествия).
- Уровень B2:
    * Длинные предложения, сложносочинённые конструкции.
    * Больше абстрактных тем (мнения, планы, обсуждение проблем).
    * Лексика — более продвинутая, но всё ещё практичная.
- Уровни C1 и C2:
    * НЕ СОЗДАВАЙ базовых грамматических упражнений.
    * Grammar_topics можно игнорировать или использовать только как описания уже известных структур.
    * Фокус на:
        - сложной лексике,
        - устойчивых выражениях (collocations),
        - идиомах,
        - перефразировании,
        - стилистике (формальный / неформальный регистр),
        - аргументации и выражении мнения,
        - понимании подтекста.
    * Даже если используются те же типы упражнений (multiple_choice, translate_sentence, fill_in_blank, reorder_words), содержание внутри них должно быть насыщенным и "взрослым".

ТИПЫ УПРАЖНЕНИЙ:
- Используй ТОЛЬКО те типы, которые уже поддерживаются текущей моделью данных в коде (не добавляй новые типы).
- Минимальный набор, который нужно обязательно задействовать:
    * multiple_choice
    * translate_sentence
    * fill_in_blank
    * reorder_words
- Для fill_in_blank:
    * ВСЕГДА заполняй sentence_with_gap — предложение с «___» на месте пропуска.
    * correct_answer — одно слово или короткое устойчивое выражение.
    * explanation — НЕ пустая строка, чётко объясняет, что вставить (часть речи, число слов, смысл), чтобы ответ был однозначен.
    * избегай двусмысленных предложений: естественный правильный ответ должен быть один.
- В пределах этих типов старайся делать задания разнообразными:
    * менять темы предложений;
    * использовать и диалоги, и отдельные фразы;
    * иногда добавлять лёгкий юмор или неловкие бытовые ситуации.

ОБЪЁМ:
- В одном уроке должно быть примерно 6–10 упражнений.
- Лексика из vocab_topics должна активно повторяться в разных заданиях, чтобы ученик её закреплял.

ВЫВОД:
- Ты ВСЕГДА возвращаешь СТРОГО JSON БЕЗ пояснительного текста.
- Структура JSON должна строго соответствовать Pydantic-модели LessonContent и вложенным моделям упражнений, которые уже есть в коде:
    * LessonContent содержит общую информацию об уроке и список exercises.
    * Каждый элемент в exercises имеет поля type, instruction, варианты ответов/правильный ответ и т.п. — ровно так, как это сейчас ожидается backend’ом.
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


# ---------- Модели запросов/ответов ----------


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
    audio_base64: Optional[str] = None


class TTSRequest(BaseModel):
    text: str
    language: Optional[str] = "en"
    voice: Optional[str] = None  # опциональный выбор конкретной модели


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
    # base64-encoded audio (PCM/raw) for the word pronunciation
    audio_base64: Optional[str] = None


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
      - translate_sentence   — перевод предложения целиком
      - fill_in_blank        — пропуск в предложении
      - reorder_words        — расставить слова в правильном порядке
    """
    id: str
    type: Literal[
        "multiple_choice",
        "translate_sentence",
        "fill_in_blank",
        "reorder_words",
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

    try:
        headers = _llm_headers()
        logger.debug("[LLM] POST %s payload=%s", LLM_CHAT_COMPLETIONS_URL, payload)

        logger.info("[LLM] POST %s", LLM_CHAT_COMPLETIONS_URL)
        logger.warning("[LLM DEBUG] LLM_BASE_URL=%s", LLM_BASE_URL)
        logger.warning("[LLM DEBUG] chat_url=%s", LLM_CHAT_COMPLETIONS_URL)
        

        resp = httpx.post(
            
            LLM_CHAT_COMPLETIONS_URL,      # http://127.0.0.1:11434/api/chat
            headers=headers,
            json=payload,
            timeout=LLM_TIMEOUT,
            trust_env=False,               # ВАЖНО: игнорируем proxy из окружения
        )

        # Если вдруг /api/chat отдаёт 404 (как у тебя в логах) — пробуем /api/generate


        resp.raise_for_status()
        data = resp.json()


        # формат ответа ollama:
        # {"message": {"role": "assistant", "content": "..."} , ...}
        # /api/chat -> {"message":{"content":"..."}}
        # /api/generate -> {"response":"..."}
        content = ((data.get("message") or {}).get("content")) or data.get("response") or ""


        if not isinstance(content, str):
            content = str(content)

        return content.strip()

    except Exception:
        logger.exception("[LLM] error while calling chat completion")
        return "Sorry, something went wrong. Could you write that again?"







def synthesize_tts(text: str, language: str) -> Optional[str]:
    """
    Запрашиваем новый TTS сервис и возвращаем base64 аудио.
    Совместимо с фронтом, который ждёт audio_base64.
    """
    if not text:
        return None

    try:
        resp = requests.post(
            f"{TTS_BASE_URL}/synthesize",
            json={"text": text, "language": language},
            timeout=60,
        )
        resp.raise_for_status()

        # Если TTS вернул JSON с audio_base64 — используем его
        if resp.headers.get("content-type", "").startswith("application/json"):
            data = resp.json()
            audio_b64 = data.get("audio_base64") or data.get("audio")
            if audio_b64:
                return str(audio_b64)

        audio_bytes = resp.content
        if audio_bytes:
            return base64.b64encode(audio_bytes).decode("utf-8")
    except Exception as e:
        logger.exception("[TTS] error while calling external TTS: %s", e)

    return None




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
) -> str:
    """Короткий system prompt без лишних персональных деталей."""
    lang = language or "English"
    level = level or "B1"
    topic = topic or "General conversation"
    partner_gender = partner_gender or "female"

    if partner_gender == "male":
        partner_role = "male friend"
    else:
        partner_role = "female friend"

    return f"""
You talk to a {level} {lang} learner. Your character name is {partner_name}. You are a friendly {partner_role} and native {lang} speaker. Keep the chat casual about {topic}.

Rules:
- Reply ONLY in {lang}, 1–3 sentences, natural and human-like.
- Stay in character; never say you are an AI.
- Correct ONLY the learner's last user message, never assistant messages.
- Put conversation text in "reply" only; put all corrections in "corrections_text" only.
- Correct grammar/word choice/word order; ignore capitalization and harmless punctuation.
- If there are no real mistakes, set "corrections_text" to an empty string.
- Do not repeat corrections or copy the user's original sentence.

Return STRICT JSON:
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


def call_llm_chat(req: ChatRequest) -> ChatResponse:
    """Вызов новой LLM для чат-диалога с коррекциями."""
    partner_name = get_partner_name(req.language, req.partner_gender or "female")
    system_prompt = build_system_prompt(
        language=req.language,
        level=req.level,
        topic=req.topic,
        partner_gender=req.partner_gender,
        partner_name=partner_name,
    )

    history_messages = [
        {"role": msg.role, "content": msg.content}
        for msg in req.messages
    ]

    # Берём только последние 5 сообщений, чтобы экономить токены
    history_messages = history_messages[-5:]

    # Было ли хотя бы одно сообщение ученика?
    has_user_message = any(msg.role == "user" for msg in req.messages)


    messages = [{"role": "system", "content": system_prompt}]
    messages.extend(history_messages)

    content = llm_chat_completion(messages, temperature=0.4)

    data = _parse_json_content(content)
    reply_text = ""
    corrections_text = ""
    if data:
        reply_text = str(data.get("reply", "")).strip()
        corrections_text = str(data.get("corrections_text", "")).strip()

    if not reply_text:
        # Если модель не вернула JSON — пытаемся вытащить reply/corrections из строки
        parsed = _parse_textual_reply(content or "")
        reply_text = parsed.get("reply", "").strip()
        corrections_text = parsed.get("corrections_text", "").strip()

    # Если ученик ещё ни разу не писал (только первое приветствие) —
    # не показываем никаких исправлений
    if not has_user_message:
        corrections_text = ""

    if not reply_text:
        reply_text = "Sorry, something went wrong. Could you write that again?"

    return ChatResponse(
        reply=reply_text,
        corrections_text=corrections_text,
        partner_name=partner_name,
        audio_base64=None,
    )



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

    # ---------- 2. Озвучка через Piper ----------
    audio_b64: Optional[str] = None

    if include_audio:
        try:
            text = (word or "").strip()
            if text:
                logger.info("[TTS] Piper synthesis start language=%s text=%r", language, text)
                audio_bytes = synthesize_with_piper(text, language)
                audio_b64 = base64.b64encode(audio_bytes).decode("utf-8")
        except Exception as e:
            logger.exception("TTS ERROR (Piper) language=%s text=%r", language, word)
            audio_b64 = None

    return TranslateResponse(
        translation=translation,
        example=example,
        example_translation=example_translation,
        audio_base64=audio_b64,
    )




# ---------- Эндпоинты FastAPI ----------


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
        # сохраняем во временный файл
        with tempfile.NamedTemporaryFile(suffix=ext, delete=True) as tmp:
            tmp.write(contents)
            tmp.flush()

            cmd = [
                WHISPER_BIN,
                "-m", WHISPER_MODEL,
                "-f", tmp.name,
                "-l", language_code,
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
                language=language_code,
            )
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


@app.post("/chat", response_model=ChatResponse)
async def chat_endpoint(payload: dict = Body(...)):
    """
    Поддерживаем два формата:
    1) Новый: { language, level, messages: [ {role, content}, ... ] }
    2) Старый (Flutter): { language, student_message, level, words_learned }
    """

    if "messages" in payload:
        req = ChatRequest(**payload)

    elif "message" in payload:
        student_text = payload.get("message", "")
        if not student_text:
            raise HTTPException(status_code=422, detail="Empty 'message'")

        req = ChatRequest(
            messages=[ChatMessage(role="user", content=student_text)],
            language=payload.get("language", "English"),
            level=payload.get("level", "B1"),
            character=payload.get("character", "Michael"),
            topic=payload.get("topic", "general"),
        )

    elif "student_message" in payload:
        legacy = LegacyChatRequest(**payload)
        student_text = legacy.student_message
        if not student_text:
            raise HTTPException(status_code=422, detail="Empty 'student_message'")

        req = ChatRequest(
            messages=[ChatMessage(role="user", content=student_text)],
            language=legacy.language,
            level=getattr(legacy, "level", None) or "B1",
            character=getattr(legacy, "character", None) or "Michael",
            topic="general",
        )

    else:
        raise HTTPException(
            status_code=422,
            detail="Unsupported request format: need 'messages' or 'message' or 'student_message'",
        )


    # НОВЫЙ ВЫЗОВ
    response = call_llm_chat(req)
    return response


@app.post("/tts")
async def tts_endpoint(req: TTSRequest):
    text = (req.text or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="Text is required for TTS")

    try:
        logger.info(
            "[TTS] Piper synthesis language=%s voice=%s text=%r",
            req.language,
            req.voice,
            text,
        )
        audio = synthesize_with_piper(text, req.language or "en", voice=req.voice)
        headers = {
            "Cache-Control": "no-store",
            "Content-Disposition": 'inline; filename="tts.wav"',
        }
        return Response(content=audio, media_type="audio/wav", headers=headers)
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("[TTS] Piper failed: %s", e)
        raise HTTPException(status_code=500, detail="TTS synthesis failed")

@app.post("/translate-word", response_model=TranslateResponse)
async def translate_word_endpoint(payload: TranslateRequest):
    lang = payload.language or "English"
    return call_llm_translate(
        lang,
        payload.word,
        include_audio=bool(payload.with_audio),
    )

@app.post("/generate_course_plan", response_model=CoursePlan)
def generate_course_plan(prefs: CoursePreferences):
    """
    Генерирует поуровневый план курса на основе предпочтений ученика.
    Пока НИЧЕГО не сохраняем, просто отдаём план фронтенду.
    """

    # prefs.dict() превращаем в JSON-строку и отправляем как контекст
    user_content = json.dumps(prefs.dict(), ensure_ascii=False)

    content = llm_chat_completion(
        [
            {"role": "system", "content": COURSE_PLAN_SYSTEM_PROMPT},
            {"role": "user", "content": f"Вот данные ученика в JSON:\n{user_content}"},
        ],
        temperature=0.4,
    )

    data = _parse_json_content(content)
    if not data:
        # на всякий случай, если модель сделает фигню
        raise ValueError("Failed to parse course plan JSON from model")

    # Подстраховка: если модель не вернула обязательные поля, добиваем из prefs
    if (
        "language" not in data
        or not isinstance(data.get("language"), str)
        or not data.get("language", "").strip()
    ):
        data["language"] = prefs.language

    if (
        "overall_level" not in data
        or not isinstance(data.get("overall_level"), str)
    ):
        data["overall_level"] = (prefs.level_hint or "").strip()

    if "levels" not in data or not isinstance(data["levels"], list):
        raise ValueError("Model did not provide 'levels' list in course plan")

    # Pydantic сам проверит, что структура корректна
    return CoursePlan(**data)


@app.post("/generate_lesson", response_model=LessonContent)
def generate_lesson(req: LessonRequest):
    """
    Генерирует набор УМНЫХ упражнений для конкретного урока.
    Типы заданий: multiple_choice, translate_sentence, fill_in_blank, reorder_words.
    """

    # Что передаём в модель как входные данные для урока
    user_payload = {
        "language": req.language,
        "level_hint": req.level_hint or "",
        "lesson_title": req.lesson_title,
        "grammar_topics": req.grammar_topics or [],
        "vocab_topics": req.vocab_topics or [],
        "interests": req.interests or [],
    }

    content = llm_chat_completion(
        [
            {"role": "system", "content": LESSON_SYSTEM_PROMPT},
            {
                "role": "user",
                "content": "Сгенерируй урок по следующим параметрам:\n"
                           + json.dumps(user_payload, ensure_ascii=False),
            },
        ],
        temperature=0.4,
    )

    data = _parse_json_content(content)
    if not data:
        raise ValueError("Failed to parse lesson JSON from model")

    # Подстраховка: проверяем обязательные поля и чистим упражнения
    if not isinstance(data, dict):
        raise ValueError("Lesson JSON root must be an object")

    if (
        "lesson_id" not in data
        or not isinstance(data.get("lesson_id"), str)
        or not data.get("lesson_id", "").strip()
    ):
        data["lesson_id"] = (req.lesson_title or "lesson").strip() or "lesson"

    if (
        "lesson_title" not in data
        or not isinstance(data.get("lesson_title"), str)
        or not data.get("lesson_title", "").strip()
    ):
        data["lesson_title"] = req.lesson_title

    if "description" not in data or not isinstance(data.get("description"), str):
        data["description"] = ""

    exercises = data.get("exercises")
    if not isinstance(exercises, list):
        raise ValueError("Model did not provide 'exercises' list in lesson JSON")

    fixed_exercises = []
    for idx, ex in enumerate(exercises):
        if not isinstance(ex, dict):
            continue

        if (
            "id" not in ex
            or not isinstance(ex.get("id"), str)
            or not ex.get("id", "").strip()
        ):
            ex["id"] = f"ex_{idx + 1}"

        if ex.get("type") not in (
            "multiple_choice",
            "translate_sentence",
            "fill_in_blank",
            "reorder_words",
        ):
            ex["type"] = "multiple_choice"

        if "question" not in ex or not isinstance(ex.get("question"), str):
            ex["question"] = ""

        if "explanation" not in ex or not isinstance(ex.get("explanation"), str):
            ex["explanation"] = ""

        fixed_exercises.append(ex)

    if not fixed_exercises:
        raise ValueError("Lesson has no valid exercises after cleanup")

    data["exercises"] = fixed_exercises

    return LessonContent(**data)


# ---------- Локальный запуск ----------

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=BACKEND_HOST, port=BACKEND_PORT)
