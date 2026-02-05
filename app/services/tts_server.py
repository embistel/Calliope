#!/usr/bin/env python3
"""
FastAPI server for Qwen3-TTS model with model persistence in memory
"""
import sys
import os
import logging
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import Optional
import torch
import soundfile as sf
import io

# Add Qwen3-TTS to path
sys.path.insert(0, '/home/embistel/Calliope/Qwen3-TTS')
from qwen_tts import Qwen3TTSModel

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(title="Qwen3-TTS Server", version="1.0.0")

# Global model cache
_tts_model = None
_device = None

# Request/Response models
class TTSRequest(BaseModel):
    text: str
    language: str = "Korean"
    speaker: str = "Sohee"
    instruct: str = "밝고 명랑한 목소리로 말해주세요"
    max_new_tokens: int = 2048

class TTSResponse(BaseModel):
    status: str
    duration: float
    sample_rate: int
    samples: int

@app.on_event("startup")
async def startup_event():
    """Load model on startup and keep in memory"""
    global _tts_model, _device
    
    logger.info("="*60)
    logger.info("Starting Qwen3-TTS Server")
    logger.info("="*60)
    
    # Determine device
    _device = "cuda:0" if torch.cuda.is_available() else "cpu"
    logger.info(f"Using device: {_device}")
    
    # Set HF_HOME to project directory to avoid permission issues
    os.environ['HF_HOME'] = '/home/embistel/Calliope/.cache/huggingface'
    os.makedirs('/home/embistel/Calliope/.cache/huggingface', exist_ok=True)
    
    # Model path - use Hugging Face model hub directly
    MODEL_PATH = "Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice"
    
    logger.info("Loading Qwen3-TTS model...")
    logger.info(f"Model path: {MODEL_PATH}")
    
    try:
        import time
        t0 = time.time()
        
        _tts_model = Qwen3TTSModel.from_pretrained(
            MODEL_PATH,
            device_map=_device,
            dtype=torch.bfloat16 if _device.startswith("cuda") else torch.float32,
            trust_remote_code=True,
        )
        
        t1 = time.time()
        logger.info(f"Model loaded successfully in {t1 - t0:.2f}s")
        logger.info("Server ready to accept requests!")
    except Exception as e:
        logger.error(f"Failed to load model: {str(e)}")
        raise

@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "ready",
        "model": "Qwen3-TTS-12Hz-1.7B-CustomVoice",
        "device": _device
    }

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "ready",
        "model_loaded": _tts_model is not None,
        "device": _device
    }

@app.post("/generate", response_model=TTSResponse)
async def generate(request: TTSRequest):
    """Generate audio from text"""
    if _tts_model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    logger.info("="*60)
    logger.info("Generating audio")
    logger.info(f"Text: {request.text}")
    logger.info(f"Language: {request.language}")
    logger.info(f"Speaker: {request.speaker}")
    logger.info(f"Instruct: {request.instruct}")
    logger.info(f"Text length: {len(request.text)} characters")
    logger.info("="*60)
    
    try:
        import time
        t0 = time.time()
        
        # Generate audio
        wavs, sr = _tts_model.generate_custom_voice(
            text=request.text,
            language=request.language,
            speaker=request.speaker,
            instruct=request.instruct,
            max_new_tokens=request.max_new_tokens,
        )
        
        t1 = time.time()
        generation_time = t1 - t0
        
        logger.info(f"Audio generated in {generation_time:.2f}s: {len(wavs)} samples, sample rate: {sr}")
        
        # Save to temporary file
        import tempfile
        import os
        
        temp_dir = "/tmp/tts_audio"
        os.makedirs(temp_dir, exist_ok=True)
        
        with tempfile.NamedTemporaryFile(
            delete=False, 
            suffix='.wav', 
            dir=temp_dir
        ) as temp_file:
            sf.write(temp_file.name, wavs[0], sr, format='WAV')
            temp_file_path = temp_file.name
        
        duration = len(wavs[0]) / sr
        
        logger.info(f"Total duration: {duration:.3f}s")
        logger.info(f"Saved to: {temp_file_path}")
        logger.info("="*60)
        
        # Return file (FastAPI will clean up the temp file)
        return FileResponse(
            temp_file_path,
            media_type="audio/wav",
            filename="generated_audio.wav",
            headers={
                "X-Generation-Time": str(generation_time),
                "X-Duration": str(duration),
                "X-Sample-Rate": str(sr),
            }
        )
        
    except Exception as e:
        logger.error(f"Failed to generate audio: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    # Run with uvicorn
    uvicorn.run(
        "tts_server:app",
        host="127.0.0.1",
        port=8000,
        log_level="info"
    )