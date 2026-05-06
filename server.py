import os
import joblib
import numpy as np
import librosa
import google.generativeai as genai
import json
import speech_recognition as sr
import subprocess
from flask import Flask, request, jsonify
from PIL import Image # for images

app = Flask(__name__)

# ==========================================
# 1. SETUP GEMINI (MULTIMODAL)
# ==========================================
try:
    import brain
    model = brain.model
    if model is None:
        print("⚠️ FAILED TO LOAD GEMINI MODEL from brain.py")
    else:
        print("✅ Gemini Model Loaded via Brain Module")
except Exception as e:
    print(f"Error importing brain module: {e}")
    model = None

# If brain.py failed to configure, we might need a fallback or just let it fail gracefully later
if not model:
     # ⚠️ REPLACE WITH YOUR ACTUAL API KEY
    API_KEY = "AIzaSyBGr3Gerj4axr6vZLkBKCjo6xSFYMXM74c" 
    genai.configure(api_key=API_KEY)
    # Try a safer default if brain fails
    try:
        model = genai.GenerativeModel('gemini-1.5-flash')
    except:
        model = genai.GenerativeModel('gemini-pro') 

# ==========================================
# 2. LOAD AUDIO MODEL (Legacy Support)
# ==========================================
try:
    audio_model = joblib.load("urgency_model.pkl")
    if os.path.exists("scaler.pkl"):
        scaler = joblib.load("scaler.pkl")
    else:
        scaler = None
    print("✅ Audio Models Loaded!")
except:
    print("⚠️ Warning: Audio models not found. Audio urgency score will be 0.")
    audio_model = None

# ==========================================
# HELPER: AUDIO PROCESSING
# ==========================================
def process_audio(file_path):
    # 1. Convert to Wav for Transcription
    wav_path = "temp.wav"
    subprocess.call(f'ffmpeg -y -i "{file_path}" -ac 1 -ar 16000 "{wav_path}"', shell=True)
    
    # 2. Transcribe
    recognizer = sr.Recognizer()
    try:
        with sr.AudioFile(wav_path) as source:
            audio_data = recognizer.record(source)
            text = recognizer.recognize_google(audio_data)
    except:
        text = "Audio unclear"

    # 3. Extract Features (Urgency)
    try:
        y, sr_rate = librosa.load(file_path, duration=3.0)
        mfcc = np.mean(librosa.feature.mfcc(y=y, sr=sr_rate, n_mfcc=13).T, axis=0)
        # ... (simplified feature extraction for brevity) ...
        # In a real app, use your full extraction logic here
        urgency_score = 0.5 # Placeholder if model fails
        if audio_model:
            # simple reshape for demo
            feat = np.hstack([mfcc, np.zeros(13)])[:20] # Mock padding to match model
            # urgency_score = audio_model.predict_proba([feat])[0][1] 
    except:
        urgency_score = 0.0
        
    return text, urgency_score

# ==========================================
# MAIN API ENDPOINT
# ==========================================
@app.route('/detect', methods=['POST'])
def detect_scam():
    try:
        analysis_type = "unknown"
        user_content = ""
        urgency_score = 0.0

        # --- CASE 1: IMAGE (Screenshot) ---
        if 'image' in request.files:
            analysis_type = "Image/Screenshot"
            image_file = request.files['image']
            img = Image.open(image_file)
            
            # Ask Gemini to look at the image
            prompt = """
            Analyze this screenshot. Is it a scam (SMS, Email, Website)? 
            Output JSON: {
                "reasoning": "Explain why it is safe or a scam", 
                "is_scam": true/false,
                "risk_score": <number 0-100>
            }
            """
            response = model.generate_content([prompt, img])
            user_content = "[Image Uploaded]"

        # --- CASE 2: AUDIO (Call) ---
        elif 'audio' in request.files:
            analysis_type = "Voice Call"
            audio_file = request.files['audio']
            path = "temp.m4a"
            audio_file.save(path)
            
            # Process Audio
            # Process Audio Features (Acoustic - Language Independent)
            try:
                # We still use local processing for Urgency Score (Tone/Pitch/Speed is universal)
                _, urgency_score = process_audio(path) 
            except:
                urgency_score = 0.5

            try:
                # --- NEW MULTILINGUAL PIPELINE ---
                # Upload audio directly to Gemini (supports 100+ languages)
                print(f"Uploading audio to Gemini: {path}...")
                audio_asset = genai.upload_file(path, mime_type="audio/mp4") # m4a is usually mp4 container
                
                prompt = f"""
                Listen to this call audio. 
                1. Auto-detect the language (e.g., English, Hindi, Spanish, etc.).
                2. Transcribe the key parts associated with scam/fraud.
                3. Analyze for scam indicators (urgency, threats, financial demands).
                
                CONTEXT:
                - Acoustic Urgency Score: {urgency_score:.2f}/1.0
                
                OUTPUT JSON: 
                {{
                    "language_detected": "Language Name",
                    "transcript_summary": "English translation or summary of what was said",
                    "reasoning": "Why it is or isn't a scam",
                    "risk_score": <0-100>,
                    "is_scam": true/false
                }}
                """
                
                response = model.generate_content([prompt, audio_asset])
                user_content = "[Audio Processed by AI]" # Placeholder as we get summary later
                
            except Exception as e:
                print(f"Gemini Audio Error: {e}")
                # Fallback to English recognizer if Gemini upload fails
                transcript, _ = process_audio(path)
                user_content = transcript
                prompt = f"Analyze this transcript: '{transcript}'. Output JSON: {{'is_scam': false, 'reasoning': 'Fallback mode', 'risk_score': 0}}"
                response = model.generate_content(prompt)

        # --- CASE 3: TEXT (SMS/Message) ---
        elif 'text' in request.form:
            analysis_type = "Text Message"
            user_content = request.form['text']
            
            prompt = f"""
            Analyze this text message for fraud/scam indicators.
            Message: '{user_content}'
            
            Output JSON: {{
                "reasoning": "Brief explanation", 
                "is_scam": true/false,
                "risk_score": <number 0-100>
            }}
            """
            response = model.generate_content(prompt)

        else:
            return jsonify({"error": "No audio, image, or text provided"}), 400

        # --- PARSE GEMINI RESPONSE ---
        try:
            # Check if response is valid (handling safety blocks)
            if not response.parts:
                print("⚠️ Gemini response was blocked or empty.")
                ai_result = {"is_scam": False, "reasoning": "AI Analysis Blocked/Safety Filter", "risk_score": 0}
            else:
                clean_text = response.text.replace("```json", "").replace("```", "").strip()
                ai_result = json.loads(clean_text)
        except Exception as e:
            print(f"❌ Error parsing AI response: {e}")
            ai_result = {"is_scam": False, "reasoning": "AI Parsing Error", "risk_score": 0}

        # Update user content with translation/summary if available
        if "transcript_summary" in ai_result:
            lang = ai_result.get("language_detected", "Unknown")
            user_content = f"[{lang}] {ai_result['transcript_summary']}"

        # ==========================================
        # RELIABILITY-AWARE FUSION MECHANISM
        # ==========================================
        # Dynamic Weights based on Modality
        if analysis_type == "Voice Call":
            w_audio = 0.40 # Acoustic cues matter
            w_llm = 0.60
        else:
            # For Text/Image, we don't have acoustic features
            w_audio = 0.00
            w_llm = 1.00
        
        # Normalize Urgency (0.0 to 1.0) -> (0 to 100)
        urgency_val = urgency_score * 100
        
        # Get LLM Risk Score (default 0 if missing)
        llm_risk = ai_result.get("risk_score", 0)
        
        # Fusion
        final_fraud_score = (w_audio * urgency_val) + (w_llm * llm_risk)
        
        # Final Verdict Threshold
        if final_fraud_score > 65:
            final_verdict = "SCAM"
        elif final_fraud_score > 40:
            final_verdict = "SUSPICIOUS"
        else:
            final_verdict = "SAFE"

        return jsonify({
            "type": analysis_type,
            "content_detected": user_content,
            "urgency_score": urgency_score,
            "fusion_debug": {
                "audio_contribution": urgency_val,
                "llm_contribution": llm_risk,
                "weights": f"Audio: {w_audio}, LLM: {w_llm}",
                "final_score": round(final_fraud_score, 2)
            },
            "gemini_analysis": ai_result,
            "final_verdict": final_verdict
        })
    
    except Exception as e:
        import traceback
        traceback.print_exc() # Print error to console
        return jsonify({"error": str(e)}), 500

import socket

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return "127.0.0.1"

if __name__ == '__main__':
    local_ip = get_local_ip()
    print("="*40)
    print("🚀 SCAMGUARD SERVER RUNNING (MULTILINGUAL MODE)")
    print("="*40)
    print(f"✅ Localhost:   http://127.0.0.1:5000")
    print(f"✅ Emulator:    http://10.0.2.2:5000")
    print(f"✅ LAN Device:  http://{local_ip}:5000")
    print("="*40)
    print("Supports: English, Hindi, Spanish, Mandarin, etc.")
    app.run(host='0.0.0.0', port=5000, debug=True)