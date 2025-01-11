#!/bin/sh

export DATABASE_URL=sqlite://./db/chatbot.db

export OPENAI_API_KEY="7b88f72bc8434619b74860824ff5fb9c"
export OPENAI_API_BASE="https://prosa-openai.openai.azure.com/"
export OPENAI_API_TYPE="azure"
export OPENAI_EMBEDDING_DEPLOYMENT_NAME="prosa-text-embedding"
export OPENAI_CHAT_DEPLOYMENT_NAME="prosa-text-gpt4o"
# export OPENAI_CHAT_DEPLOYMENT_NAME="prosa-text-1"
export OPENAI_API_VERSION="2023-05-15"

export QDRANT_URL="http://localhost:6334"          # URL for local Docker deployment
export QDRANT_COLLECTION_NAME="chatbot_collection" # Name for your vector collection

export JINA_API_KEY="jina_ae389feeac554dea93297f9afd32cc2583fmfPfLMsBGmUzUCawX_Zj021mR"
export JINA_RERANK_URL="https://api.jina.ai/v1/rerank"
export JINA_MODEL="jina-reranker-v2-base-multilingual"

export DEFAULT_SCENARIO=default
export RERANKER_TOP_K=10
export RERANKER_SCORE_THRESHOLD=0.10

zig build run
