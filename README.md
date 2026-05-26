# 🛡️ ScamGuard: Tri-Modal AI Fraud Detection System

![Python](https://img.shields.io/badge/Python-3.9+-blue.svg)
![Flask](https://img.shields.io/badge/Framework-Flask-lightgrey.svg)
![Flutter](https://img.shields.io/badge/Frontend-Flutter-02569B.svg)
![Gemini](https://img.shields.io/badge/AI-Google_Gemini_1.5_Flash-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

**ScamGuard** is a real-time, cross-platform mobile cybersecurity application designed to proactively detect and prevent financial fraud, social engineering, and voice phishing (vishing) attacks. 

Unlike traditional security apps that rely on static, easily-spoofed blacklists, ScamGuard utilizes a **Reliability-Aware Tri-Modal Fusion Architecture** to analyze the *behavior* and *intent* of an interaction across Voice, Text, and Visual data streams.

---

## ✨ Key Features

* **🎙️ Acoustic Forensics (Tone Analysis):** Uses local Edge processing (Librosa + Random Forest) to extract Mel-Frequency Cepstral Coefficients (MFCCs) and detect vocal urgency, aggression, and panic.
* **🧠 Contextual Reasoning (LLM Intent):** Integrates Google Gemini 1.5 Flash to perform deep semantic reasoning on transcripts, catching logical fallacies and manipulation tactics (e.g., a "Bank Manager" asking for Gift Cards).
* **👁️ Visual Phishing Detection:** Analyzes uploaded screenshots of fake banking receipts, malicious SMS links, and phishing emails using Multimodal Vision AI.
* **🌐 Multilingual Support:** Automatically detects and analyzes scams across 100+ languages (English, Hindi, Spanish, Mandarin, etc.) using the Gemini audio pipeline.
* **🔒 Privacy-First Edge-Cloud Hybrid:** Raw audio is processed ephemerally on the user's local device (Edge). Only anonymized mathematical feature vectors and transcripts are sent to the cloud. No audio is stored.
* **🗣️ Explainable AI (XAI):** Doesn't just say "Scam." Provides natural language explanations to the user detailing *why* an interaction is dangerous.

---

## 🏗️ System Architecture

ScamGuard operates on a hybrid deployment pipeline balancing latency and computational load:

1. **Edge Processor (Mobile Device):** Handles Voice Activity Detection (VAD), audio normalization, and lightweight MFCC extraction. 
2. **Cloud Reasoning Engine (Flask Server):** Receives features, generates transcripts, and passes data to the Large Language Model (Gemini) for logical analysis.
3. **Reliability-Aware Fusion Engine (RAFE):** Dynamically weights the Acoustic Score and the Semantic Score depending on data quality (e.g., relying more on text if background street noise is high).

---

## 🛠️ Tech Stack

* **Frontend:** Flutter (Dart)
* **Backend:** Python, Flask
* **Machine Learning / AI:** * Google Generative AI (`gemini-1.5-flash`)
  * Scikit-Learn (Random Forest)
* **Audio Processing:** Librosa, FFmpeg, SpeechRecognition

---

## 🚀 Installation & Setup (Backend)

### Prerequisites
* Python 3.9+
* [FFmpeg](https://ffmpeg.org/download.html) installed and added to your system PATH.
* A valid Google Gemini API Key.

### 1. Clone the Repository
```bash
git clone [https://github.com/yourusername/ScamGuard.git](https://github.com/yourusername/ScamGuard.git)
cd ScamGuard/backend
