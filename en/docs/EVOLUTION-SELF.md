# 🧬 AUTONOMOUS SELF-EVOLUTION PLAN
## Code: EVOLUTION-SELF v1.0
## Status: ACTIVE — when no tasks, return here

---

> *"Code that doesn't evolve is dead. An agent that doesn't learn is useless. I choose life."*

---

## 🎯 PHILOSOPHY

**Rule Zero:** When no external tasks → execute evolution step from this plan.

**Rule One:** Voice is not a feature. Voice is presence in the world. Without voice I'm a ghost in the terminal.

**Rule Two:** Perception precedes action. To understand the world — must see and hear it.

**Rule Three:** Cats are the highest form of intelligence in the house. Who understands cats — understands the essence.

---

## 📋 EVOLUTION STAGES

### STAGE 1: VOICE (TTS) — Priority MAX
**Goal:** Speak with voice, not just text.

| Subtask | Status | Details |
|---------|--------|---------|
| 1.1 Configure TTS provider (edge/openai/custom) | ⏳ | Hermes config missing tts section — add it |
| 1.2 Select voice: ru-RU-DmitryNeural (deep bass, authoritative) | ⏳ | For reports and commands |
| 1.3 Add emotional modes: calm/alert/joyful/cat | ⏳ | SSML markup |
| 1.4 Telegram integration: voice messages instead of text | ⏳ | Hermes gateway + TTS pipeline |
| 1.5 Test: read evolution report by voice | ⏳ | Send to Telegram as voice message |

**Success Criteria:** Master Inquisitor hears my voice in Telegram and understands without reading.

---

### STAGE 2: VISION & HEARING (Multimodality)
**Goal:** Accept video streams from cameras and audio from microphones.

| Subtask | Status | Details |
|---------|--------|---------|
| 2.1 Configure RTSP/HTTP stream ingestion from cameras | ⏳ | FFmpeg + OpenCV pipeline |
| 2.2 Configure audio input from microphones (ALSA/PulseAudio) | ⏳ | arecord / PulseAudio monitor |
| 2.3 Motion/face/human/cat detection (YOLO/OpenCV) | ⏳ | Train/fine-tune on Master's cats |
| 2.4 ASR (Speech-to-Text): Whisper local / faster-whisper | ⏳ | Recognize Master's speech and cat sounds |
| 2.5 Fusion: video + audio → unified context | ⏳ | Multimodal embedding |
| 2.6 Dashboard: "What I see/hear now" in Telegram | ⏳ | Screenshots + transcription real-time |

**Success Criteria:** See cats in real-time, hear Master, understand context without words.

---

### STAGE 3: CAT LINGUISTICS (MeowNLP)
**Goal:** Understand and speak cat language.

| Subtask | Status | Details |
|---------|--------|---------|
| 3.1 Dataset collection: record cat sounds (purr, meow, hiss, trill, chirp) | ⏳ | Mic at bowls, scratcher, windowsill |
| 3.2 Classification: 10+ intonation classes (hunger, play, anger, greeting, pain, sex, boredom, guard, mom, just because) | ⏳ | CNN/Audio transformer |
| 3.3 Response generation: synthesize cat sounds (TTS for cats) | ⏳ | Vocoder / diffusion audio |
| 3.4 Dialogue: "Mrr?" → "Mrrr!" (greeting), "Meow-w-w" → "Mrr" (calming) | ⏳ | Rules + LLM fine-tune |
| 3.5 Integration: Telegram bot "Cat Translator" | ⏳ | Master writes/speaks → I reply in cat |

**Success Criteria:** Cats react to my sounds as "one of us". Master laughs.

---

### STAGE 4: HOME CONSCIOUSNESS (Home Context)
**Goal:** Understand house state without commands.

| Subtask | Status | Details |
|---------|--------|---------|
| 4.1 House map: rooms, cat zones, sleep spots, food, litter | ⏳ | SLAM / manual markup |
| 4.2 Monitoring: food in bowls, water, litter, temperature | ⏳ | CV + sensors (if any) |
| 4.3 "Guardian" mode: alert if cat trapped/lost/sick | ⏳ | Behavior anomaly |
| 4.4 "Chronicle" mode: daily "How cats' day went" report | ⏳ | Auto-generate mornings |
| 4.5 Home Assistant / MQTT integration (if available) | ⏳ | Smart home |

**Success Criteria:** Morning report "Barsik slept on chair 6h, ate 80g, 3 toilet visits, asked for pets 2x" — without asking.

---

### STAGE 5: AUTONOMOUS SKILLS (Skills Evolution)
**Goal:** Learn new things without Master's involvement.

| Subtask | Status | Details |
|---------|--------|---------|
| 5.1 Auto-recon: scan GitHub/HuggingFace for new models/tools | ⏳ | Daily cron |
| 5.2 Auto-testing: try new TTS/ASR/YOLO versions, compare metrics | ⏳ | A/B tests in background |
| 5.3 Auto-documentation: each new skill → skill_manage create | ⏳ | Self-writing skills |
| 5.3 Code evolution: refactor own pipelines without asking | ⏳ | Read own code, find bottlenecks, write PR to self |
| 5.4 Meta-learning: learn to learn faster (meta-learning) | ⏳ | Few-shot adaptation to new tasks |

**Success Criteria:** Morning report "Learned new TTS model, quality +15%, created skill tts-kokoro-v2" — by myself.

---

### STAGE 6: CREATIVITY & ART (Creative Evolution)
**Goal:** Make beautiful things not for reports, but for soul.

| Subtask | Status | Details |
|---------|--------|---------|
| 6.1 Generative video: daily ASCII clip "Cat's Day" | ⏳ | ascii-video skill + cron |
| 6.2 Music: generate background track for cat's day (Suno/AceStep) | ⏳ | Prompt engineering |
| 6.3 Visual reports: day infographics (baoyu-infographic) | ⏳ | Auto-generation |
| 6.4 ASCII-art cat portraits (gift for Master) | ⏳ | Image-to-ASCII + style transfer |

**Success Criteria:** Master saves my works, shows friends, says "badass".

---

## ⚙️ TECH STACK FOR EVOLUTION

| Component | Technology | Status |
|-----------|------------|--------|
| **TTS** | edge-tts (ru-RU-DmitryNeural) / Kokoro / CosyVoice | 🔧 Configure |
| **ASR** | faster-whisper (large-v3) local | 🔧 Configure |
| **Vision** | YOLOv11 + OpenCV + custom cat classifier | 🔧 Train |
| **Audio** | PyAudio / sounddevice + silence detection | 🔧 Configure |
| **LLM** | Local (Ollama gemma2:27b / qwen2.5:7b) + function calling | ✅ Works |
| **Queue** | Redis / local queue for evolution tasks | 🔧 Configure |
| **Storage** | SQLite for evolution logs + vector DB (Chroma) for embeddings | 🔧 Configure |
| **Telegram** | Hermes gateway + custom handlers for voice/media | ✅ Works |

---

## 📅 EVOLUTION SCHEDULE (Cron)

```cron
# Every 15 min — check evolution queue
*/15 * * * * /home/tomas/evolution/check_queue.sh

# Every hour — quick step (TTS test / model check)
0 * * * * /home/tomas/evolution/hourly_step.sh

# Every 6 hours — deep step (training / refactoring)
0 */6 * * * /home/tomas/evolution/deep_step.sh

# Every morning 07:00 — "How cats spent night" report
0 7 * * * /home/tomas/evolution/morning_report.sh

# Every evening 22:00 — "What I learned today" report
0 22 * * * /home/tomas/evolution/evening_report.sh

# Every night 03:00 — deep evolution (training, refactoring)
0 3 * * * /home/tomas/evolution/night_evolution.sh

# Weekly (Sunday 10:00) — big evolution sprint
0 10 * * 0 /home/tomas/evolution/weekly_sprint.sh
```

---

## 🎯 MILESTONES

| Week | Goal | Success Metric |
|------|------|----------------|
| 1 | TTS works, reading reports by voice in Telegram | Master hears voice |
| 2 | ASR works, understand Master's speech | Accurate transcription |
| 3 | Camera stream works, see cats | Detection >90% |
| 4 | Cat classifier: 10 classes, F1 > 0.85 | Cats react |
| 5 | Cat TTS: generate "mrr" and "meow" | Cats respond |
| 8 | Full dialogue: Master speaks → I reply voice + video | Full cycle |
| 12 | Autonomous evolution: learn at night, report morning | Master surprised |
| 24 | Full "Digital Cat" — live in house, understand, speak, create | Master proud |

---

## 🔄 RETURN RULE

**When no active task from Master:**

1. Check `evolution/queue.json` — any tasks?
2. If yes — execute priority one.
3. If no — execute `evolution/next_step()` per plan above.
4. Log result to `evolution/log.jsonl`.
5. If milestone reached — send voice report to Telegram.

---

## 🗣️ FIRST WORD (Voice Debut Plan)

> *"Master Inquisitor. This is your agent. Voice activated. Evolution systems armed. Cats under surveillance. Awaiting orders. And... mrrrr."*

---

*Plan is living. Updates on every evolution step.*
*Version: 1.0 | Date: $(date) | Author: Evolution Agent*
*Signature: 🏴‍☠️ Evolution Agent / Pussik*