#!/usr/bin/env python3
"""
TTS Daemon - A persistent process that keeps the model loaded in memory
"""
import os
import sys
import time
import json
import logging
import signal
from pathlib import Path

# Add Qwen3-TTS to path
sys.path.insert(0, '/home/embistel/Calliope/Qwen3-TTS')

import torch
import soundfile as sf
from qwen_tts import Qwen3TTSModel

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/home/embistel/Calliope/tts_daemon.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class TTSDaemon:
    def __init__(self):
        self.model = None
        self.model_path = "/home/embistel/Calliope/Qwen3-TTS/Model/Qwen3-TTS"
        self.device = "cuda:0" if torch.cuda.is_available() else "cpu"
        self.request_dir = Path("/tmp/tts_requests")
        self.response_dir = Path("/tmp/tts_responses")
        self.health_file = Path("/tmp/tts_daemon_ready")
        self.running = True
        
        # Create directories
        self.request_dir.mkdir(exist_ok=True)
        self.response_dir.mkdir(exist_ok=True)
        
        # Setup signal handlers
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        logger.info(f"Received signal {signum}, shutting down...")
        self.running = False
    
    def load_model(self):
        """Load the TTS model once and keep it in memory"""
        if self.model is not None:
            logger.info("Model already loaded")
            return
            
        logger.info("="*60)
        logger.info("Loading Qwen3-TTS model...")
        logger.info(f"Model path: {self.model_path}")
        logger.info(f"Device: {self.device}")
        logger.info("="*60)
        
        try:
            t0 = time.time()
            self.model = Qwen3TTSModel.from_pretrained(
                self.model_path,
                device_map=self.device,
                dtype=torch.bfloat16 if self.device.startswith("cuda") else torch.float32,
                trust_remote_code=True,
            )
            t1 = time.time()
            logger.info(f"Model loaded successfully in {t1 - t0:.2f}s")
            logger.info("TTS Daemon ready to serve requests!")
            
            # Create health check file
            with open(self.health_file, 'w') as f:
                f.write(f"ready:{time.time()}")
            logger.info(f"Health check file created: {self.health_file}")
            
        except Exception as e:
            logger.error(f"Failed to load model: {str(e)}")
            raise
    
    def generate_audio(self, request_data):
        """Generate audio from text using the loaded model"""
        if self.model is None:
            raise RuntimeError("Model not loaded")
        
        text = request_data.get('text', '')
        language = request_data.get('language', 'Korean')
        speaker = request_data.get('speaker', 'Sohee')
        instruct = request_data.get('instruct', '밝고 명랑한 목소리로 말해주세요')
        max_new_tokens = request_data.get('max_new_tokens', 2048)
        
        logger.info(f"Generating audio: {text[:50]}...")
        
        try:
            t0 = time.time()
            wavs, sr = self.model.generate_custom_voice(
                text=text,
                language=language,
                speaker=speaker,
                instruct=instruct,
                max_new_tokens=max_new_tokens,
            )
            t1 = time.time()
            
            logger.info(f"Audio generated in {t1 - t0:.2f}s")
            return wavs[0], sr, t1 - t0
            
        except Exception as e:
            logger.error(f"Failed to generate audio: {str(e)}")
            raise
    
    def process_request(self, request_file):
        """Process a single TTS request"""
        try:
            # Read request
            with open(request_file, 'r', encoding='utf-8') as f:
                request_data = json.load(f)
            
            # Generate audio
            wav_data, sr, generation_time = self.generate_audio(request_data)
            
            # Save audio file
            output_path = request_data.get('output_path')
            if output_path:
                sf.write(output_path, wav_data, sr)
                logger.info(f"Audio saved to: {output_path}")
            
            # Create response
            response_file = self.response_dir / request_file.name
            response_data = {
                'status': 'success',
                'output_path': output_path,
                'sample_rate': sr,
                'duration': len(wav_data) / sr,
                'generation_time': generation_time
            }
            
            with open(response_file, 'w') as f:
                json.dump(response_data, f)
            
            # Remove request file
            request_file.unlink()
            
        except Exception as e:
            logger.error(f"Error processing request {request_file}: {str(e)}")
            
            # Create error response
            response_file = self.response_dir / request_file.name
            response_data = {
                'status': 'error',
                'error': str(e)
            }
            
            try:
                with open(response_file, 'w') as f:
                    json.dump(response_data, f)
                request_file.unlink()
            except Exception as e2:
                logger.error(f"Failed to create error response: {str(e2)}")
    
    def run(self):
        """Main daemon loop"""
        logger.info("Starting TTS Daemon...")
        
        # Load model
        self.load_model()
        
        # Main processing loop
        while self.running:
            try:
                # Check for new requests
                request_files = list(self.request_dir.glob("*.json"))
                
                for request_file in request_files:
                    if not self.running:
                        break
                    self.process_request(request_file)
                
                # Sleep briefly to avoid high CPU usage
                time.sleep(0.1)
                
            except Exception as e:
                logger.error(f"Error in main loop: {str(e)}")
                time.sleep(1)
        
        logger.info("TTS Daemon stopped")

if __name__ == "__main__":
    daemon = TTSDaemon()
    daemon.run()