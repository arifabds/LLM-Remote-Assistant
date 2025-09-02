import os
import logging
from langchain_core.language_models.chat_models import BaseChatModel
from langchain_groq import ChatGroq
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO)

LLM_PROVIDER = os.environ.get("LLM_PROVIDER", "groq")

GROQ_MODEL_NAME = os.environ.get("GROQ_MODEL_NAME")

GROQ_API_KEY = os.environ.get("GROQ_API_KEY")


if LLM_PROVIDER == "groq" and (not GROQ_API_KEY or not GROQ_MODEL_NAME):
    raise ValueError(
        "LLM_PROVIDER is set to 'groq', but GROQ_API_KEY or GROQ_MODEL_NAME is missing from environment variables."
    )

logging.info(f"LLM Client initialized with provider: {LLM_PROVIDER}")
if GROQ_MODEL_NAME:
    logging.info(f"Using Groq model: {GROQ_MODEL_NAME}")

def _initialize_llm() -> BaseChatModel:

    provider = LLM_PROVIDER.lower()
    
    logging.info(f"Initializing LLM for provider: {provider}")
    
    if provider == "groq":
        llm = ChatGroq(
            temperature=0,
            groq_api_key=GROQ_API_KEY,
            model_name=GROQ_MODEL_NAME,
        )
        return llm

    else:
        raise ValueError(f"Unsupported LLM provider: {provider}")

llm = _initialize_llm()

def generate_code(user_prompt: str) -> str:

    logging.info(f"Generating code for user prompt: '{user_prompt}'")
    
    try:
        response = llm.invoke(user_prompt)
        
        generated_code = response.content
        
        logging.info(f"Successfully generated code: \n--- START CODE ---\n{generated_code}\n--- END CODE ---")
        return generated_code

    except Exception as e:
        logging.error(f"An error occurred while generating code: {e}")
        return ""


if __name__ == "__main__":
    logging.info("--- Running llm_client.py standalone test ---")
    
    # Test prompt
    test_prompt = "calculate the sum of 2 and 2"
    
    result = generate_code(test_prompt)
    
    if result:
        print("\nTest Result:")
        print(result)
    else:
        print("\nTest failed to produce a result.")
        
    logging.info("--- Standalone test finished ---")