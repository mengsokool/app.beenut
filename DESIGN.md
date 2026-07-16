---
name: BeeNut Workbench
description: A calm, precise, field-ready interface for operating and servicing the BeeNut counting appliance.
colors:
  action-light: "#F4A900"
  action-light-hover: "#D98900"
  action-light-active: "#C47A00"
  action-soft-light: "#FFF2CC"
  action-text-light: "#8A4B00"
  action-focus-light: "#B76A00"
  action-dark: "#FFC23D"
  action-dark-hover: "#FFD36A"
  action-dark-active: "#E8A820"
  action-soft-dark: "#3A2A00"
  action-text-dark: "#FFD36A"
  action-focus-dark: "#FFC23D"
  on-action-light: "#171717"
  on-action-dark: "#171717"
  canvas-light: "#F3F4F6"
  surface-light: "#FFFFFF"
  surface-raised-light: "#F9FAFB"
  ink-light: "#171717"
  muted-light: "#52525B"
  disabled-light: "#A1A1AA"
  line-light: "#D4D4D8"
  line-subtle-light: "#E4E4E7"
  canvas-dark: "#0F0F0F"
  surface-dark: "#18181B"
  surface-raised-dark: "#27272A"
  ink-dark: "#FAFAFA"
  muted-dark: "#A1A1AA"
  disabled-dark: "#71717A"
  line-dark: "#3F3F46"
  line-subtle-dark: "#303036"
  success-light: "#166534"
  success-soft-light: "#DCFCE7"
  success-dark: "#4ADE80"
  success-soft-dark: "#123D24"
  warning-light: "#9A3412"
  warning-soft-light: "#FFEDD5"
  warning-dark: "#FB923C"
  warning-soft-dark: "#4A2412"
  danger-light: "#B91C1C"
  danger-soft-light: "#FEE2E2"
  danger-dark: "#F87171"
  danger-soft-dark: "#4C1D1D"
  info-light: "#1D4ED8"
  info-soft-light: "#DBEAFE"
  info-dark: "#60A5FA"
  info-soft-dark: "#172F52"
  preview-black: "#09090B"
typography:
  count:
    fontFamily: "NotoSansThai, NotoSans, sans-serif"
    fontSize: "96px"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "-1.5px"
    fontFeature: "tnum"
  page-title:
    fontFamily: "NotoSansThai, NotoSans, sans-serif"
    fontSize: "20px"
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: "normal"
  dialog-title:
    fontFamily: "NotoSansThai, NotoSans, sans-serif"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: 1.4
    letterSpacing: "normal"
  section-title:
    fontFamily: "NotoSansThai, NotoSans, sans-serif"
    fontSize: "14px"
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: "normal"
  body:
    fontFamily: "NotoSansThai, NotoSans, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.45
    letterSpacing: "normal"
  label:
    fontFamily: "NotoSansThai, NotoSans, sans-serif"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.3
    letterSpacing: "normal"
  caption:
    fontFamily: "NotoSansThai, NotoSans, sans-serif"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: 1.35
    letterSpacing: "normal"
  data:
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
    fontSize: "11.5px"
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: "normal"
rounded:
  indicator: "2px"
  control: "4px"
  panel: "6px"
  pill: "999px"
spacing:
  space-1: "4px"
  space-2: "8px"
  space-3: "12px"
  space-4: "16px"
  space-5: "20px"
  space-6: "24px"
  space-8: "32px"
components:
  button-primary-technician-light:
    backgroundColor: "{colors.action-light}"
    textColor: "{colors.on-action-light}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0 12px"
    height: "36px"
  button-primary-technician-light-active:
    backgroundColor: "{colors.action-light-active}"
    textColor: "{colors.on-action-light}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0 12px"
    height: "36px"
  button-primary-operator-light:
    backgroundColor: "{colors.action-light}"
    textColor: "{colors.on-action-light}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0 16px"
    height: "48px"
  button-primary-technician-dark:
    backgroundColor: "{colors.action-dark}"
    textColor: "{colors.on-action-dark}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0 12px"
    height: "36px"
  button-secondary-technician-light:
    backgroundColor: "{colors.surface-light}"
    textColor: "{colors.ink-light}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0 12px"
    height: "36px"
  field-technician-light:
    backgroundColor: "{colors.surface-light}"
    textColor: "{colors.ink-light}"
    typography: "{typography.body}"
    rounded: "{rounded.control}"
    padding: "0 10px"
    height: "36px"
  field-operator-light:
    backgroundColor: "{colors.surface-light}"
    textColor: "{colors.ink-light}"
    typography: "{typography.body}"
    rounded: "{rounded.control}"
    padding: "0 14px"
    height: "48px"
  setting-row-technician:
    backgroundColor: "{colors.surface-light}"
    textColor: "{colors.ink-light}"
    typography: "{typography.body}"
    rounded: "{rounded.indicator}"
    padding: "8px 12px"
    height: "44px"
  setting-row-operator:
    backgroundColor: "{colors.surface-light}"
    textColor: "{colors.ink-light}"
    typography: "{typography.body}"
    rounded: "{rounded.indicator}"
    padding: "10px 16px"
    height: "56px"
  panel-light:
    backgroundColor: "{colors.surface-light}"
    textColor: "{colors.ink-light}"
    rounded: "{rounded.panel}"
    padding: "16px"
  status-healthy-light:
    backgroundColor: "{colors.success-soft-light}"
    textColor: "{colors.success-light}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "4px 8px"
  navigation-selected-light:
    backgroundColor: "{colors.action-soft-light}"
    textColor: "{colors.action-text-light}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0 10px"
    height: "36px"
---

# Design System: BeeNut Workbench

## Overview

**Creative North Star: "The Operator's Workbench"**

BeeNut Workbench is an instrument surface, not a consumer application and not a website inside a window. An operator uses it beside a running camera and counting machine, often at arm's length, under inconsistent ambient light, with only seconds to confirm that the count and hardware state are trustworthy. A technician uses the same product more densely to configure models, inspect diagnostics, and recover the appliance. Every visual decision must shorten those tasks and preserve confidence.

This document is the normative migration target for BeeNut Workbench v0.1. Existing screens may still contain legacy Material visuals or heavier typography; new work must follow this contract, and migrations must move toward it without copying legacy exceptions into new tokens.

The canonical Flutter primitives live in `lib/core/workbench_tokens.dart`; `lib/core/theme.dart` maps those roles into `ThemeData` while preserving Material behavior. Feature code consumes semantic Workbench roles and must not introduce screen-local brand or status colors.

The system borrows the restraint of excellent native workbench applications: quiet typography, compact controls, clear alignment, structural dividers, and familiar interaction behavior. It does not imitate any one operating system. Flutter and Material may provide focus, input, menu, semantics, and accessibility behavior, but BeeNut owns all visible shape, color, spacing, typography, and state treatment.

Light theme is the default for bright operator environments. Dark theme is a first-class equivalent for controlled or low-light environments, never a decorative "pro" mode. The live camera preview remains dark in both themes so imagery and overlays retain stable contrast.

Density is selected by task, not guessed from viewport width:

- **Operator density:** kiosk and recovery workflows use 48 px controls, 56 px rows, obvious state changes, and minimal secondary copy.
- **Technician density:** settings and diagnostics use 32–36 px visual controls, at least 40 px interactive hit regions, 44 px rows, and progressive disclosure for deep detail.
- **Responsive structure:** below 640 px, navigation collapses and trailing controls may stack; from 640–959 px the standard workbench layout applies; at 960 px and above, content is capped and auxiliary panels may sit beside the primary task. Typography does not scale fluidly with viewport width.

**Key Characteristics:**

- Practical, precise, calm, durable, and field-ready.
- Flat by default, with hierarchy carried by spacing, tone, and one-pixel dividers.
- Information-dense without becoming visually heavy.
- One sans-serif family for Thai and Latin interface text; monospace only for machine data.
- Restrained roadway amber brand signal; semantic colors communicate operational state.
- Keyboard, pointer, and touch behavior are equally complete.
- Motion communicates state in 100–220 ms and disappears when reduced motion is requested.

**The Workbench Test.** If a visual choice attracts attention before the count, preview, current selection, or failure state, remove it.

**The Behavior Boundary Rule.** Material behavior is permitted; Material appearance is not the BeeNut public design language. No feature may depend on an unreviewed Material default for its visible design.

## Colors

The palette pairs high-visibility roadway amber with asphalt ink and concrete-neutral surfaces. The result should recall durable road equipment and field signage without turning the interface into a warning sign. Green, hazard orange, red, and blue remain reserved for operational meaning.

### Primary

- **Roadway Amber:** the BeeNut brand signal and dominant interaction color. Use the bright tone for filled primary actions and substantial signal surfaces with asphalt-dark foregrounds. On white or pale surfaces, standalone icons, links, selection marks, focus rings, and progress indicators use the Deep Amber tokens so their edges meet non-text contrast requirements.
- **Amber Wash:** a low-emphasis selection background. It supports a dark readable label plus an amber icon or indicator; it never replaces the selected state or focus ring.
- **Deep Amber Ink:** the accessible text/link form of the brand color on light surfaces. Bright roadway amber is a fill and indicator color, not body text on white.

### Secondary

- **Operational Green:** healthy, ready, connected, accepted, saved, and successfully completed states.
- **Hazard Orange:** degraded operation, pending intervention, temperature or performance warnings, and actions that require care. It is redder and darker than Roadway Amber and is always paired with a warning icon or state word.
- **Fault Red:** disconnected hardware, invalid configuration, destructive actions, and failures that block the counting task.
- **Diagnostic Blue:** neutral information and progress that is neither success nor warning.

### Neutral

- **Canvas:** the app shell behind primary surfaces. It separates major work areas without a shadow.
- **Surface:** the standard panel, row, menu, and dialog content surface.
- **Raised Surface:** toolbars, selected neutral regions, hover states, and floating surfaces when a subtle tonal step is required.
- **Ink:** primary text and icons.
- **Muted Ink:** secondary labels, descriptions, units, and timestamps. It must still meet body-text contrast requirements.
- **Structural Line:** one-pixel panel borders, dividers, field outlines, and separators.
- **Preview Black:** the stable camera-preview surround in both themes.

**The One Signal, One Meaning Rule.** Roadway amber means BeeNut interaction or current selection; green means operational success; hazard orange means warning. Never use these roles interchangeably.

**The Ten Percent Rule.** Saturated color occupies no more than roughly 10% of a normal workbench screen. The live preview and functional visualization overlays are exempt when the data requires color.

**The Contrast Rule.** Normal text and placeholder text must reach at least 4.5:1 against their surface; large text and non-text controls must reach at least 3:1. Color is always paired with a label, icon, shape, or state word.

## Typography

- **Display Font:** Noto Sans Thai with Noto Sans and platform sans-serif fallbacks
- **Body Font:** Noto Sans Thai with Noto Sans and platform sans-serif fallbacks
- **Data Font:** platform UI monospace (`SFMono-Regular`, `Menlo`, `Consolas`, then `monospace`)

**Character:** quiet, highly legible, and structurally neutral. Typography identifies hierarchy without turning every label into a heading. The bundled Noto fonts are variable fonts and must expose the requested weight instead of relying on synthetic bolding.

### Hierarchy

- **Count** (700, default 96 px, 1.0 line height): the primary counting result only. It may fit between 64–140 px using available panel height, uses tabular figures, and is the only routine use of weight 700.
- **Page Title** (600, 20 px, 1.3): the single title for a major workspace or settings screen.
- **Dialog Title** (600, 16 px, 1.4): modal and high-consequence confirmation titles.
- **Section Title** (500, 14 px, 1.4): panel and settings-group headings.
- **Body** (400, 13 px, 1.45): descriptions, setting values, messages, and ordinary content. Prose is capped at 65–75 characters per line; dense data layouts may exceed that.
- **Label** (500, 12 px, 1.3): buttons, field labels, tabs, status labels, and navigation items.
- **Caption** (400, 11 px, 1.35): units, timestamps, helper text, and tertiary metadata. It is never used for essential instructions.
- **Data** (400, 11.5 px, 1.4): paths, pipeline fragments, identifiers, dimensions, frame rates, and diagnostic key-value data.

**The Weight Budget Rule.** Weight 400 is the default, 500 marks controls and local hierarchy, 600 is limited to one major heading per region, and 700 is reserved for the main count or a genuinely critical value. Weight 800 and 900 are prohibited.

**The Sentence Case Rule.** Buttons, navigation, status labels, and headings use sentence case in Thai and English. Uppercase is allowed only for established technical abbreviations such as CPU, FPS, ONNX, and GPIO.

**The Data Is Not Description Rule.** Structured values are rendered as labels, status words, metrics, and key-value pairs. Never compress hardware or model data into a prose description merely to fit a row.

## Elevation

BeeNut Workbench is flat by default. At-rest panels, settings groups, rows, buttons, and inputs use tonal separation and one-pixel structural lines; they do not cast shadows. Elevation exists only where a surface physically floats above another interaction layer: menus, tooltips, dialogs, and transient feedback.

### Shadow Vocabulary

- **Popup** (`0 4px 8px rgba(15, 23, 42, 0.14)` in light theme; `0 4px 8px rgba(0, 0, 0, 0.36)` in dark theme): menus, tooltips, and non-modal floating pickers.
- **Dialog** (`0 8px 24px rgba(15, 23, 42, 0.20)` in light theme; `0 8px 24px rgba(0, 0, 0, 0.48)` in dark theme): dialogs above a scrim. Dialogs use this shadow without a decorative outer border.

**The Flat-at-Rest Rule.** If a surface is part of normal page layout, its shadow is zero.

**The Structural Depth Rule.** Use this order to create hierarchy: spacing first, tonal surface second, one-pixel line third, shadow last.

## Components

BeeNut components feel precise and familiar. Geometry is compact, state changes are immediate, and every interactive component implements default, hover, focus, active, disabled, loading, and error behavior where relevant.

### Buttons

- **Shape:** compact rectangle with gently eased corners (4 px), never a capsule unless the control is a true binary chip.
- **Typography:** 12 px, weight 500, sentence case. Icons are 16–18 px and never substitute for an unfamiliar text label.
- **Primary:** roadway-amber fill with asphalt-dark foreground; 36 px high in technician density and 48 px high in operator density.
- **Secondary:** surface fill with a one-pixel structural outline. Hover uses the raised surface; active uses a darker tonal step.
- **Ghost:** transparent at rest and reserved for toolbar actions. Hover reveals a raised-surface background.
- **Destructive:** fault red is used only when the action is destructive or blocks operation; confirmation copy states the consequence.
- **Focus:** an external two-pixel deep-amber focus ring with two pixels of separation in light theme, and bright roadway amber in dark theme. Focus never depends on a color change alone.
- **Loading:** preserves button width, disables repeated activation, and replaces only the leading icon with a compact progress indicator.

### Status Indicators

- **Style:** status icon or six-pixel dot, explicit state word, and optional metric. Healthy, warning, fault, and information states use their semantic color families.
- **Content:** `ready · 30.0 fps` is valid compact status copy. Pipeline strings, device paths, labels, thread counts, and similar values belong in a detail region as key-value data.
- **Shape:** compact rectangle (4 px) for a status label; full-pill geometry is permitted only for a short non-interactive state chip.
- **Behavior:** status changes are announced to assistive technology when operationally important. A status chip is not clickable unless it has a clear disclosed action.

### Rows and Property Data

- **Setting row:** one label, optional one-line helper text, and one trailing control. Technician rows are at least 44 px high; operator rows are at least 56 px high.
- **Status row:** leading system icon, subsystem title, compact status summary, and an optional disclosure control. Expanded detail uses aligned key-value pairs.
- **Property row:** label and value align to a stable grid. Machine values use the Data typography role; human-facing values use Body.
- **Separation:** adjacent rows share one-pixel dividers. Never wrap every row in an individual card.
- **Overflow:** user-facing text wraps when it is useful; paths and pipelines copy, scroll, or disclose. Essential values are never silently ellipsized without an accessible full-value path.

### Panels and Containers

- **Corner Style:** restrained panel corners (6 px).
- **Background:** standard surface on the canvas; raised surface only for state or floating context.
- **Border:** one-pixel structural line when the panel boundary is otherwise ambiguous.
- **Internal Padding:** 12 px for dense tool panels, 16 px for standard panels, and 20–24 px only for primary kiosk regions.
- **Nesting:** one structural panel may contain divided rows. Panel-inside-panel styling and repeated nested cards are prohibited.

### Inputs and Selectors

- **Style:** one-pixel structural outline, surface background, 4 px corners, Body typography, and a persistent label whenever the value is ambiguous.
- **Size:** 36 px visual height in technician density, 48 px in operator density. Dense controls retain at least a 40 px hit region.
- **Focus:** two-pixel deep-amber outline outside the component without changing layout; use the brighter amber focus token in dark theme.
- **Error:** fault-colored outline plus a plain-language message beneath or beside the field. Error color alone is insufficient.
- **Disabled:** reduced contrast, no hover response, and no pointer activation; disabled values remain readable.

### Navigation

- **Style:** quiet shell surface, 18–20 px icons, 12 px weight-500 labels, and a compact selected background. Selection uses amber plus a shape or tonal change.
- **Information architecture:** settings remain flat and task-based under three non-interactive group labels: Operation contains Overview, Targets, and Counting; Device contains Camera, Model, and Hardware; System contains Interface and Service.
- **Grouping:** group labels use sentence case and subdued Label typography. They organize destinations but never introduce a second navigation level.
- **Technician layout:** persistent rail or sidebar when width permits; selected state remains visible while content scrolls.
- **Compact layout:** below 640 px, navigation becomes a drawer, compact rail, or top-level switcher without hiding critical recovery actions.
- **Keyboard:** logical traversal order, visible focus, arrow-key behavior for tab-like collections, and activation with Enter or Space.

### Count and Preview Workspace

- **Count:** the largest visual element because it is the primary instrument reading, not a marketing hero metric. It uses tabular figures and remains stable when digits change.
- **Preview:** maintains a dark surround and reserves saturated overlay colors for detection boxes, gates, and current tracking state.
- **Competition:** secondary labels, status chips, and toolbar actions must remain visually quieter than both count and preview.

### Feedback, Disclosure, and Overlays

- **Save feedback:** concise inline confirmation or toast; it includes what happened and disappears without blocking work.
- **Disclosure:** chevron and label expose secondary diagnostics in place. State changes complete in 160 ms with an ease-out curve.
- **Menus and dialogs:** use familiar platform behavior, remain inside the visible workspace, and restore focus to the invoking control when closed.
- **Motion:** standard state transitions use 100–220 ms. Reduced-motion mode uses zero-duration layout changes or a simple crossfade.

### Material Implementation Boundary

- **Allowed foundations:** `Focus`, `FocusTraversalGroup`, `Shortcuts`, `Actions`, `Semantics`, text input behavior, menu positioning, selection behavior, scrolling physics, and accessible activation semantics.
- **Owned by BeeNut:** `ThemeExtension` tokens, component geometry, typography, density, colors, borders, hover/focus/active visuals, navigation appearance, dialogs, status language, and feedback treatment.
- **Migration rule:** existing Material widgets may remain while being wrapped or themed, but no new BeeNut component may expose a raw Material visual role as its public API.

## Do's and Don'ts

### Do:

- **Do** put the counting task first: count, live preview, target selection, and blocking system state win every hierarchy decision.
- **Do** render hardware and model state as status, metrics, and aligned property data instead of prose descriptions.
- **Do** use the 4 px spacing grid and the defined density metrics; operator controls are 48 px and technician controls are 32–36 px with adequate hit regions.
- **Do** use weight 400 for normal text and weight 500 for buttons, navigation, field labels, and local hierarchy.
- **Do** maintain readable Thai and Latin line metrics with the bundled Noto Sans variable fonts.
- **Do** show visible keyboard focus, complete semantics, and touch-friendly hit areas on every interactive control.
- **Do** test every component in light and dark themes, Thai and English, operator and technician density, and widths below 640 px and at or above 960 px.
- **Do** keep recovery, retry, and degraded-mode actions visible near the state that requires them.
- **Do** use skeleton or structural placeholders for content loading and compact progress indicators for bounded actions.

### Don't:

- **Don't** add marketing-site flourishes. BeeNut is an appliance workbench, not a landing page.
- **Don't** use over-rounded consumer app styling. Controls stop at 4 px, panels stop at 6 px, and pills are reserved for true chips or short states.
- **Don't** use decorative motion. Motion must explain state, feedback, loading, or disclosure.
- **Don't** hide controls required to operate, diagnose, retry, or recover the appliance.
- **Don't** ship low-contrast diagnostics. Muted text, placeholders, dividers, and status information must remain readable in both themes.
- **Don't** add any visual treatment that competes with the live preview or count status.
- **Don't** use Material 3 typography, Cards, FilledButton styling, NavigationRail appearance, or surface-container names as the public BeeNut visual language.
- **Don't** use weight 600 for ordinary row labels or weight 700 for button text. Weight 800 and 900 are forbidden.
- **Don't** turn structured data into a description string or use ellipsis as the only way to access a machine value.
- **Don't** place every setting, metric, or status in its own card, and never nest decorative cards.
- **Don't** use gradient text, glassmorphism, decorative glows, diagonal stripe backgrounds, or wide soft shadows on bordered surfaces.
- **Don't** add a colored side stripe thicker than one pixel to cards, list items, alerts, or callouts.
- **Don't** use uppercase for ordinary labels, buttons, subtitles, or navigation.
- **Don't** use green for selection, amber for success, or brand amber as the warning treatment; one signal has one meaning.
- **Don't** open a modal when inline editing, disclosure, or progressive expansion can complete the task safely.
