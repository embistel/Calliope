# coding=utf-8
# Qwen3-TTS 더빙 테스트 예제
import time
import torch
import soundfile as sf

from qwen_tts import Qwen3TTSModel


def main():
    # GPU 설정
    device = "cuda:0"
    MODEL_PATH = "Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice"

    print("모델 로딩 중...")
    tts = Qwen3TTSModel.from_pretrained(
        MODEL_PATH,
        device_map=device,
        dtype=torch.bfloat16,
        # attn_implementation="flash_attention_2",  # FlashAttention 2 미설치 시 주석 처리
    )
    print("모델 로딩 완료!")

    # -------- 한국어 더빙 테스트 --------
    print("\n한국어 더빙 테스트 시작...")
    torch.cuda.synchronize()
    t0 = time.time()

    wavs, sr = tts.generate_custom_voice(
        text="안녕하세요, 반갑습니다. 오늘 날씨가 정말 좋네요.",
        language="Korean",
        speaker="Sohee",  # 한국어 네이티브 스피커
        instruct="밝고 명랑한 목소리로 말해주세요",
    )

    torch.cuda.synchronize()
    t1 = time.time()
    print(f"한국어 더빙 완료! 소요 시간: {t1 - t0:.3f}s")

    output_file = "qwen3_tts_korean_dubbing.wav"
    sf.write(output_file, wavs[0], sr)
    print(f"오디오 파일 저장 완료: {output_file}")

    # -------- 영어 더빙 테스트 --------
    print("\n영어 더빙 테스트 시작...")
    torch.cuda.synchronize()
    t0 = time.time()

    wavs, sr = tts.generate_custom_voice(
        text="Hello everyone, welcome to our presentation today.",
        language="English",
        speaker="Ryan",  # 영어 네이티브 스피커
        instruct="Professional and confident tone",
    )

    torch.cuda.synchronize()
    t1 = time.time()
    print(f"영어 더빙 완료! 소요 시간: {t1 - t0:.3f}s")

    output_file = "qwen3_tts_english_dubbing.wav"
    sf.write(output_file, wavs[0], sr)
    print(f"오디오 파일 저장 완료: {output_file}")

    # -------- 중국어 더빙 테스트 --------
    print("\n중국어 더빙 테스트 시작...")
    torch.cuda.synchronize()
    t0 = time.time()

    wavs, sr = tts.generate_custom_voice(
        text="大家好，欢迎使用我们的产品。",
        language="Chinese",
        speaker="Vivian",  # 중국어 네이티브 스피커
        instruct="温和友好的语气",
    )

    torch.cuda.synchronize()
    t1 = time.time()
    print(f"중국어 더빙 완료! 소요 시간: {t1 - t0:.3f}s")

    output_file = "qwen3_tts_chinese_dubbing.wav"
    sf.write(output_file, wavs[0], sr)
    print(f"오디오 파일 저장 완료: {output_file}")

    print("\n모든 더빙 테스트 완료!")


if __name__ == "__main__":
    main()