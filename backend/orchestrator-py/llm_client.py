import os
import logging
from langchain_core.language_models.chat_models import BaseChatModel
from langchain_groq import ChatGroq
from dotenv import load_dotenv
import prompts
import re

load_dotenv()
logging.basicConfig(level=logging.INFO)

LLM_PROVIDER = os.environ.get("LLM_PROVIDER", "groq")
GROQ_API_KEY = os.environ.get("GROQ_API_KEY")
GROQ_MODEL_NAME = os.environ.get("GROQ_MODEL_NAME")
SECURITY_LLM_API_KEY = os.environ.get("SECURITY_LLM_API_KEY", GROQ_API_KEY)
SECURITY_LLM_MODEL_NAME = os.environ.get("SECURITY_LLM_MODEL_NAME")

if not all([GROQ_API_KEY, GROQ_MODEL_NAME, SECURITY_LLM_API_KEY, SECURITY_LLM_MODEL_NAME]):
    raise ValueError("One or more required LLM environment variables are missing.")

logging.info(f"Main LLM: {GROQ_MODEL_NAME} | Security LLM: {SECURITY_LLM_MODEL_NAME}")

def _initialize_llm(api_key: str, model_name: str) -> BaseChatModel:
    if LLM_PROVIDER.lower() == "groq":
        return ChatGroq(temperature=0, groq_api_key=api_key, model_name=model_name)
    else:
        raise ValueError(f"Unsupported LLM provider: {LLM_PROVIDER}")
    
def _clean_llm_json_response(response_text: str) -> str:
    match = re.search(r"```(json)?\s*(\{.*?\})\s*```", response_text, re.DOTALL)
    if match:
        return match.group(2)
    
    match = re.search(r"(\{.*?\})", response_text, re.DOTALL)
    if match:
        return match.group(1)
        
    return response_text

main_llm = _initialize_llm(GROQ_API_KEY, GROQ_MODEL_NAME)
security_llm = _initialize_llm(SECURITY_LLM_API_KEY, SECURITY_LLM_MODEL_NAME)

code_generation_chain = prompts.CODE_GENERATION_PROMPT | main_llm
security_analysis_chain = prompts.SECURITY_ANALYSIS_PROMPT | security_llm

def generate_code(user_prompt: str) -> str:
    logging.info(f"Generating code for: '{user_prompt}'")
    try:
        response = code_generation_chain.invoke({"user_prompt": user_prompt})
        cleaned_response = _clean_llm_json_response(response.content)
        logging.info(f"Code generation response (cleaned): {cleaned_response}")
        return cleaned_response
    except Exception as e:
        logging.error(f"Error during code generation: {e}")
        return ""

def analyze_code_with_llm(intent: str, code: str) -> str:
    logging.info(f"Analyzing code with security LLM for intent: '{intent}'")
    try:
        response = security_analysis_chain.invoke({"intent": intent, "code": code})
        cleaned_response = _clean_llm_json_response(response.content)
        logging.info(f"Security analysis response (cleaned): {cleaned_response}")
        return cleaned_response
    except Exception as e:
        logging.error(f"Error during security analysis: {e}")
        return ""