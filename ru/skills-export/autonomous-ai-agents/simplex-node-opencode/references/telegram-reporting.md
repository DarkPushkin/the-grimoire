# Telegram Reporting Workflow — Saint Mary Liberty Island

## Context
All build, audit, evolution, and cycle reports for the simplex-node project must be delivered to the Telegram bot with inline buttons. The user explicitly requires this for every significant update.

## Bot Credentials
- **Bot token**: `8863122561:AAE520N_2s_PF6P_qx3CwwTbHE0VQvt_DhQ`
- **Chat ID**: `143293811`
- **Bot username**: `@hermes_knndpol6k2bduche_bot`

## Required Inline Keyboard Buttons
Every status report must include these 4 buttons:
```
[Build Status] [Next Steps]
[Report Bug]  [Feedback]
```

## API Call Template
```bash
curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d '{
    "chat_id": "'${CHAT_ID}'",
    "text": "REPORT TEXT HERE",
    "reply_markup": {
      "inline_keyboard": [
        [{"text": "Build Status", "callback_data": "build_status"}, {"text": "Next Steps", "callback_data": "next_steps"}],
        [{"text": "Report Bug", "callback_data": "report_bug"}, {"text": "Feedback", "callback_data": "feedback"}]
      ]
    }
  }'
```

## Content Structure
Reports should be plain text (not Markdown, not HTML) to avoid parse errors:
1. **Header** — what happened (e.g., "ROYAL APP EVOLUTION - BUILD SUCCESSFUL")
2. **Body** — bullet points of changes, results, or observations
3. **Footer** — project signature (e.g., "Saint Mary Liberty Island - Royal Control vA2.0")

## Markdown Note
If using `parse_mode: "Markdown"`, watch for special characters in paths (underscores, asterisks). Paths like `../main.dart` contain underscores that break Markdown parsing. When in doubt, use plain text.

## When to Report
- **Build success/failure** — always report the result with inline buttons
- **Evolution cycle step** — after completing any major step in the production cycle
- **Bug discovery** — report with "Report Bug" button pre-selected context
- **Phase completion** — milestone or major phase done

## Token Safe Storage
The token is stored in `~/.config/opencode-telegram-bot.token` and chat ID in `~/.config/opencode-telegram-bot.chat`.
The bot info is also saved in Hermes memory and in the `simplex-node-opencode` skill's references.