---
target: settings interface design
total_score: 20
p0_count: 0
p1_count: 4
timestamp: 2026-07-10T16-46-57Z
slug: lib-ui-settings-settings-page-dart
---
# BeeNut Settings Interface Critique

## Design Health Score

| # | Heuristic | Score | Key issue |
|---|---|---:|---|
| 1 | Visibility of System Status | 2/4 | มี status เยอะ แต่ผล Saving/Saved/Failed อยู่ไกลจากจุดที่แก้ค่า |
| 2 | Match System / Real World | 2/4 | ภาษางานช่างพอใช้ได้ แต่เปิดศัพท์ NMS, HEF, daemon, preview transport และ path ดิบมากเกินไป |
| 3 | User Control and Freedom | 2/4 | ออกจากหน้า/ยกเลิก dialog ได้ แต่ไม่มี Apply/Discard/Undo สำหรับค่าที่ auto-save และ shutdown overlay ไม่มีทางกู้เมื่อค้าง |
| 4 | Consistency and Standards | 3/4 | token และ setting-row ใช้สม่ำเสมอ แต่ custom dialog/control และขนาด 28/32/36/38/40 px ทำให้ vocabulary แตก |
| 5 | Error Prevention | 2/4 | มี bounds และ confirm งานทำลายข้อมูล แต่ Camera/AI/GPIO เปลี่ยนแล้วส่งทันทีและพึ่ง backend ตรวจทีหลัง |
| 6 | Recognition Rather Than Recall | 2/4 | nav มี label ชัด แต่ต้องจำภาพ/count เดิม และต้องกลับ General เพื่อดูว่า save ผ่านหรือไม่ |
| 7 | Flexibility and Efficiency | 1/4 | ไม่มี search, shortcut, direct numeric entry, bulk target actions หรือ keyboard reorder |
| 8 | Aesthetic and Minimalist Design | 3/4 | palette สุขุมและ shape เหมาะกับเครื่องมือ แต่หลายหน้ากลายเป็น wall of rows ที่น้ำหนักเท่ากัน |
| 9 | Error Recovery | 2/4 | camera permission recovery ดี แต่ save rollback และ filesystem error ยังไม่อธิบายการกู้คืนตรงจุด |
| 10 | Help and Documentation | 1/4 | มี description บางแถว แต่ค่าที่เสี่ยงต่อ accuracy/hardware ไม่มีคำแนะนำหรือ recommended range |
| **Total** |  | **20/40** | **Acceptable — ต้องแก้โครงสร้างก่อนจะดูเป็น production native app** |

## Anti-Patterns Verdict

**LLM assessment:** ไม่ใช่ AI slop แบบชัด ๆ เพราะไม่มี gradient text, radius ใหญ่เกิน, motion ฟุ่มเฟือย หรือ palette สำเร็จรูป งานฐานค่อนข้างมีวินัย แต่เป็น **product slop ระดับกลาง**: มันให้ความรู้สึกเหมือน service console ที่แต่ง UI แล้ว มากกว่า Settings ของ native appliance ที่เลือกสิ่งสำคัญให้ผู้ใช้แล้ว สาเหตุหลักคือทุกอย่างถูกเปิดพร้อมกัน, feedback การบันทึกอยู่ผิดที่, ภาษาไทย/อังกฤษปนกัน และ custom controls เล็กกว่าบริบท touch kiosk ต้องการ

มี ghost-card treatment ใน custom dialog: border ถูกวางคู่กับเงากว้าง blur 32 (`target_edit_dialog.dart:115-127`; `file_picker.dart:501-511`) และ Runtime ใช้ bordered choice cards ซ้อนใน bordered SettingsGroup (`model_tab.dart:84-113`; `setting_choice_cards.dart:38-119`) ซึ่งเพิ่มชั้นกรอบโดยไม่เพิ่มความหมาย

**Deterministic scan:** ตัว detector จบด้วย exit code 0 และรายงาน 0 findings แต่ผลนี้ใช้ยืนยันว่า clean ไม่ได้ เพราะ directory scan ไม่รองรับ `.dart`; มันข้ามไฟล์ใน `lib/ui/settings` ทั้งหมดแบบเงียบ และอ่านได้เพียง common Dart files ที่ส่งเป็นไฟล์ตรง ๆ ไม่มี false positive แต่มี false-negative risk สูง

**Visual evidence:** ไม่มี browser overlay เพราะ in-app Browser backend ไม่พร้อมใช้งาน และ Flutter project ไม่มี web target ที่รองรับการ render หน้านี้อย่างเชื่อถือได้ ภาพจาก widget render ที่ 1200×800 และ 500×700 ยืนยันเรื่อง hierarchy: main pane ไม่มี page title, group heading กับ row label มีน้ำหนักใกล้กัน, และเนื้อหาเริ่มเป็นกรอบ/แถวทันทีจนไม่มีจุดพักสายตา

## Overall Impression

ความรู้สึกของคุณถูกครับ: **ยังไม่เหมาะจะเรียกว่า finished native Settings** แม้สี ฟอนต์ และ radius จะไม่ได้เละ ปัญหาจริงคือ information architecture กับ operational feedback ไม่ใช่การแต่งสี โอกาสใหญ่ที่สุดคือเปลี่ยนจาก “เอาค่าทั้งหมดมาแสดงเป็นแถว” เป็น “ออกแบบตามงานของ operator และ technician แล้วค่อยเปิดรายละเอียดเมื่อจำเป็น”

## What's Working

- Visual foundation ดี: สี restrained, contrast หลักชัด, Noto Sans Thai/Latin, radius 4–6 px และ motion สั้น เหมาะกับ field tool (`theme.dart:4-27`, `81-190`; `settings_page.dart:244-260`)
- Desktop sidebar และ compact list/detail navigation เข้าใจง่าย พร้อมทางกลับ Kiosk ชัด (`settings_page.dart:153-361`)
- มี guardrail ที่ดีหลายจุด: bounded steppers, capability-aware choices, ป้องกันลบ target สุดท้าย, confirm shutdown/factory reset และ USB dry-run

## Priority Issues

### [P1] Information architecture ทำให้ทุกอย่างดูกองและมีน้ำหนักเท่ากัน

**Why it matters:** General รวม Display, live machine status, resource graph สูง 360 px, permissions, validation และ save history (`status_tab.dart:60-298`) ขณะที่ Hardware Diagnosis รวม test, export diagnostics, factory reset, USB update, relay/tray simulation และ manual count 9 แถวใน group เดียว (`test_tab.dart:157-325`) ผู้ใช้ต้องสแกนงานคนละชนิดในพื้นที่เดียวกัน

**Fix:**

- ให้ General เริ่มด้วย System Health summary 3–4 รายการ แล้วแยก Appearance ออกเป็นกลุ่มสั้น
- ย้าย Resource Usage ไป Diagnostics และซ่อนไว้หลัง “ดูรายละเอียด”
- แยก Camera ออกจาก Trigger & I/O
- แยก AI เป็น Model & Runtime กับ Advanced Tuning แบบ collapsed/disclosure
- แยก Test ออกจาก Maintenance; Factory Reset และ USB Update ต้องอยู่หมวด Service/Maintenance ที่มี access/visual hierarchy ต่างออกไป
- เพิ่ม page title + one-line context ใน main pane เพื่อให้แต่ละปลายทางมี anchor

**Suggested command:** `$impeccable distill`

### [P1] การบันทึกค่ามองไม่เห็นในจุดที่ผู้ใช้กำลังแก้

**Why it matters:** ทุก row ส่งค่าแบบ optimistic/debounced และอาจ rollback แต่ save result แสดงเฉพาะท้าย General (`service_client.dart:248-297`; `status_tab.dart:285-295`) ทำให้หน้า Camera/AI ดูตอบสนองเร็วแต่ไม่น่าไว้ใจ และสร้าง memory bridge ข้ามแท็บ

**Fix:** เพิ่ม persistent Settings header ที่แสดง `Saving… / Saved / Save failed`; ผูก validation error กับ row ที่ผิด สำหรับ Camera/Model/GPIO ควร stage เป็น draft พร้อม Apply/Discard และ summary ว่า config ยัง healthy ก่อนกลับ Kiosk

**Suggested command:** `$impeccable harden`

### [P1] Touch target, keyboard และ compact layout ยังไม่ถึงมาตรฐาน kiosk

**Why it matters:** stepper hit area 28×28, selector สูง 32, action button 38 และ file-picker control บางตัว 24–28 px (`setting_controls.dart:34-66`, `88-173`; `setting_action_row.dart:62-88`; `file_picker.dart:730-764`) UI Scale ยังลดได้ถึง 50% จึงยิ่งทำให้เป้ากดเล็กลง Selector ใช้ `GestureDetector` แทน control ที่ focus/keyboard ได้ตามมาตรฐาน (`setting_rows.dart:67-129`)

**Fix:** กำหนด minimum interaction size 48 px, ไม่ scale hit region ลง, ให้ setting row เปลี่ยนเป็น vertical label/control layout เมื่อพื้นที่แคบ, รองรับ direct numeric input และ keyboard focus/action, เพิ่ม semantic summary ให้ chart และทดสอบ 360 px + Thai + 200% scale

**Suggested command:** `$impeccable adapt`

### [P1] ภาษาไทย/อังกฤษปนกันจนดูเหมือน prototype

**Why it matters:** เมนู Targets, Status, Model, Hardware Test, target dialog และ file picker ยังมีข้อความ hard-coded อังกฤษจำนวนมาก แม้เลือกภาษาไทย (`settings_page.dart:59-65`; `status_tab.dart:116-295`; `model_tab.dart:84-218`; `test_tab.dart:42-325`; `target_edit_dialog.dart:142-465`) และบาง logic เปรียบเทียบ translated display text โดยตรง (`config_tab.dart:367-371`)

**Fix:** ย้ายข้อความ user-visible ทั้งหมดเข้า i18n, เก็บค่าของ control เป็น stable ID แล้วแปลเฉพาะ label, เพิ่ม parity test ของ key อังกฤษ/ไทย และ widget test ที่เดินทุกแท็บในภาษาไทย

**Suggested command:** `$impeccable clarify`

### [P2] Component vocabulary “custom ทุกจุด” ลดความรู้สึก native

**Why it matters:** shared settings rows เป็นฐานที่ดี แต่มี inline button styles, custom dialog, custom selector, custom filesystem browser และกรอบซ้อนจำนวนมาก ขนาด/พฤติกรรมจึง subtly inconsistent แม้สีเหมือนกัน

**Fix:** ใช้ Material 3 components/theme เป็น default, ลด panel border ที่ไม่จำเป็น, เลิก nested choice cards, ใช้ standard dialog/sheet ตามขนาดจอ และแทน generic file explorer ด้วย task-first import flow: USB / Managed Models / Local File

**Suggested command:** `$impeccable polish`

## Cognitive Load

**ไม่ผ่าน 7 จาก 8 ข้อ — high cognitive load**

- Single focus: ไม่ผ่าน — General และ Test รวมหลายงานคนละประเภท
- Chunking: ไม่ผ่าน — Camera มี 6 rows, Connection Diagnostics มี 6+ conditional rows, Hardware Diagnosis มี 9 rows
- Grouping: ผ่าน — `SettingsGroup` และ divider สม่ำเสมอ
- Visual hierarchy: ไม่ผ่าน — health/validation ถูกฝังหลัง Display และ chart; row ทุกตัวเด่นใกล้กัน
- One thing at a time: ไม่ผ่าน — runtime, model, thresholds, filters และ safe mode เปิดพร้อมกัน
- Minimal choices: ไม่ผ่าน — GPIO 17 ตัวเลือก, model-class chips อาจเป็นหลักสิบ, Hardware Test มีราว 12 actions
- Working memory: ไม่ผ่าน — มอง preview/count ไม่ได้ขณะ tune และ feedback save อยู่คนละแท็บ
- Progressive disclosure: ไม่ผ่าน — advanced tuning, maintenance และ filesystem internals เปิดกว้างเกินไป

## Emotional Journey

- **เข้า Settings:** สงบและดูเป็นเครื่องมือจริง sidebar ชัด
- **เริ่มหาเมนู:** ชื่อแท็บพอเข้าใจได้ แต่ General ซ่อนข้อมูลสุขภาพเครื่องที่สำคัญที่สุด
- **เริ่มแก้ค่า:** รู้สึกเร็วเพราะค่าเปลี่ยนทันที แต่เริ่มไม่มั่นใจเพราะไม่มี Saved/Failed ใกล้มือ
- **เจอปัญหา:** เป็น emotional valley — ค่าอาจเด้งกลับ, error บางส่วนเป็น technical string และต้องรู้เองว่าจะไปดู General
- **ก่อนกลับ Kiosk:** ไม่มี completion moment ว่า “ค่าทั้งหมดถูกยอมรับและเครื่องพร้อมนับ” จบด้วยความไม่แน่ใจแทน confidence

## Persona Red Flags

**Alex — power user:** ไม่มี search, shortcut, direct numeric entry, bulk target management หรือ keyboard reorder; ปรับค่าช่วงกว้างต้องกด +/− ซ้ำ และ save เร็วแต่ตรวจสอบสถานะไม่ได้

**Sam — accessibility-dependent:** control 24–40 px, whole-app scale ถึง 50%, file/chart text 8–10 px, selector แบบ gesture-only, chart ไม่มี semantic equivalent, dialog fixed width และ disabled target ลด opacity เหลือ 42% (`catalog_tab.dart:350-375`)

**Jordan — first-timer:** เจอ NMS, HEF, GPIO Active Low, daemon, preview transport, dry run และ raw path โดยไม่มีคำอธิบาย ค่าถูก save ทันทีจึงไม่กล้าลอง และ recovery information อยู่คนละแท็บ

## Minor Observations

- `LED Relay: ON` ใช้ warning tone ทั้งที่อาจเป็น normal active state (`status_tab.dart:126-132`)
- แสดงอุณหภูมิเป็น `C` แทน `°C` และปล่อย backend thermal strings ออกตรง ๆ (`status_tab.dart:145-152`)
- description จำกัดสองบรรทัดแล้วตัด ellipsis; ภาษาไทยและ recovery detail หายได้ (`setting_row_shell.dart:37-49`)
- unavailable runtime card ไม่เขียน “Unavailable” หรือบอกวิธีแก้ (`setting_choice_cards.dart:44-110`)
- settings tests ปัจจุบันตรวจเพียงโครง layout/scroll; ยังไม่ครอบคลุม save/error, keyboard, semantics, dark/Thai, scale, dialog และ overflow (`test/settings_page_test.dart:10-96`)

## Questions to Consider

- ถ้า line operator เปลี่ยน NMS, GPIO polarity หรือ model runtime ได้ใน tap เดียว นี่คือ Settings หรือ service console ที่ยังไม่มี guardrail?
- ก่อนกลับ production มีข้อความใดบนจอที่ยืนยันชัดว่า “เครื่องรับค่าทั้งหมดแล้วและยังนับได้อย่างน่าเชื่อถือ”?
- Operator จำเป็นต้องเห็น filesystem root, daemon terminology และ preview transport implementation จริงหรือไม่?
- Hardware Test ควรอยู่ระดับเดียวกับ Factory Reset และ USB Update หรือไม่?
