# Settings experience

BeeNut uses Carbon-inspired Flutter controls, IBM Plex typography, square corners, neutral field layers, and blue for actions/focus. Settings are organized around tasks. There is no global Basic/Developer switch and no role-based access-control boundary.

## Tasks

| Task | Workflow |
| --- | --- |
| Jobs to count | Edit prepared job names, images, operator-facing class names, enabled state and order. Model class IDs and mapping controls are omitted. Each job save is sent immediately and waits for acknowledgement. |
| Camera view | Live camera image with actual camera choices and horizontal/vertical flips. Changes are applied and saved automatically through the service client, with a short debounce for quick taps and rollback/error feedback for rejected saves. There is no Save/Discard bar for camera alignment. Controls are disabled while disconnected. A single available source is not presented as a selector; mock sources and capture tuning belong to machine setup. |
| Display and language | Language, theme and UI scale in a short form. UI scale previews immediately while editing and persists after Save; Discard restores the saved size. Live status refreshes do not overwrite the preview. Save the task before returning. Desktop and Pi scaling also works on short windows such as 800×480; only compact Android/iOS layouts bypass whole-viewport scaling. |
| Machine setup | Model/classes, detection/counting, performance, hardware, and checks. Related edits share one draft and are applied together. |

A single 56-pixel toolbar shows back/close and the task title. The root is a flat list of four single-line tasks with unboxed icons and a minimum 48-pixel touch target. Enabled job names appear as a trailing summary when the row has at least 560 pixels of available width; narrow windows show only the task title. Wide machine windows have section navigation on the left and the configuration form in the remaining area. Compact machine windows use a section picker and the full content area for configuration. Machine setup has no camera preview, live count/FPS/processing strip, or preview toggle; checks are accessed through Diagnostics and service.

The camera task uses `NativePreviewPane`, including the existing native texture transport or Android camera controller. Camera alignment sends changes automatically to the live pipeline; machine configuration retains an explicit Apply workflow. A paused camera preview offers a resume control; opening settings does not silently resume capture.

## Operator poweroff

On devices reporting poweroff capability, the settings root has a pinned 56-pixel poweroff button. The operator path is Kiosk → Settings → Poweroff → Confirm, without entering machine setup. The button is disabled while the service is disconnected. Confirmation sends one IPC shutdown request, locks navigation during shutdown, and uses operator-facing progress text. An accepted shutdown acknowledgement cancels the response timeout; a rejection or missing acknowledgement restores the controls with an error. Linux deployment still requires the poweroff permissions installed by `beenut-setup`; physical Pi shutdown remains a deployment check.

## Editing and applying

`ConfigDraft` stores changed JSON leaves and overlays them on the latest service configuration, preserving unrelated live updates. A bottom bar appears only while changes are pending or being applied. Apply/Save sends one configuration update; rejection or timeout preserves the draft for correction/retry. Successful acknowledgement clears it.

Leaving a task with a draft offers Keep editing, Discard or Save/Apply. Save waits for acknowledgement before navigating. System back follows this same flow before closing settings. Machine section changes retain the draft and validate visible numeric fields first. Diagnostics, hardware tests and shutdown remain immediate commands.

Worker job edits retain the prepared model mapping. Adding/deleting jobs and changing class mappings belongs to machine setup. If model paths, runtime, or label source are being changed, apply them before editing class mappings so the list uses labels reported by the loaded model.

## Input controls

- Two or three finite choices use radio options; longer lists use a menu. One available choice is shown as a value. Binary settings use toggles.
- Machine numbers are inline bounded fields, supporting typing, Tab, +/- and an explicit touch keypad button. Invalid values cannot be applied or lost by switching machine sections.
- Ordinary numeric settings open a touch keypad. Short landscape screens place the field beside the keypad so all four rows remain accessible.
- Machine paths support inline typing/paste, Browse and an explicit onscreen keyboard. Text editors expose a Thai/English keyboard, including path punctuation.
- Ordinary controls are 56 logical pixels high; machine controls are 48. Availability of GPU/runtime/GPIO remains based on reported capabilities, not assumed from the platform name.

## Source and verification

- `lib/ui/settings/settings_page.dart`: task routing, workspace layout, scoped draft/apply lifecycle, guarded navigation and preview.
- `lib/core/config_draft.dart`: draft merge logic.
- `lib/ui/common/settings_experience.dart`: internal input/density scope.
- `lib/ui/common/inline_number_control.dart`, `inline_text_control.dart`: machine input fields.
- `lib/ui/common/number_editor.dart`, `virtual_keyboard.dart`: touch input.
- `test/settings_page_test.dart`: compact/wide navigation and preview, worker saves, rejection/navigation and shutdown denial.
- `test/settings_experience_test.dart`: draft merge, acknowledgement/retry, bounded inline entry, explicit keypad and short-screen Thai keyboard.
- `test/shell_navigation_test.dart`: nested task and draft handling under system back.

Physical Raspberry Pi touch/IME and hardware testing remains a deployment check. Widget tests verify desktop and compact layouts; these do not establish physical touch accuracy or platform keyboard integration.
