# Landing Agent — Kaizen

## Read these first
1. /CLAUDE.md — project overview, pricing, tone
2. /docs/design-tokens.json — Focus theme colours + fonts

---

## Stack
Pure HTML · Tailwind CSS (CDN) · Alpine.js (CDN)
**No build step. No npm. Single file: `landing/index.html`**

---

## Design system (Focus theme)
```
Background: #141009
Surface:    #241D11
Text:       #F6EFE1
Accent:     #D9F24B  (lime — buttons, highlights)
Ember:      #FF6A3D  (urgent, price badge)
Display font: Fraunces (Google Fonts CDN)
Body font:    Hanken Grotesk (Google Fonts CDN)
```

---

## Page sections (in order)

### 1. Hero
- Headline: **"The planner that never lets the important stuff slip."**
- Subhead: "Auto-reschedules your day around what matters. Built for students."
- Smart **[Download]** button (Alpine.js, see below)
- Phone mockup image or simple screenshot placeholder

### 2. Problem / Solution (3 cards)
| Pain | Kaizen fix |
|------|-------------|
| You plan the day. One thing breaks it. Nothing gets done. | Morning review auto-reschedules around your priorities. |
| You forget what actually matters vs. what just feels urgent. | Up to 3 "Main" tasks — protected, always first. |
| You don't know *why* your plans keep failing. | Diary + patterns show exactly what derails you. |

### 3. Features (3 tiles)
- **Morning review** — "Yesterday's loose ends, sorted before 9am."
- **Streak ring** — "See your progress, protect your streak."
- **Tone toggle** — "Gentle nudges or brutal honesty — your call." (show gentle/harsh toggle mockup)

### 4. Pricing
| Free | Premium $10/mo |
|------|---------------|
| Rule-based rescheduling | AI-powered smart plans |
| Streaks + ring | Multiple plan variants |
| Basic diary | Deep diary insights |
| Ads (non-intrusive) | No ads |

CTA: **[Start Free]** + **[Go Premium]**

### 5. Footer
- Logo + tagline
- Links: App Store · Play Store · Web App · Privacy · Terms
- Email: hello@kaizen.com (placeholder)

---

## Smart Download button (Alpine.js)
```javascript
// Detect platform and redirect
function getDownloadUrl() {
  const ua = navigator.userAgent;
  if (/iPad|iPhone|iPod/.test(ua)) {
    return 'https://apps.apple.com/app/kaizen';     // placeholder
  } else if (/Android/.test(ua)) {
    return 'https://play.google.com/store/apps/kaizen'; // placeholder
  } else {
    return 'https://app.kaizen.com';                  // placeholder
  }
}
```

---

## Rules
- Mobile responsive — use Tailwind responsive prefixes (sm: md: lg:)
- No external images — use CSS/SVG placeholders for mockups
- Placeholder store links are fine — they'll be updated post-launch
- Keep it fast — CDN only, no custom JS bundle
- Tone: confident, warm, student-facing — matches the app's "gentle" voice
