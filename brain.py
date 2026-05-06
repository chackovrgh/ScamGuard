import google.generativeai as genai
import json

# ==========================================
# CONFIGURATION
# ==========================================
API_KEY = "AIzaSyBGr3Gerj4axr6vZLkBKCjo6xSFYMXM74c"  # <--- Paste your key here again

genai.configure(api_key=API_KEY)

def get_best_model():
    """
    Automatically finds a working model so you don't get 404 errors.
    """
    print("Searching for available models...")
    try:
        available_models = []
        for m in genai.list_models():
            if 'generateContent' in m.supported_generation_methods:
                available_models.append(m.name)
        
        # Priority list (Try these in order)
        preferred = [
            "models/gemini-1.5-flash", 
            "models/gemini-1.5-flash-latest", 
            "models/gemini-1.5-pro",
            "models/gemini-pro"
        ]
        
        for p in preferred:
            if p in available_models:
                print(f"✅ Found Model: {p}")
                return genai.GenerativeModel(p)
        
        # Fallback: Just take the first available one
        if available_models:
            print(f"⚠️ specific flash model not found. Using: {available_models[0]}")
            return genai.GenerativeModel(available_models[0])
            
    except Exception as e:
        print(f"Error finding models: {e}")
        return None

# Initialize Model ONCE
model = get_best_model()

def analyze_scam(text_transcript, audio_urgency_score):
    if not model:
        return {"error": "No AI model found. Check API Key.", "is_scam": False}

    # 1. Define Risk
    audio_risk = "LOW"
    if audio_urgency_score > 0.6: audio_risk = "MEDIUM"
    if audio_urgency_score > 0.8: audio_risk = "CRITICAL"

    # 2. Prompt
    prompt = f"""
    Analyze this call/message for scam indicators. Output JSON only.
    
    INPUT:
    - Text: "{text_transcript}"
    - Audio Urgency: {audio_urgency_score}/1.0 ({audio_risk})
    
    ANALYSIS TASKS:
    1. Detect scam-related keywords and financial intent.
    2. Identify psychological triggers (urgency, fear, greed).
    3. Perform contextual reasoning to find LOGICAL INCONSISTENCIES (e.g., authority misuse, abnormal payment requests).
    
    OUTPUT FORMAT:
    {{
        "reasoning": "Brief explanation highlighting logical inconsistencies or triggers",
        "scam_likelihood": "LOW/MEDIUM/HIGH",
        "confidence_score": <number 0-100 indicating confidence in the verdict>,
        "risk_score": <number 0-100 indicating fraud risk>,
        "is_scam": true/false
    }}
    """
    
    try:
        response = model.generate_content(prompt)
        clean_text = response.text.replace("```json", "").replace("```", "").strip()
        return json.loads(clean_text)
    except Exception as e:
        return {"error": str(e), "is_scam": False}

# ==========================================
# TEST
# ==========================================
if __name__ == "__main__":
    if model:
        fake_text = "Hello sir, I am calling from your bank. Verify your card details now."
        print("\nTesting Brain...")
        result = analyze_scam(fake_text, 0.89)
        print(json.dumps(result, indent=2))
    else:
        print("CRITICAL ERROR: Could not connect to Google AI.")