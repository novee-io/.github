# Interactive states in `@novee/ui`: standards, audit and proposed fixes

Dated snapshot, 2026-10-14. Covers hover, pressed, selected, current, open, focus and disabled across the uilib (`frontend/packages/ui`: `theme.css`, the `novee` and `shadcn` components, Storybook, the audit scripts) and the webapp that consumes it. Read-only audit: nothing in the monorepo was changed. The companion file [`interaction-states-audit-2026-10-findings.md`](interaction-states-audit-2026-10-findings.md) lists every verified finding with file and line evidence.

Scope note: the design system is the uilib. Figma is not a reference for this work and no Figma to-dos appear here.

## 0. Summary

The inconsistency you see ("some items hover purple, some grey, and selected looks different everywhere") is real, measurable, and mostly caused by five decisions in `theme.css`, not by individual components:

1. `--color-surface-selected` and `--color-surface-hover` resolve to the same hex in both themes (`#f2efff` light, `#513a84` dark). Anything that uses the system tokens for hover and for selection renders them identically.
2. Two hover families coexist with no rule. Purple tint reaches components through `accent`, `sidebar-accent`, `table-row-hover`, `input-bg-hover` and `surface-hover`. Neutral grey reaches them through `surface-secondary`, `muted`, `surface-emphasis` and `menu-item-bg-hover`. Across the uilib and the webapp the neutral family is used about 55 times for `hover:bg-surface-secondary` alone, the purple family about 70 times.
3. The word "active" maps to purple for tabs, KPI tiles and filter buttons, but to neutral grey for the sidebar token and ghost buttons. The neutral sidebar token (`--nav-item-bg-active`) is defined, tuned in the dark-mode comments, and consumed by nothing.
4. The shadcn bridge points `--color-accent` (which shadcn documents as the neutral hover for menu items) at the brand tint, and `--color-muted` at a neutral. shadcn-derived components therefore hover purple while most hand-written rows hover grey.
5. There is one `--color-ring` token but at least nine focus recipes in use (widths 1 to 4 px, hues brand-900, 800, 700 and 500, alpha 50% and 30%, outset and inset), plus ten call sites that remove the ring with no replacement.

The audit found 234 verified inconsistencies: 13 accessibility blockers, 45 high, 130 medium, 46 low. Every finding was re-checked against the cited lines by an independent pass, and every blocker and high finding additionally passed a user-perception review. The industry consensus (section 2) is unambiguous on the points that matter: hover is a neutral one-step tint, selected is persistent and never color alone, selected plus hover is its own step, pressed is transient, and focus is a solid ring of at least 2 px at 3:1 that is never removed.

Section 4 proposes one state model for the uilib. Section 5 turns it into a token diff, a prioritised migration list, and guardrails so the drift cannot return.

## 1. Scope and method

**What was audited.** All 101 exported components under `frontend/packages/ui/src/{novee,shadcn}` plus the webapp surfaces that style states themselves (`frontend/packages/webapp/src`). The backoffice runs a separate palette and was excluded. The audit was organised into eight families: buttons, toggles and chips; menus, lists and pickers; navigation, tabs and steppers; rows, tables and trees; selectable cards and options; form controls; a sweep of the remaining webapp code; and the token layer with its guardrails.

**How.** For every interactive component the auditor recorded a state matrix: the literal Tailwind classes for rest, hover, focus-visible, mousedown, selected or checked or pressed, current, open, highlighted and disabled; the tokens they resolve to; the light and dark hex; the hue family; the mechanism (`:hover`, `aria-pressed`, `data-[state=…]`, prop-conditional class); and whether a non-color cue exists. Token resolution used the repo's own `scripts/audit-tokens.mjs --emit-manifest`. Each finding carries file and line evidence. A second, independent pass re-opened every cited line, re-resolved every token, and tried to refute the finding; five were refuted and dropped. Every blocker and high finding then went through a third pass asking whether a security analyst would perceive it. Severities below are post-verification.

**Severity rubric.** Blocker: an accessibility failure (no visible focus on a reachable control, a persistent selection indistinguishable from hover with no non-color cue, a state change with no perceivable difference, a control that keyboard users cannot reach). High: the same role rendered in a different hue family or through a different mechanism across siblings, or selected equal to hover. Medium: same family, different intensity, offset or width. Low: naming or mechanism nits with equal visuals.

**Prior work.** `docs/design-system-audit-2026-08.md` in the monorepo covered token and component drift between Figma and code. It did not cover interaction states. Closed issues novee-io/novee#3091, #3957, #3813 and #3052 were earlier symptoms of the same root causes.

## 2. What the industry does

Sources: WCAG 2.2 and WAI-ARIA 1.2 with the Authoring Practices Guide; Material Design 3; IBM Carbon; Atlassian Design System; Adobe Spectrum; GitHub Primer; Shopify Polaris; Microsoft Fluent 2; Apple HIG; Radix Colors, Themes and Primitives; shadcn/ui; Vercel Geist; GOV.UK; and practitioner guidance from NN/g, TPGi, Deque, Sara Soueidan and Maze. Values were read from first-party documentation or token packages. Linear and Stripe publish no state matrix, so they appear only as observed benchmarks.

### 2.1 Per-system comparison

| System | Hover | Selected | Selected + hover | Pressed | Focus | Token naming |
|---|---|---|---|---|---|---|
| WCAG 2.2 / ARIA / APG | No ARIA state; supplemental; must not erode other cues | `aria-selected` or `aria-checked`; 3:1 vs adjacent; never hue alone; distinct from focus | Not defined; the selection cue must keep 3:1 under hover | `aria-pressed` is a persistent toggle; mouse-down not addressed | 2.4.7 visible and not time limited; 1.4.11 3:1; 2.4.13 (AAA) 2 px perimeter | `aria-*` attributes, `:focus-visible` |
| Material 3 | 8% on-surface state layer | secondary-container fill plus check, weight or 3 px indicator | Additive 8% layer over the fill | 12% ripple | 3 px secondary ring, 2 px outward | `md-comp-x-selected-hover-state-layer-color` |
| IBM Carbon | `$layer-hover`, a grey half step | `$layer-selected` one step plus 4 px Blue 60 bar, check or SemiBold | `$layer-selected-hover` | `$layer-active`, two steps | 2 px `$focus` plus `$focus-inset`, 3:1 | `$layer-selected-hover-01` |
| Atlassian | `.hovered` modifier on the current role | `color.background.selected` plus 2 px `border.width.selected` and a cue | `color.background.selected.hovered` | `.pressed` modifier | 2 px `color.border.focused`, 2 px outside | `color.property.role.emphasis.state` |
| Adobe Spectrum | One contrast unit up | gray-800 fill by default; accent only when emphasized | Not documented | "down", one unit past hover | keyboard-focus blue ring | `--spectrum-role-emphasis-property-state` |
| GitHub Primer | `#818b981a` neutral alpha | `#818b9826` plus semibold and an accent line, underline or check | Hover replaces the fill; bold and line persist | Same step as selected | 2 px `#0969da`, inset 2 px, `:focus-visible` | `control-bgColor-hover` |
| Shopify Polaris | gray[4] | gray[6] plus semibold | gray[7] (dedicated brand-hover token) | gray[5] | 2 px `#005bd3`, offset 1 px | `color-bg-surface-selected` |
| Microsoft Fluent 2 | grey[96], never brand | grey[92] fill, or an unchanged surface plus brand bar and strong label on nav and tabs | Hover replaces; the bar stays | grey[88] under `:hover:active` | 2 px black or white, inset, keyboard only | `colorNeutralBackground1Selected` |
| Apple HIG | Pointer highlight or lift | Accent fill with white text in the key window; grey when unemphasized; check mark in menus | Not documented | `selectedControlColor` | Ring for fields, highlight for lists | Semantic NSColor names |
| Radix | Step 4 (step 3 if transparent) | Step 5; Themes add a 2 px `--accent-indicator` and medium weight | Tab hover layers over the indicator; segmented control suppresses hover on the selected segment | `:active` one step, suppressed while `data-state=open` | 2 px `--focus-8`, `:focus-visible` | Scale steps plus `data-state` |
| shadcn/ui | `hover:bg-accent` (a neutral in the stock theme) | `data-[state=on]:bg-accent`, rows `bg-muted`, sidebar `bg-sidebar-accent` plus `font-medium` | Nav link `bg-accent/50` to `bg-accent` | None on Button | `ring-[3px] ring-ring/50` | Semantic pairs plus Tailwind variants |
| Vercel Geist | Color 2 background, Color 5 border | Not documented | Not documented | Color 3 background, Color 6 border | `--ds-focus-color` blue-700 | `--ds-gray-alpha-N` |
| GOV.UK | Black tint-80 halo | 5 px bar plus strong label; tick on checkbox | Not documented | Button drops 2 px | 3 px yellow plus black, on `:focus` | `govuk-functional-colour(link-hover)` |

### 2.2 Consensus rules

1. **Hover is a neutral one-step tint of the element's own surface** (strong: Fluent, Primer, Polaris, Carbon, Material, Radix, Geist, GOV.UK, Atlassian, Spectrum). None of the token-based systems uses a brand fill for hover. Sources: [Fluent light tokens](https://raw.githubusercontent.com/microsoft/fluentui/master/packages/tokens/src/alias/lightColor.ts), [Radix scale](https://www.radix-ui.com/colors/docs/palette-composition/understanding-the-scale), [Carbon](https://carbondesignsystem.com/elements/color/overview/#hover).
2. **Hover is supplemental.** It carries no ARIA state and no contrast duty of its own, but it must never erode the contrast of the component or of the selected and focus indicators layered under it (WCAG 1.4.11 Understanding, TPGi, Carbon). Source: [Understanding 1.4.11](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html).
3. **Selected is persistent and never shown by color alone.** It always carries a non-color cue (indicator bar, check mark, bolder label, border, filled icon) that meets 3:1 against adjacent colors (WCAG 1.4.1 and 1.4.11; Carbon, Material, Primer, Fluent, GOV.UK, Radix Themes, Atlassian). Sources: [WCAG 1.4.1](https://www.w3.org/TR/WCAG22/#use-of-color), [Atlassian color](https://atlassian.design/foundations/color).
4. **Brand color lives in the indicator, not the fill.** Carbon, Primer, Fluent, Radix Themes, GOV.UK, Polaris and Spectrum keep the selected fill neutral and put brand only in the bar, underline, check or text. Material's secondary container and Apple's accent row fill are the exceptions.
5. **Selected plus hover is additive.** The selected cue stays and hover adds one more step. Systems that fill selected items mint a dedicated selected-hover token (Carbon `$layer-selected-hover`, Atlassian `selected.hovered`, Polaris gray[7], Material's stacked layer). Source: [Carbon data table](https://carbondesignsystem.com/components/data-table/style/).
6. **Pressed is transient, selected is persistent.** `aria-pressed` needs "a full press-and-release cycle" (ARIA 1.2). Pressed is bound to `:active`, is one step beyond hover, never persists, and is suppressed while a trigger is open (Radix Themes). Source: [aria-pressed](https://www.w3.org/TR/wai-aria-1.2/#aria-pressed).
7. **Focus is a solid ring of at least 2 px at 3:1 against adjacent colors**, with an inner contrast stroke on filled controls (Carbon `$focus-inset`, Fluent `colorStrokeFocus1`, GOV.UK yellow plus black). WCAG 2.4.13 (AAA) adds a 2 px perimeter area and says an inset ring needs 3 px. Sources: [2.4.13](https://www.w3.org/TR/WCAG22/#focus-appearance), [C40](https://www.w3.org/WAI/WCAG22/Techniques/css/C40).
8. **Focus shows on `:focus-visible` and is never removed without a replacement** (Material, Primer, Polaris, Fluent, Radix Themes, shadcn, React Aria; WCAG 2.4.7 permits keyboard-only display and forbids time limits). Menu and listbox items that move real focus with the pointer are the one place hover and focus share a highlight. Source: [Understanding 2.4.7](https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html).
9. **Focus and selected are visually distinct**, and focus tokens are reserved for focus (APG, Atlassian, Carbon). A ring means focus; a fill, bar or check means selection. Source: [APG keyboard interface](https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/).
10. **The current page carries `aria-current="page"` and the selected look** (bar plus bolder label on a neutral or unchanged surface). `aria-current` is not a substitute for `aria-selected` on tabs. Source: [aria-current](https://www.w3.org/TR/wai-aria-1.2/#aria-current).
11. **Disabled is grey, inert and contrast-exempt**; disabled menu items stay focusable (WCAG 1.4.11 exemption, ARIA, APG, Carbon).
12. **Open triggers hold a hover-level or pressed-level surface** while open (`data-state="open"`, `aria-expanded`), with the chevron as the non-color cue; Radix, Fluent and shadcn reuse hover, Primer, Polaris and Stripe reuse pressed.
13. **Menus use one highlight and a check mark.** Pointer hover and keyboard focus share a single highlighted treatment; the chosen item is shown by a check, not a second fill (Radix `[data-highlighted]`, Fluent, Primer, Apple).
14. **State is a trailing token modifier, persistent before transient**: `…-hover`, `…-pressed`, `…-selected`, `…-selected-hover`, `…-disabled` (Carbon, Atlassian, Polaris, Primer, Fluent, Material). Scale-step systems (Radix, Geist, shadcn) keep state out of the name and bind steps through selectors.
15. **One attribute per state, one selection model per app**: `aria-selected` for single-select, `aria-checked` for multi-select, `aria-pressed` for label-stable toggles, `aria-expanded` for open, `aria-current` for navigation. Source: [APG listbox](https://www.w3.org/WAI/ARIA/apg/patterns/listbox/).

### 2.3 Where systems split

The intensity ladder is contested: Fluent and Carbon order hover < selected < pressed; Polaris orders hover < active < selected; Radix and Primer give pressed and selected the same step. Focus color splits between accent hues (Carbon, Primer, Polaris, Geist, Radix) and maximum-contrast neutrals (Fluent, GOV.UK); both pass when 3:1 holds. Ring placement splits between outset (Atlassian, Material, Polaris) and inset (Primer, Fluent). Disabled splits between opacity (shadcn 0.5, Material 0.38) and dedicated grey tokens (Polaris, Carbon, Fluent, Primer). Checked form controls use a brand fill in Primer, Material and Fluent but grey in Polaris.

### 2.4 Canonical vocabulary

| State | Definition | Attribute | Typical visual |
|---|---|---|---|
| rest | No interaction, no persistent state | none, or `data-state="closed" / "inactive" / "off"` | Base surface, regular weight |
| hover | Transient pointer-over | `:hover`; `[data-highlighted]` in Radix menus | One neutral step up from rest |
| pressed | Transient mouse-down | `:active`, suppressed while `data-state="open"` | One step beyond hover |
| focus-visible | Keyboard focus that must be shown | `:focus-visible` | 2 px solid ring at 3:1, outset by 2 px, inset only inside clipped containers |
| selected | Persistent choice of an option, tab, row or card | `aria-selected="true"`; `aria-checked` for multi-select; Radix `data-state="active" / "on" / "selected"` | Neutral fill one step beyond hover plus a required non-color cue |
| selected + hover | Pointer over an already selected item | the above combined with `:hover` | Fill one more step; bar, check and weight unchanged |
| pressed (toggle on) | Persistent on state of a label-stable toggle | `aria-pressed="true"` | Same ladder as selected plus a check or filled icon |
| checked | Checkbox, radio, switch on | `aria-checked`, `data-state="checked"` | Brand fill with white glyph; in menus only the check mark shows |
| current | The page or step the user is on | `aria-current="page"` | Selected treatment: neutral fill, 2 px brand bar, medium label |
| open | Trigger whose popover or panel is shown | `aria-expanded="true"`, `data-state="open"` | Hover-level surface held, chevron rotated |
| disabled | Perceivable, not operable | `disabled`, `aria-disabled`, `[data-disabled]` | Neutral grey tokens or opacity; no hover or pressed response |

## 3. What Novee does today

### 3.1 Root causes in the token layer

All five are in `frontend/packages/ui/theme.css`; line numbers are from the audited commit.

| # | Finding | Evidence | Effect |
|---|---|---|---|
| T1 | `--color-surface-selected` equals `--color-surface-hover` in both themes | lines 253 and 258 both `var(--color-brand-300)`; lines 684 and 687 both `var(--color-brand-dark-300)` | Every consumer of the system tokens renders hover and selected identically: DataGrid rows, ActionGallery rail, OptionCard, filter buttons, KPI tiles, tabs. A code comment in `ReportKindCard.tsx:65` already works around it by dropping the hover tint altogether. |
| T2 | Three hover hue families with no rule | purple: `--color-surface-hover` (253), `--btn-ghost-bg-hover` (407), `--nav-item-bg-hover` (461), `--table-row-bg-hover` (442), `--input-bg-hover` (471); neutral: `--btn-filter-bg-hover` (422), `--table-head-column-bg-hover` (443), `--menu-item-bg-hover` (451), `--tabs-browsing-item-bg-inactive-hover` (508), the `--color-muted` bridge (583); solid: `--color-action-*-cta-hover` | The same gesture reads as "brand highlight" in some lists and "quiet grey" in others. In light mode the purple tint on white is 1.13:1 and the grey is 1.05:1, so what users perceive is "some rows hover, some do not". In dark mode it is an obvious grey versus purple flip. |
| T3 | "active" means two different things | `--nav-item-bg-active` is neutral `surface-tertiary` (462) while `--tabs-nav-item-bg-active` (497), `--kpi-bg-active` (516) and `--btn-filter-bg-active` (424) are purple `surface-selected`; `--btn-ghost-bg-active` (408) is neutral `surface-emphasis` | The sidebar's intended neutral current fill has zero consumers; the shadcn sidebar binds hover, mousedown and current to the same purple `sidebar-accent` (line 603 bridges it to `--nav-item-bg-hover`). The dark-mode comment at 664 tunes a token nothing renders. |
| T4 | The shadcn bridge inverts shadcn's own semantics | `--color-accent: var(--btn-ghost-bg-hover)` (584) makes `accent` the brand tint; `--color-muted: var(--tabs-browsing-bg)` (583) makes `muted` a neutral; `--color-secondary` resolves to the page color so `hover:bg-secondary/80` paints the page over itself | Every shadcn-derived item (dropdown, select, command, sidebar, ghost and outline button) hovers purple; every hand-written row that reached for `surface-secondary` or `muted` hovers grey. `Button secondary` has no visible hover at all. |
| T5 | One ring token, nine recipes, no pressed, selected-hover or current token | `--color-ring` (593) resolves to brand-900 / brand-800; components use `ring-ring/50 ring-[3px]`, `ring-2 ring-ring`, `ring-[1px] ring-inset`, `ring-border-focus`, `ring-brand-900`, `ring-brand-700`, `ring-brand-500`, `outline-1 outline-ring`, `focus-visible:ring-0`; `focus:` rather than `focus-visible:` in 15 places | Tabbing through one screen shows up to four different focus indicators; ten call sites show none. There is no token for pressed, selected plus hover, current, or a selected indicator, so consumers improvise. |

Two further token-layer facts matter for the fix. "surface" is overloaded: `--color-surface-*` are backgrounds but `--btn-*-surface`, `--kpi-surface` and `--menu-item-surface` are text colors. And the dark theme collapses distinct roles onto one hex: `#513a84` is at once `surface-hover`, `surface-selected`, `action-primary-cta-disabled` and `category-bg-brand`; `#3f4046` is `surface-disabled`, `border-primary`, `border-secondary` and `action-secondary-cta-hover` (from `audit-tokens.mjs --report`).

### 3.2 Accessibility blockers

These twelve items (thirteen findings; one duplicated across two families) fail WCAG 2.1.1, 2.4.7 or 1.4.1 outright on shipped surfaces. Paths are relative to `frontend/packages/`.

| ID | Surface | What happens | Evidence |
|---|---|---|---|
| F4-11 | Assets and Issues grids | Clickable rows are `div onClick` with no `tabIndex`, key handler or focus style; keyboard users cannot open a row at all | `ui/src/novee/components/DataGrid/components/DataGridRow.tsx:113`, `DataGridDataRow.tsx:81-99`, `webapp/src/lib/assets/v2/AssetsV2Table/AssetsV2Table.tsx:1286` |
| F4-12 | Notifications panel, dashboard widget rows | Clickable divs with no keyboard or focus state; the first Tab after opening the bell lands on an `opacity-0` kebab, so focus visibly vanishes | `ui/src/novee/components/NotificationItem/NotificationItem.tsx:160-188`, `webapp/src/lib/notifications/components/NotificationItem.tsx:345` |
| F2-09 | Dashboard "Completed on" filter | `DateRangeFilter` trigger and clear × are divs; Radix merges handlers but never `tabIndex`, so neither can be reached | `ui/src/novee/components/DateRangeFilter/DateRangeFilter.tsx:58-84` |
| F6-16 | Legacy asset form repository picker | `common/RepositoryMultiSelect` trigger is a non-focusable div with no hover and an `outline-none` input; the onboarding copy of the same component is a proper button | `webapp/src/lib/common/components/RepositoryMultiSelect.tsx:389-422` |
| F5-11 / F7-15 | Assessment wizard recurrence days | Day pills are `div onClick` with no role, focus or `aria-pressed`; unselected pills are painted with the hover token so every day looks pre-highlighted; duplicated in two wizards | `webapp/src/lib/onboarding/components/ApplicationAssessmentForm/ApplicationWizardSummaryView.tsx:281-293`, `webapp/src/lib/onboarding/v2/AssessmentWizardSummaryView.tsx:429-441` |
| F5-01 | Onboarding assessment-type and environment radio cards | `focus-visible:outline-none` plus a border change that the checked card already has; with roving tabindex, Tab lands on the checked card and nothing changes | `webapp/src/lib/onboarding/v2/AssessmentTypeCard.tsx:81-83`, `webapp/src/lib/assets/components/AssetEnvironmentSection.tsx:116-119` |
| F6-04 | Assessment wizard asset picker (filled state) | The DS Input's `read-only:focus-visible:ring-0` rule outranks the consumer's focus classes, so a filled picker shows no focus; the empty state shows a ring | `webapp/src/lib/common/components/AssetSelectDropdown/AssetSelectDropdown.tsx:110-113`, `ui/src/shadcn/components/ui/input.tsx:16` |
| F4-14 | Network traffic rows | Focus ring is the unflipped primitive brand-500 `#e0d6ff`: 1.38:1 on white, and clipped by the card's `overflow-hidden` | `ui/src/novee/components/NetworkTrafficPanel/NetworkTrafficRow.tsx:97-98` |
| F6-07 | Rich text toolbar (prompt editor, onboarding testing instructions) | Pressed state is `bg-surface-secondary`, the same hex as `ToolbarIconButton` hover and about 1.03:1 on white; a click produces no visible change under the cursor | `ui/src/novee/components/RichTextEditor/RichTextEditor.tsx:203-205`, `ToolbarIconButton.tsx:13` |
| F7-01 | Chat history | Selected thread and hovered thread are both `bg-surface-hover`; no weight, bar or `aria-current` | `webapp/src/lib/chat/components/ChatHistory.tsx:150-152` |
| F7-14 | Issue action menu, status and severity chip pickers | Items cancel the DS highlight (`focus:bg-transparent data-[highlighted]:bg-transparent`) while staying in the roving tab order, so arrow-keying shows nothing on them | `webapp/src/lib/issues/single-issue/components/issue-action-menu-items.tsx:143-147`, `webapp/src/lib/issues/components/ChipPickerItem.tsx:25` |
| F7-12 | Webapp-wide | Seven focus-visible recipes; the border-only and tint-only ones (`AssessmentTypeCard`, `FacetCheckboxRow`) are identical to hover and about 1.06:1 on white | `webapp/src/lib/onboarding/v2/AssessmentTypeCard.tsx:81`, `webapp/src/lib/common/table/facet/FacetCheckboxRow.tsx:48` |

### 3.3 Hover: two families, three intensities, several invisible

Hue family by role, with representative evidence:

- **Purple tint (`#f2efff` / `#513a84`)**: sidebar items (`sidebar.tsx:483`), DataGrid rows (`DataGridRow.tsx:166`), ghost and outline buttons, `IconButton`, `NotificationBellButton` (`:11`), `RowActionButton` (`surface-hover-strong`, `:36`), inputs and select triggers (`input.tsx:13`), dropdown, select and command items (`dropdown-menu.tsx:84`), `DataGridFilterOptionList`, `TimePicker`, `PaginationLink`, `CollapsibleGroupHeader` (`:67`), ActionGallery (`:176`), chat history, `MobileAssetForm` cards, the EditableTitle pencil (`:187`).
- **Neutral grey (`#f9f9fb` / `#32333a`, or slate-300)**: `ToolbarIconButton` (`:13`), `CopyToClipboardButton` ghost (`:68`), `GroupBySelect` (`:114`), `DateFilter` presets (`:206`), `DataGridColumnFilter` (`:159`), `DataGridDateFilter` (`:170`), `DataGridColumnManager` (`:90`), `SortableHeader` (`muted/50`), `FileExplorer` tree rows (`surface-tertiary`), the account menu (`SidebarAccountMenu.tsx:48,161`), `HelpMenu` (`:29`), `PageTopBarProjects` (`:135`), `StepRailButton` (`:29`), `MarkdownSectionsTab` (`:146`), `IntegrationStepper` (`:192`), `BrowsingTabBar` (`:56`), `AssetSelectDropdown` rows (`:187`), `SeverityThresholdSelect` (`:90`).
- **Border only (brand-900 or brand-600)**: `Card interactive`, `CardLink`, `OptionCard`, `TestingCategoryTile`, `AssessmentTypeCard`, `QuickFilter`, `ReportKindCard` (`:65`, deliberately, because of T1), `FlowNodeCard`, `GalleryCard`.
- **Text only or none**: `NovTabs` underline, `VeeVeeTabStrip`, `LinkCrumb`, select clear ×, chip remove buttons, `Button secondary` (no visible change, F1-08), the account-menu trigger whose hover color equals the sidebar background in both themes (F3-05).

Within the purple family three intensities are in use (brand-200, brand-300, brand-300 at 50% alpha), and on secondary surfaces brand-200 is 1.00:1, so `NetworkTrafficRow`, `LogRow` and `NotificationItem` have no perceivable hover in light mode (F4-07). The same control can switch family with the theme: `Button outline` hovers purple in light and neutral in dark because `dark:hover:bg-input/50` overrides `hover:bg-accent` (F1-23). Icon buttons that sit side by side in one toolbar hover purple, grey or not at all (F1-06, F6-24). The most visible single case is the sidebar: nav items flash purple on hover and the account row directly beneath them does nothing (F3-05, F3-06).

### 3.4 Selected: six mechanisms, usually equal to hover

Selection is encoded six different ways: `aria-pressed` with the `ACTIVE_FILTER` / `ACTIVE_GHOST` recipes in `button.tsx:10-18`; `data-[state=on]` in `toggle.tsx`; `data-[state=active]` in `tabs.tsx` and `NovTabs`; `data-[active=true]` in `sidebar.tsx`; `data-[selected]` or `data-[state=selected]` on rows; and prop-conditional class strings in at least nine webapp files, often with no ARIA state at all (F7-18 lists eight surfaces where a screen reader cannot tell which item is current).

Because of T1, the selected fill equals the hover fill wherever both use system tokens: DataGrid rows collapse hover, selected, open and focus-within onto one hex and define no selected-plus-hover (F4-04); server-grouped rows then drop the selected tint entirely (F4-05); the sidebar current page equals hover, mousedown and open-hover (F3-01, F8-03); the ActionGallery rail, `TimePicker` presets, `PromptCard`, integration category pills and the chat history all show selected as hover (F3-07, F2-03, F3-27, F5-04, F7-01). Where a non-color cue exists it is inconsistent: `font-medium` on the sidebar and `SegmentedControl`, a check glyph in `Combobox` and `PageTopBarProjects`, a dot on `DataGridFilterTrigger`, a solid icon swap in the sidebar, and nothing on `QuickFilter`, facet pills, `GroupBySelect` or filter buttons (F1-14, F2-05). The pressed look of primary and destructive buttons drops their solid fill for a pale tint whose border is paler than the hover border, so a hovered unselected filter button out-ranks the selected one (F1-03). `FileExplorer` is the one component that follows the industry pattern (neutral hover, brand-tinted and bold selected with `aria-selected`), which makes it the inverse of the table beside it (F4-08).

### 3.5 Focus: nine recipes and ten suppressions

Recipes in use: `ring-[3px] ring-ring/50` plus `border-ring` (the shadcn default, 31 files), `ring-2 ring-ring` solid (16 files), `ring-[1px] ring-inset` (`SelectTrigger`, `AssetSelectDropdown`), `ring-border-focus` with `ring-offset-2` (`OptionCard`), `ring-brand-900`, `ring-brand-700` (`AttackChainStepCard`), `ring-brand-500` (`NetworkTrafficRow`), `outline-1 outline-ring`, `inset-ring-border-focus` (`FlowNodeCard`), border-only (`AssessmentTypeCard`, `TemplateEditorForm`), and tint-only (`FacetCheckboxRow`). Thirty-two utilities use `focus:` instead of `focus-visible:`; on Radix menu items that is correct (focus follows the pointer there), but on buttons and cards it means a mouse click also paints a ring. Ten sites set `focus-visible:ring-0` or `outline-none` with no replacement (`MobileAssetForm.tsx:1473`, `AssetCreateUpdatePage.tsx:2628`, `ScanCustomeHeadersHeaderField.tsx:119`, `InlineTitleInput.tsx:41`, `TemplateEditorForm.tsx:401,433,484`, `TemplateTagInput.tsx:48`, `SimpleMultiSelect.tsx:860`, `OptimizablePromptField.tsx:143`). Some are backed by a `focus-within` ring on a wrapper; `TemplateTagInput` is not (F6-15). The ring is clipped by `overflow-hidden` containers in rows and cards, which is where an inset variant would be needed and none is defined.

### 3.6 Pressed, open, current and disabled

- **Pressed (mouse-down)**: no `:active` rule exists on `Button`, `Toggle`, menu items or rows; the sidebar's `active:` rule paints the same purple as hover, so a click gives no feedback anywhere (F1-03, F3-01). `ToolbarIconButton` invites `aria-pressed` in a comment but styles no pressed state; `RichTextEditor` patches it with a class that equals hover (F1-30, F6-07).
- **Open**: triggers hold `bg-accent` (purple), `bg-surface-secondary` (grey), a 1 px inset ring, `ring-0`, or nothing, depending on the component (8 findings).
- **Current**: the sidebar is the only surface with a current concept and it uses `data-active` with the hover token and no `aria-current`; breadcrumbs, steppers and the project switcher mark current by class alone (F7-18).
- **Disabled**: `Input` and `Checkbox` use the tuned disabled tokens; `Textarea`, `Radio`, `Switch`, `Slider` and `SelectTrigger` use `opacity-50`; `SegmentedDateInput` steppers use `opacity-30`; the Jira wizard patches one of two adjacent selects back to tokens (F6-10). Report filter chips encode unselected as `opacity-40`, which reads as disabled (F5-26).

### 3.7 Consumer drift in the webapp

Nine pickers (account menu, help menu, project switcher, severity and category selects, asset picker, ticketing user picker, both repository pickers) hand-roll option rows with their own hover and no keyboard highlight instead of using `DropdownMenuItem`, `CommandItem` or `DataGridFilterOptionList` (F2-22). `DataGridColumnFilter` is a copy of `DataGridFilterOptionList` down to the `SEARCH_MIN_OPTIONS` constant, differing only in hover hue, and both render in the same grid column (F2-02). Three dashboard widgets each re-implement a list row. `text-muted-foreground` is used in two files but defined nowhere in `theme.css`, so placeholders render in body color (F6-35). Frozen primitives appear in state styling: `brand-600` and `brand-700` rings, `slate-850` text at 2.51:1 on the dark surface (F7-24).

### 3.8 Guardrails today

`scripts/audit-tokens.mjs` checks token arithmetic and dark-mode collapses, and already reports the `surface-hover` equals `surface-selected` collapse group, but nothing fails on it. `scripts/scan-colors.mjs` flags frozen primitives but says nothing about which hover or focus token a component reaches for. ESLint has no rule on state classes. Storybook has no pseudo-states addon and only a handful of state stories (`Selected` ×4, `Active` ×3, `AllStates` ×1), so the inconsistencies are not visible in the rendered source of truth.

<!-- PART4: proposed state model -->

<!-- PART5: fix list, guardrails, rollout -->

<!-- PART6: open decisions and appendix -->
