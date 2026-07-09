# Accessibility Audit — Driver + Maintenance In-Scope Screens

> Generated: Step 1 findings before fixes. Step 2 applies the fixes below in priority order.

---

## 1. ActiveNavigationDetailView.swift

### VoiceOver Labels Missing

| Line | Element | Issue |
|------|---------|-------|
| 704–718 | Call Manager phone button | Icon-only button (`phone.fill`) with no `.accessibilityLabel`. VoiceOver sees "phone.fill" only. |
| 745–760 | Pause / Resume button | Icon-only button (`play.fill` / `pause.fill`) that changes icon on state, no `.accessibilityLabel` or `.accessibilityValue`. VoiceOver can't discover the action. |
| 634 | Drag handle capsule | Decorative — OK. |
| 673 | Bottom-bar tap gesture | `onTapGesture` on the ETA/Distance/Speed bar toggles `isExpanded` but is invisible to VoiceOver. The gesture area lacks `.accessibilityAddTraits(.isButton)`. |
| 858–891 | Jerk countdown overlay | Custom overlay, not a native alert. Countdown number updates every second but VoiceOver never announces the change. The "I'm OK — Cancel" button lacks a label. `.accessibilityAddTraits(.isModal)` needed to trap focus. |

### Fixed-Size Fonts (vs Dynamic Type)

| Line | Font | Suggestion |
|------|------|------------|
| 519 | `.system(size: 16, weight: .bold)` | Replace with `.headline` |
| 643, 653, 663 | `.system(size: 26, weight: .bold, design: .rounded)` (×3) | Replace with `.title1` |
| 646, 657, 667 | `.system(size: 11, weight: .bold)` (×3) | Replace with `.caption` |
| 865 | `.system(size: 48)` (jerk icon) | Decorative — add `.minimumScaleFactor(0.5)` |
| 1142 | `.system(size: 11, weight: .black, design: .rounded)` (slide-to-cancel) | Replace with `.caption` + weight `.black` |

### Tap Targets < 44×44pt

| Line | Element | Size |
|------|---------|------|
| 706–708 | Call Manager phone button | 38×38pt |
| 752–755 | Pause/Resume circle button | 38×38pt |

### Contrast Risks — Gray on Light Background

| Line | Text | Background |
|------|------|------------|
| 873 | `.foregroundColor(.secondary)` — jerk countdown cancel instruction | `.regularMaterial` (adapts, likely OK) |

### Alerts / Sheets

- **SOS alert** (line 848): standard `Alert`, OK.
- **Reroute confirm** (line 838): standard `Alert`, OK.
- **Cancellation sheet** (line 893): standard sheet, OK.
- **Jerk countdown overlay** (line 858): custom ZStack — VoiceOver focus is not trapped; countdown value not announced.

---

## 2. FuelHistoryView.swift + OCRReviewView

### VoiceOver Labels Missing

| Line | Element | Issue |
|------|---------|-------|
| 322–331 | PhotosPicker label | `Image(systemName:)` icon changes on state (photo.badge.plus → checkmark.circle.fill) but no `.accessibilityLabel` on the label content. |
| 241–258 | Locked state lock icon | `Image("lock.fill")` — decorative, but if left accessible it reads "lock.fill". |

### Fixed-Size Fonts

| Line | Font | Suggestion |
|------|------|------------|
| 245 | `.system(size: 48)` (lock icon) | Decorative — OK |
| 269 | `.system(size: 36, weight: .heavy, design: .rounded)` (range km) | Replace with `.largeTitle` + weight |

### Tap Targets < 44×44pt

No interactive controls below 44pt found in FuelHistoryView.

### Contrast Risks — Gray on Light Background

| Line | Text | Background |
|------|------|------------|
| 339 | `.foregroundColor(.secondary)` — scanning text | systemBackground (white) — borderline at smallest sizes |
| 348 | `.foregroundColor(.secondary)` — OCR failed text | systemBackground — borderline |

### Alerts / Sheets

- **`showingSavedAlert`** (line 173): standard `Alert`, OK.
- **`showingSaveError`** (line 180): standard `Alert` with dynamic message, OK.
- **OCRReviewView** (line 501): standard sheet with `Form` + `TextField`s. Each field's placeholder serves as a11y hint. ✅

---

## 3. CompleteWorkOrderView.swift

### VoiceOver Labels Missing

| Line | Element | Issue |
|------|---------|-------|
| 87 | Plus button ("Add Parts") | `Image("plus.circle.fill")` with no `.accessibilityLabel`. VoiceOver sees only the icon name. |
| 123–127 | Minus stepper button | `Image("minus")` — icon-only, no label. |
| 131–135 | Plus stepper button | `Image("plus")` — icon-only, no label. |
| 145–149 | Trash/remove part button | `Image("trash.fill")` — icon-only, no label. |
| 229–234 | Remarks TextEditor | Has placeholder behavior but no explicit `.accessibilityLabel`. The character count (`236–238`) updates without announcement. |

### Fixed-Size Fonts

| Line | Font | Suggestion |
|------|------|------------|
| 33 | `.system(size: 20, weight: .bold, design: .rounded)` (title) | Replace with `.title2` |
| 38 | `.system(size: 15, weight: .medium, design: .rounded)` (description) | Replace with `.body` |
| 54, 84 | `.system(size: 16, weight: .bold, design: .rounded)` (section headers) | Replace with `.headline` |
| 101, 111 | `.system(size: 15, weight: .bold, design: .rounded)` (part name / amount) | Replace with `.body` |
| 115 | `.system(size: 11, weight: .medium, design: .rounded)` (unit price) | Replace with `.caption` |
| 125, 134 | `.system(size: 12, weight: .bold)` (stepper icons) | Add `.minimumScaleFactor(0.7)` |
| 130 | `.system(size: 14, weight: .bold, design: .rounded)` (quantity) | Replace with `.body` or `.subheadline` |
| 148 | `.system(size: 16)` (trash icon) | Add `.minimumScaleFactor(0.7)` |
| 166 | `.system(size: 11, weight: .bold, design: .rounded)` (TOTAL PARTS COST) | Replace with `.caption` |
| 169 | `.system(size: 16, weight: .bold, design: .rounded)` (total amount) | Replace with `.headline` |
| 182 | `.system(size: 16, weight: .bold, design: .rounded)` (Labour Cost header) | Replace with `.headline` |
| 187, 191 | `.system(size: 20, weight: .bold)` (₹ / labor cost) | Replace with `.title2` |
| 197 | `.system(size: 14, weight: .semibold, design: .monospaced)` (elapsed time) | Replace with `.subheadline` |
| 214 | `.system(size: 12, weight: .medium, design: .rounded)` (calc note) | Replace with `.caption` |
| 222 | `.system(size: 16, weight: .bold, design: .rounded)` (Remarks header) | Replace with `.headline` |
| 225 | `.system(size: 13, weight: .medium, design: .rounded)` ("(Optional)") | Replace with `.subheadline` |
| 231 | `.system(size: 15, design: .rounded)` (TextEditor) | Replace with `.body` |
| 237 | `.system(size: 11, weight: .bold, design: .rounded)` (char count) | Replace with `.caption` |
| 249 | `.system(size: 11, weight: .bold, design: .rounded)` (SUMMARY) | Replace with `.caption` |
| 255, 264 | `.system(size: 14, weight: .medium, design: .rounded)` (Parts/Labour Cost label) | Replace with `.subheadline` |
| 259, 268 | `.system(size: 14, weight: .bold, design: .rounded)` (cost values) | Replace with `.subheadline` weight `.bold` |
| 276 | `.system(size: 18, weight: .bold, design: .rounded)` (Total Cost label) | Replace with `.title3` |
| 280 | `.system(size: 28, weight: .black, design: .rounded)` (total cost value) | Replace with `.largeTitle` weight `.black` |
| 303 | `.system(size: 18, weight: .bold, design: .rounded)` (Complete button) | Replace with `.headline` |
| 326 | `.system(size: 16, weight: .bold)` (toolbar title) | Replace with `.headline` |

### Tap Targets < 44×44pt

| Line | Element | Size |
|------|---------|------|
| 123–127 | Minus stepper | 24×24pt |
| 131–135 | Plus stepper | 24×24pt |
| 145–149 | Remove part (trash) | ~32×32pt (8pt padding) |
| 87 | Add parts plus button | `font(.system(size: 24))` — hit area <44pt |

### Contrast Risks — Gray on Light Background

| Line | Text | Background |
|------|------|------------|
| 39 | `Color.gray` — description | White card — **FAIL WCAG AA normal text** |
| 116 | `Color.gray` — unit price | White card — small text, **FAIL** |
| 125 | `Color.gray` — minus icon | #E8EAED capsule — icon, borderline |
| 167 | `Color.gray` — "TOTAL PARTS COST" | White card — **FAIL** |
| 188 | `Color.gray` — "₹" symbol | White card — **FAIL** |
| 198 | `Color.gray` — elapsed time capsule text | #E8EAED back — **FAIL** |
| 215 | `Color.gray` — calc note | White card — small, **FAIL** |
| 226 | `Color.gray` — "(Optional)" | White card — **FAIL** |
| 238 | `Color.gray` — char count | #E8EAED — **FAIL** |
| 250 | `Color.gray` — "SUMMARY" | White card — **FAIL** |
| 256, 265 | `Color.gray` — "Parts Cost" / "Labour Cost" | White card — **FAIL** |

### Alerts / Sheets

- **"Notice" error alert** (line 384): standard, OK.
- **"Voice Action" alert** (line 389): standard, OK.
- **AddPartsSheet** (line 379): standard sheet, OK.

---

## 4. AddPartsSheet.swift

### VoiceOver Labels Missing

| Line | Element | Issue |
|------|---------|-------|
| 42–49 | Dismiss (xmark) button | Icon-only. VoiceOver reads "xmark". Needs `.accessibilityLabel("Close")`. |
| 88–100 | "Add" button per row | Text label "Add" exists, but doesn't say which part. Should use `accessibilityLabel("Add \(part.name)")`. |

### Fixed-Size Fonts

| Line | Font | Suggestion |
|------|------|------------|
| 39 | `.system(size: 20, weight: .bold)` (title) | Replace with `.title2` |
| 44 | `.system(size: 16, weight: .bold)` (xmark icon) | Decorative, OK |
| 74 | `.system(size: 16, weight: .bold)` (part name) | Replace with `.body` weight `.bold` |
| 77 | `.system(size: 14)` (unit price) | Replace with `.subheadline` |
| 85 | `.system(size: 12, weight: .medium)` (stock count) | Replace with `.caption` |
| 93 | `.system(size: 12, weight: .bold)` (Add button text) | Replace with `.caption` weight `.bold` |

### Tap Targets < 44×44pt

| Line | Element | Size |
|------|---------|------|
| 42–48 | Dismiss (xmark) | 36×36pt |

### Contrast Risks — Gray on Light Background

| Line | Text | Background |
|------|------|------------|
| 56 | Search icon `Color.gray` | White — decorative icon, OK |
| 78 | Unit price `Color.gray` | White row — **FAIL** |
| 86 | Stock count `Color.gray` | White row — **FAIL** |
| 94 | Add button disabled text `Color.gray` | Gray opacity 0.1 back — **FAIL** (already disabled state, lower priority) |
| 99 | Disabled state on Add button | Applies `.disabled` — OK |

---

## Summary of Findings

| Category | Count (in-scope) |
|----------|------------------|
| Missing VoiceOver labels | 8 icon-only buttons |
| Fixed-size fonts | ~45 instances across 4 files |
| Tap targets under 44pt | 6 instances |
| Gray-on-light contrast risks | ~15 text instances |
| Custom overlay focus issues | 1 (jerk countdown) |
| State-change VO announcements missing | 3 (pause/resume, countdown, photos picker) |

---

## Not Addressed in This Pass

- Fleet Manager dashboard screens (reports, user management, vehicle lists)
- Onboarding / auth / first-time-setup screens
- Maintenance NewUI dashboard, inventory, job list screens
- Driver screens outside the scope list (incident, performance, profile, dashboard)
- `SlideToCancel` component (ActiveNavigationDetailView tail section) — decorative-only, state-tracking via `progress` binding already provides visual context
