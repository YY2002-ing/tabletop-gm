#!/bin/bash
cd "$(dirname "$0")/剧场"
open "http://localhost:8767" 2>/dev/null || true
exec python3 serve.py
