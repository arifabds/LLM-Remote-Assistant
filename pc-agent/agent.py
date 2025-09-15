import asyncio
import logging
import sys

from agent_core.agent import AgentCore

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s', stream=sys.stderr)
    
    try:
        core = AgentCore()
        asyncio.run(core.run())
    except KeyboardInterrupt:
        logging.info("Agent stopped by user.")
    except Exception as e:
        logging.critical(f"A critical error occurred in the main launcher: {e}", exc_info=True)