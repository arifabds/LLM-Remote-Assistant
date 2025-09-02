#!/bin/sh

echo "Starting gRPC server..."
python main.py &

echo "Starting FastAPI server..."
uvicorn main:app --host 0.0.0.0 --port 8000 --reload