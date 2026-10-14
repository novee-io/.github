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

## 4. Proposed state model: transient is neutral, persistent is brand

Three candidate models were drafted independently (neutral surfaces with a brand cue; a monotonic purple ladder; and transient-neutral, persistent-brand), scored by three judges with different lenses (accessibility and standards, engineering and migration cost, product perception), and the winner was finalised with the best ideas grafted from the other two. The scores were close (156, 146, 144 of 210). The winner keeps brand presence exactly where the product has to say "this is where you are" or "this is what you chose", removes it from pointer feedback, and lands with the least churn because most of the ~100 purple-hover call sites change value through the token layer without a code edit.

### 4.1 Principles

1. **Classify every state by duration.** Transient states (hover, mousedown, a trigger held open, the keyboard highlight in a menu) are feedback about the pointer: one or two steps on the slate scale, never the brand hue.
2. **Persistent states are facts about the model.** Selected, current page, toggle on and checked use a brand tint fill plus exactly one brand non-color cue (a 2 px edge, a 2 px bar or underline, a check glyph, or the checked box) plus a dedicated selected-plus-hover step so the cue survives the pointer.
3. **Focus keeps purple and nothing else does.** A 2 px solid outline in `--color-ring` with a 2 px gap, on `:focus-visible` only, never a border swap, never removed. Inside clipped containers the ring sits inset with a 1 px page-colored inner stroke so it stays at 3:1 on any fill.
4. **Two grounds, two ladders.** Targets on the page use `surface-hover`, `surface-pressed`, `surface-selected` and `surface-selected-hover`. Targets on the secondary ground (sidebar, tab tracks, filled group headers, the network-traffic card) use `surface-secondary-*` rungs mixed over that ground, so every rung is visible where it is used.
5. **Two cue tokens, neither of which is the ring.** `--color-border-selected` is the edge of a selected pill, segment, tab or card on the page. `--color-indicator-selected` is the bar, underline, check glyph, radio dot, and every edge on a secondary ground. Both differ from `--color-ring` in both themes.
6. **Selected tabs and segments are inert to hover.** Everything else takes the selected-hover rung and keeps its cue. Open is hover held (or the field focus stroke on pickers) plus a rotated chevron.
7. **Disabled is tokens, not opacity**, except on whole non-interactive tiles. Disabled menu items that carry a reason stay focusable with `aria-disabled`; items that are merely inert use Radix `disabled`.
8. **One attribute per state, styled from the attribute.** `aria-pressed`, `aria-selected`, `aria-checked`, `aria-expanded`, `aria-current="page"`, `data-[state=…]`: never a prop-only class string. Tailwind compiles bare `aria-current:` to `[aria-current="true"]`, so the bracket form `aria-[current=page]:` is required.
9. **Tokens name the role.** Every component `-active` token becomes `-selected`, `-current`, `-pressed` or `-focus` with a deprecated alias for one release. `.dark` overrides stay on semantic tokens. No two state roles share a dark hex.

**One deliberate departure from the industry majority.** Consensus rule 4 says the selected fill should stay neutral with brand only in the cue. This model keeps a brand tint for persistent fills (the Material secondary-container and Atlassian `background.selected` tradition) for three reasons: the slate ladder has no spare neutral rung that is one step past hover and still more than 1.1:1 from pressed; `surface-selected` already exists as a documented brand tint with more than forty consumers and keeps its name and role; and the tint is never the only cue, so it only has to differ from hover. The neutral alternative remains a two-token swap (`surface-selected` and `surface-selected-hover` to slate-500 and slate-600) if design rejects the tint. This is open decision 1 in section 6.

### 4.2 The ladder

Contrast ratios were computed with WCAG 2.x relative luminance; `color-mix` values were resolved per channel. Light values are on the white page, dark values on `#25272d` unless stated.

| State | Token | Light | Dark | Required cue | Mechanism |
|---|---|---|---|---|---|
| rest | `surface-primary`, `border-primary` | `#ffffff`, border `#e0e1e6` | `#25272d`, border `#3f4046` | none | no attribute |
| hover (page) | `--color-surface-hover` = slate-300; edges `--color-border-hover` = slate-810 | `#f0f0f3` (1.14:1); border `#abacb1` | `#3b3d42` (1.37:1); border `#717377` | none; rows lift text to primary, cards add shadow | `hover:` |
| hover (secondary ground) | `--color-surface-secondary-hover` | `#ececef` (1.12:1 vs `#f9f9fb`) | `#42434a` (1.28:1 vs `#32333a`) | none | `hover:bg-sidebar-accent` |
| hover-strong | `--color-surface-hover-strong` = slate-400 | `#e8e8ec` | `#484a4f` | none | a control nested in an already-hovered surface; drag-over |
| pressed | `--color-surface-pressed` = slate-700; CTA pressed tokens | `#cdced6` (1.57:1); primary `#613da9` | `#515257` (1.92:1) | none; lasts the press | `active:`, suppressed while `data-[state=open]` |
| selected | `--color-surface-selected` = brand-400 + `--color-border-selected` or `--color-indicator-selected` + `--color-text-selected` | fill `#eae3ff` (1.24:1, 1.09:1 vs hover); edge `#8149eb` (5.14:1); label `#6f42c5` (5.19:1) | fill `#553c8d` (1.72:1, 1.25:1 vs hover); edge `#8e55fd` (3.46:1); label `#d4c6ff` (5.51:1) | one of: 2 px edge, 2 px bar or underline, check glyph, checked box, inset ring on solid buttons; plus `font-medium` | `aria-selected`, `aria-pressed`, `aria-checked`, `data-[state=on|active|checked]`, `data-[selected]` |
| selected + hover | `--color-surface-selected-hover` = brand-500 | `#e0d6ff` (1.11:1 vs selected) | `#6041a1` (1.15:1 vs selected) | unchanged | `aria-pressed:hover:` etc.; tabs and segments take none |
| current (sidebar) | `--nav-item-bg-current` = `surface-secondary-selected` + `--nav-item-indicator-current` 2 px bar | fill `#ded0fc`, bar `#8149eb` (4.89:1 vs ground) | fill `#574188`, bar `#c3b0ff` (6.57:1 vs ground) | bar + `font-medium` + solid icon | `aria-current="page"` styled via `aria-[current=page]:` |
| open | hover fill held; field triggers hold the focus stroke | `#f0f0f3` or stroke `#8e55fd` | `#3b3d42` or stroke `#ae92ff` | chevron rotates; `aria-expanded` | `data-[state=open]` |
| highlighted (menu row) | `--menu-item-bg-hover` = `surface-hover` via `--color-accent`; selected option = check in `--menu-item-indicator-selected` + `font-medium`, no fill | `#f0f0f3`; check `#8149eb` | `#3b3d42`; check `#c3b0ff` | check glyph or checkbox | Radix `[data-highlighted]`, cmdk `data-[selected=true]` |
| checked (checkbox, radio, switch) | `--checkbox-fill-checked` = primary CTA, with hover and pressed twins | `#8149eb` (white 5.14:1) | same | glyph, dot or thumb position | `data-[state=checked]` |
| focus | `--color-ring` = `--color-border-focus`; `--focus-ring-width` 2 px; `--focus-ring-offset` 2 px | `#8e55fd` (4.31:1 vs page, 3.48:1 inset on selected) | `#ae92ff` (5.94:1 vs page, 3.46:1 inset on selected) | the ring | `:focus-visible` only, via `focus-ring`, `focus-ring-inset` or the field recipe |
| disabled | `text-disabled`, `input-bg-disabled`, `action-primary-cta-disabled`, `surface-disabled` (gets its own dark rung) | text `#b9bbc6`, fill `#f9f9fb` | text `#8b8d98` (4.52:1), fill `#32333a` | `cursor-not-allowed`; no hover or pressed | `:disabled`, `aria-disabled`, `[data-disabled]` |

### 4.3 Focus recipe

Three exported constants in a new `ui/src/novee/styles/focus-ring.ts`, backed by two `@utility` rules in `theme.css`:

- `FOCUS_RING` (`focus-ring`) for standalone controls: `outline: 2px solid transparent; outline-offset: 2px`, and under `:focus-visible` the outline turns solid in `--color-ring`. The transparent rest outline is the forced-colors-safe pattern.
- `FOCUS_RING_INSET` (`focus-ring-inset`) for anything clipped or touching a neighbour (rows, tabs, segments, sidebar items, controls nested in a row): the same ring at `-2px` plus a 1 px page-colored inner stroke written into Tailwind's `--tw-inset-shadow` so it composes with `ring-1` selected edges instead of overriding them.
- `FOCUS_FIELD` for inputs and pickers: border in `--input-border-focus` plus a 1 px inset ring; `data-[state=open]` reuses it; `FOCUS_FIELD_WITHIN` is the `focus-within` twin for composite boxes.

Neither constant carries `outline-none` or `outline-hidden`: with Tailwind 4.1.14 the `.outline-hidden` rule is emitted after the utilities at equal specificity and would cancel the ring, so every migrated element drops its `outline-none` in the same edit. The old `ring-ring/50` recipe composites to 1.98:1 in light and 2.57:1 in dark and is removed everywhere, including the `@layer base` rule. `focus:` without `-visible`, `ring-0`, and brand primitives in rings are forbidden.

### 4.4 Rules per family

| Family | Hover | Selected | Selected + hover | Pressed | Focus | Open / current | Disabled |
|---|---|---|---|---|---|---|---|
| Buttons (Button, IconButton, ToolbarIconButton, RowActionButton, PaginationLink) | primary brand-1100; outline and ghost `surface-hover`; nested in a hovered row `surface-hover-strong` | one `ACTIVE` recipe under `aria-pressed`: selected fill, `text-selected`, 2 px `border-selected` edge; solid variants keep their fill and add a 2 px inset ring at 3.89:1 | `btn-filter-bg-selected-hover` | `active:` pressed token per variant | `FOCUS_RING`; in-row buttons inset | open holds the hover fill; pagination current = `aria-[current=page]` | tokens, `opacity-100` |
| Toggles and filter chips (Toggle, ToggleGroup, SegmentedControl, QuickFilter, FacetToggleChip, KPI, ActionGallery rail) | `data-[state=off]:hover:bg-surface-hover`; pills add `border-hover`; KPI border + shadow | `data-[state=on]` or `aria-pressed`: selected fill, `text-selected`, `border-selected` edge, `font-medium`; the rail on the secondary ground uses the sidebar recipe | `surface-selected-hover`; segments and Toggle inert | `surface-pressed` | `FOCUS_RING`; segments inset | open pill keeps the selected recipe | `text-disabled`, no opacity |
| Menu and list items (DropdownMenuItem, SelectItem, CommandItem, MultiSelectItem, option lists, presets, webapp pickers) | one highlight `bg-accent` (now neutral) via `focus:`, `[data-highlighted]`, `data-[selected=true]`; never suppressed | no fill: check in `indicator-selected` + `font-medium`, or the checkbox; `aria-checked` or `aria-selected` on the row | highlight over the check | `surface-pressed` on plain rows | the highlight is the indicator; standalone list buttons inset ring | sub-trigger holds the highlight; `aria-current` on the project switcher and open thread | `text-disabled`; inert items Radix-disabled, items with a reason `aria-disabled` and focusable |
| Tabs (NovTabs underline, pill, segmented, browsing; shadcn Tabs deprecated) | underline: text to primary; pill and segmented: `tabs-nav-item-bg-hover`, inactive only | underline: 2 px bar in `tabs-nav-item-indicator-selected` + `text-selected` + `font-medium`; pill: selected fill + 2 px edge; browsing: white card + 2 px top bar | none (inert) | none | inset ring on every trigger | More trigger holds hover | `text-disabled` |
| Sidebar and vertical navigation (SidebarMenuButton, AppSidebarItem, account trigger, rails, steppers, breadcrumb) | `sidebar-accent` (= `surface-secondary-hover`) on every row including the account trigger | `data-[active=true]` and `aria-[current=page]`: `sidebar-selected` fill + 2 px left bar in `sidebar-indicator` + `font-medium` + solid icon; rails `aria-current="step"` + edge | `sidebar-selected-hover`; bar and weight stay | `sidebar-pressed` | inset ring | collapsible `aria-expanded` + chevron + hover fill | `text-disabled` |
| Table and list rows (one DataGridRowShell, Table, headers, NetworkTrafficRow, FileExplorer, DetailCell) | `table-row-hover` only when clickable, selectable or expandable; rows on a secondary card use the secondary ladder; headers only when sortable | `data-[selected]` or `aria-selected`: `table-row-selected` + checked checkbox + 2 px bar; tree rows the same bar and `text-selected` | `table-row-selected-hover`; text promoted to primary | `table-row-bg-pressed` | clickable rows get `tabIndex=0`, Enter and Space, inset ring; `focus-within` tinting removed | `has-[[data-state=open]]` holds hover; chevron + `aria-expanded` | `text-disabled`, no hover |
| Selectable cards (OptionCard and OptionCardGroup, Card interactive, CardLink, KPI, report and onboarding cards) | `card-border-hover` + `shadow-md`, no fill (OptionCard keeps its lift) | `data-[state=checked]` or `aria-pressed`: selected fill + `card-border-selected` edge + indicator slot (check or radio dot) + `font-medium` | `card-bg-selected-hover`; edge and indicator unchanged, no lift | `surface-pressed` | `FOCUS_RING`, visible on the checked card of a roving group | step rails `aria-current="step"` | `card-bg-disabled`, `text-disabled`, `aria-disabled`; only whole tiles use opacity |
| Inputs and pickers (Input, Textarea, SelectTrigger, Combobox, MultiSelect, date and tag inputs, editors) | `border-hover` only; no fill (`--input-bg-hover` = `--input-bg`) | a trigger holding a value renders as an outline Button with `active` | on picker buttons | none on text fields | `FOCUS_FIELD`; composite boxes `FOCUS_FIELD_WITHIN`; read-only keeps the ring with a dashed border | open = the focus stroke + chevron | input disabled tokens at `opacity-100` |
| Checkbox, radio, switch | unchecked: `surface-hover` fill + `border-hover-strong` edge; checked: brand-1100 | brand-1000 fill with white glyph (5.14:1) via `data-[state=checked]`; mirrored `--radio-*` and `--switch-*` tokens | checked hover brand-1100 | CTA pressed on checked | `FOCUS_RING` | n/a | token fills; switch track `surface-disabled` |

## 5. Fix list

Every one of the 234 verified findings maps to a row below or to the two won't-fix items; the mapping was checked mechanically. Priorities: P0 accessibility and the token flip, P1 cross-family hue or mechanism mismatches, P2 intensity and naming.

### 5.1 Token changes in `theme.css`

Summary of the 37 changes (18 additions, 14 value changes, 3 deprecated aliases, 2 retirements). Every new token has a light and a dark value; the only dark pairing between a state token and a non-state token is `indicator-selected` with `emphasis-link-hover` (both brand-700), which is allow-listed by name so it cannot grow silently.

| Kind | Token | Light | Dark | Why |
|---|---|---|---|---|
| add | `--color-surface-pressed` | var(--color-slate-700) = #cdced6 | color-mix(in srgb, var(--color-slate-100) 20%, var(--color-slate-1000)) = #515257 | Mousedown step (F8-07, F1-28, F3-03); 1.57 / 1.92:1 vs page; unique. |
| add | `--color-surface-selected-hover` | var(--color-brand-500) = #e0d6ff | color-mix(in srgb, var(--color-brand-900) 56%, var(--color-slate-1000)) = #6041a1 | Additive selected+hover (CR-05): 1.11 / 1.15:1 above selected. |
| add | `--color-surface-secondary-hover` | color-mix(in srgb, var(--color-slate-1000) 6%, var(--color-slate-200)) = #ececef | color-mix(in srgb, var(--color-slate-100) 8%, var(--color-slate-950)) = #42434a | Hover on bg-secondary grounds (F3-05, F3-24, F4-07): 1.12 / 1.28:1. |
| add | `--color-surface-secondary-selected` | color-mix(in srgb, var(--color-brand-900) 25%, var(--color-slate-200)) = #ded0fc | color-mix(in srgb, var(--color-brand-900) 40%, var(--color-slate-950)) = #574188 | Current-page fill on the sidebar ground: 1.37 / 1.51:1 vs the ground. |
| add | `--color-surface-secondary-selected-hover` | color-mix(in srgb, var(--color-brand-900) 33%, var(--color-slate-200)) = #d6c3fc | color-mix(in srgb, var(--color-brand-900) 50%, var(--color-slate-950)) = #60449c | Hovered current item: 1.11:1 above secondary-selected. |
| add | `--color-surface-secondary-pressed` | color-mix(in srgb, var(--color-slate-1000) 16%, var(--color-slate-200)) = #d7d7da | color-mix(in srgb, var(--color-slate-100) 23%, var(--color-slate-950)) = #616267 | Sidebar mousedown (F3-03): 1.37 / 2.07:1 vs the ground. Unique. |
| add | `--color-border-selected` | var(--color-brand-1000) = #8149eb | var(--color-brand-900) = #8e55fd | The 2px EDGE of a selected pill, segment, tab or card on the page ground. Light brand-1000: 5.14:1 vs white, 3.94:1 vs the rest border, 4.14:1 vs the selected fill, 1.19:1 from the brand-900 focus rin |
| add | `--color-indicator-selected` | var(--color-brand-1000) = #8149eb | var(--color-brand-700) = #c3b0ff | Bar, underline, check glyph, radio dot and any edge on a secondary ground. Light brand-1000 (= emphasis-link): 5.14:1 vs page, 4.89:1 vs sidebar, 4.14:1 on selected, 3.73:1 on selected-hover, 3.56:1 o |
| add | `--color-border-hover-strong` | var(--color-slate-825) = #8b8d98 | color-mix(in srgb, var(--color-slate-100) 50%, var(--color-slate-1000)) = #929396 | Hover edge for checkbox, radio and switch, whose rest edge is already border-dark: with border-hover now slate-810 the checkbox would hover to its own rest colour (light border-hover = border-dark = # |
| add | `--color-text-selected` | var(--color-brand-1100) = #6f42c5 | var(--color-brand-600) = #d4c6ff | Label on a page-ground selected fill: 5.19 / 4.67 light, 5.51 / 4.81 dark. |
| add | `--color-action-primary-cta-pressed` | color-mix(in srgb, var(--color-brand-1000) 65%, var(--color-slate-1000)) = #613da9 | restated = #613da9 | Primary mousedown; white 7.64:1 (F1-05, F8-07). |
| add | `--color-action-destructive-cta-pressed` | color-mix(in srgb, var(--color-red-700) 80%, var(--color-slate-1000)) = #a5191f | restated = #a5191f | Destructive mousedown; white 7.61:1. |
| add | `--color-accent-info-light` | var(--color-brand-300) = #f2efff | var(--color-brand-dark-200) = #3c315b | Static brand wash so surface-selected is a state token only (F1-34, F8-08). |
| add | `bridge: --color-muted-foreground / --muted-foreground` | var(--color-text-tertiary) = #6e6b79 (5.20:1) | #8b8d98 (4.52:1) | 62 webapp text-muted-foreground sites emit no CSS today (F6-35, F4-24). |
| add | `bridge: --color-sidebar-selected, -selected-hover, -pressed, -indicator (+ :root twins)` | #ded0fc, #d6c3fc, #d7d7da, #8149eb | #574188, #60449c, #616267, #c3b0ff | sidebar.tsx utilities (F3-01, F3-02, F3-03, F8-03). |
| add | `bridge: --color-table-row-selected, --color-table-row-selected-hover` | #eae3ff, #e0d6ff | #553c8d, #6041a1 | Named utilities for DataGridRow, DataGridDataRow, TableRow (F4-01, F4-03, F4-04, F4-05). |
| add | `--focus-ring-width, --focus-ring-offset (:root)` | 2px, 2px | 2px, 2px | Read by the focus-ring utilities; asserted by audit-tokens (F8-07, F8-10). |
| add | `component tokens: --btn-*-bg-pressed, --btn-primary-ring-selected, --btn-destructive-ring-selected, --btn-filter-bg/border/surface-selected(-hover), --table-row-bg-selected(-hover)/-pressed/-indicator-selected, --menu-item-indicator-selected, --nav-item-bg-pressed/-current(-hover)/-indicator-current, --input-border-focus, --checkbox-fill-checked(-hover/-pressed), --radio-*, --switch-track-bg(-hover/-checked/-checked-hover/-disabled), --tabs-nav-item-bg/indicator/border-selected, --tabs-browsing-item-bg/surface/indicator-selected, --kpi-bg-selected(-hover)/-border-selected, --card-*` | each is var() of the semantic token the diff names; ring-selected -> color-mix(in srgb, var(--color-text-on-ac | inherited through the semantic .dark overrides; component tokens never get .dark entries | Every family gets named pressed, selected, selected-hover, current and indicator tokens (F8-06, F8-16, F5-25, F6-08, F6-28, F8-02); the pill edge and browsing bar give every tab variant a structural c |
| change | `--color-surface-hover` | brand-300 -> var(--color-slate-300) = #f0f0f3 | brand-dark-300 -> color-mix(in srgb, var(--color-slate-100) 10%, var(--color-slate-1000)) = #3b3d42 | Hover is neutral (CR-01); the brand-tint selected fill is the one recorded departure. |
| change | `--color-surface-hover-strong` | brand-400 -> var(--color-slate-400) = #e8e8ec | brand-dark-400 -> color-mix(in srgb, var(--color-slate-100) 16%, var(--color-slate-1000)) = #484a4f | Role narrows to a control nested in a hovered surface and drag-over. |
| change | `--color-surface-selected` | brand-300 -> var(--color-brand-400) = #eae3ff | brand-dark-300 -> color-mix(in srgb, var(--color-brand-900) 46%, var(--color-slate-1000)) = #553c8d | A lightness step above the neutral hover; dark leaves the chip grid. |
| change | `--color-border-hover` | brand-900 -> var(--color-slate-810) = #abacb1 | brand-800 -> color-mix(in srgb, var(--color-slate-100) 35%, var(--color-slate-1000)) = #717377 | Transient edges; dissolves the border-hover = focus = hover-muted = link dark collapse (F8-12). |
| change | `--color-action-primary-cta-disabled (.dark only)` | unchanged brand-700 #c3b0ff | brand-dark-300 -> color-mix(in srgb, var(--color-brand-1000) 40%, var(--color-slate-850)) = #6d599f | Was identical to the selected fill (F1-22, F8-22). |
| change | `--color-surface-disabled (.dark only)` | unchanged slate-600 #d9d9e0 (1.40:1 vs page, 1.08:1 vs border-primary) | slate-900 #3f4046 -> color-mix(in srgb, var(--color-slate-100) 14%, var(--color-slate-1000)) = #44454a | The third F8-12 collapse: in dark, surface-disabled was the border colour (border-primary = border-secondary = #3f4046), so --switch-track-bg-disabled would have drawn a disabled track in the border h |
| change | `--btn-filter-bg-hover, --table-head-column-bg-hover, --menu-item-bg-hover` | -> var(--color-surface-hover) | inherited | 1.05:1 hovers become the neutral step (F8-04, F4-06, F8-05). |
| change | `--nav-item-bg-hover` | -> var(--color-surface-secondary-hover) | inherited | The sidebar sits on bg-secondary (F3-01, F3-05). |
| change | `--input-bg-hover` | -> var(--input-bg) | inherited | Fields hover by border only (F6-05, F6-06). |
| change | `--checkbox-bg-hover, --checkbox-border-hover` | -> var(--color-surface-hover); -> var(--color-border-hover-strong) | inherited | Unchecked hover is neutral, one step past the rest edge (F6-09). |
| change | `--tabs-nav-item-surface-hover / -selected, --tabs-browsing-item-bg-inactive-hover` | -> text-primary; -> text-selected; -> surface-secondary-hover | inherited | Ink hover, brand selected (F3-10, F3-11, F3-24). |
| change | `--kpi-bg-hover, --btn-primary-border-focus` | -> var(--kpi-bg); -> var(--color-border-focus) | inherited | Cards hover by edge (F1-02); focus must not alias hover (F8-18). |
| change | `bridge: --color-accent / --accent, --color-accent-foreground, --color-ring / --ring, --color-sidebar-ring` | accent -> var(--menu-item-bg-hover); ring -> var(--color-border-focus) | inherited | accent is transient in shadcn (F8-05); focus is its own role (F8-06). |
| change | `base `* { @apply border-border outline-ring/50 }` and the swish / glowPulse literals` | outline-ring/50 (1.98:1) -> outline-ring; literals -> tokens | 2.57:1 -> 5.94:1 | UA fallback outlines get the full ring (F7-13, F5-10); no literals (F8-23). |
| alias | `--color-surface-hover-subtle, --color-border-hover-muted` | var(--color-surface-hover), var(--color-border-hover) (deprecated) | same | brand-200 was the source of the invisible hovers (F4-07, F2-12, F1-13). |
| alias | `--btn-filter-*-active, --btn-ghost-bg-active, --kpi-*-active, --tabs-*-active, --nav-item-bg-active, --input-border-active` | each = var() of its -selected / -current / -focus twin | inherited | -active meant five things (F8-06, F1-28, F3-23, F7-26); aliases keep consumers compiling. |
| alias | `Button variant `secondary`` | same string as `outline`, @deprecated | same | bg-secondary is the page colour (F1-08). |
| retire | `--color-action-secondary-cta, --color-action-secondary-cta-hover` | deleted (@theme and .dark) | deleted | Zero consumers once --menu-item-bg-hover moves (verified by grep). |
| retire | `--color-surface-selected as an info or static fill; ACTIVE_GHOST; dark:bg-input overrides` | static panels -> accent-info-light; one ACTIVE recipe | same | surface-selected becomes a pure state token (F1-34, F8-08, F6-31); F1-04, F1-23, F6-28, F3-26. |

The complete diff against the audited `theme.css` (semantic, component, bridge, dark and base layers, plus the two new focus utilities):

```diff
--- a/frontend/packages/ui/theme.css
+++ b/frontend/packages/ui/theme.css
@@ semantic: Surface (lines 250-258) @@
-  /* Brand hover triad ... (three-line comment, now false) */
-  --color-surface-hover: var(--color-brand-300);
-  --color-surface-hover-subtle: var(--color-brand-200);
-  --color-surface-hover-strong: var(--color-brand-400);
+  /* STATE RULE: transient (hover, hover-strong, pressed) = slate steps; persistent (selected, selected-hover) = brand tint + a brand cue (border-selected edge or indicator-selected bar / check); secondary-ground rungs mix over slate-200 / slate-950. */
+  --color-surface-hover: var(--color-slate-300);
+  --color-surface-hover-strong: var(--color-slate-400);
+  --color-surface-pressed: var(--color-slate-700);
+  --color-surface-hover-subtle: var(--color-surface-hover); /* @deprecated */
-  --color-surface-selected: var(--color-brand-300);
+  --color-surface-selected: var(--color-brand-400);
+  --color-surface-selected-hover: var(--color-brand-500);
+  --color-surface-secondary-hover: color-mix(in srgb, var(--color-slate-1000) 6%, var(--color-slate-200));
+  --color-surface-secondary-selected: color-mix(in srgb, var(--color-brand-900) 25%, var(--color-slate-200));
+  --color-surface-secondary-selected-hover: color-mix(in srgb, var(--color-brand-900) 33%, var(--color-slate-200));
+  --color-surface-secondary-pressed: color-mix(in srgb, var(--color-slate-1000) 16%, var(--color-slate-200));
@@ semantic: Text (after --color-text-on-accent) @@
+  --color-text-selected: var(--color-brand-1100);
@@ semantic: Border (lines 290-292) @@
-  --color-border-hover: var(--color-brand-900);
+  --color-border-hover: var(--color-slate-810);
+  --color-border-hover-strong: var(--color-slate-825);
-  --color-border-hover-muted: var(--color-brand-600);
+  --color-border-selected: var(--color-brand-1000);
+  --color-indicator-selected: var(--color-brand-1000);
+  --color-border-hover-muted: var(--color-border-hover); /* @deprecated */
@@ semantic: Action @@
-  --color-action-secondary-cta: var(--color-slate-300);
-  --color-action-secondary-cta-hover: var(--color-slate-400);
+  --color-action-primary-cta-pressed: color-mix(in srgb, var(--color-brand-1000) 65%, var(--color-slate-1000));
+  --color-action-destructive-cta-pressed: color-mix(in srgb, var(--color-red-700) 80%, var(--color-slate-1000));
@@ semantic: Accent (lines 309-313) @@
-  /* Soft tint surfaces ... Info banners use --color-surface-selected ... */
+  /* Soft tint surfaces for banners/alerts. Info banners use --color-accent-info-light; --color-surface-selected is a state token only. */
+  --color-accent-info-light: var(--color-brand-300);
@@ component tokens (:root 386-566, each line verbatim) @@
+  --btn-primary-bg-pressed: var(--color-action-primary-cta-pressed);
+  --btn-primary-ring-selected: color-mix(in srgb, var(--color-text-on-accent) 80%, var(--btn-primary-bg));
-  --btn-primary-border-focus: var(--color-border-hover);
+  --btn-primary-border-focus: var(--color-border-focus);
+  --btn-secondary-bg-pressed: var(--color-surface-pressed);
-  --btn-ghost-bg-active: var(--color-surface-emphasis);
+  --btn-ghost-bg-pressed: var(--color-surface-pressed);
+  --btn-ghost-bg-active: var(--btn-filter-bg-selected); /* @deprecated */
+  --btn-destructive-bg-pressed: var(--color-action-destructive-cta-pressed);
+  --btn-destructive-ring-selected: color-mix(in srgb, var(--color-text-on-accent) 80%, var(--btn-destructive-bg));
-  --btn-filter-bg-hover: var(--color-surface-secondary);
+  --btn-filter-bg-hover: var(--color-surface-hover);
+  --btn-filter-bg-pressed: var(--color-surface-pressed);
-  --btn-filter-bg-active: var(--color-surface-selected);
+  --btn-filter-bg-selected: var(--color-surface-selected);
+  --btn-filter-bg-selected-hover: var(--color-surface-selected-hover);
+  --btn-filter-bg-active: var(--btn-filter-bg-selected); /* @deprecated */
-  --btn-filter-surface-active: var(--color-emphasis-link);
+  --btn-filter-surface-selected: var(--color-text-selected);
+  --btn-filter-surface-active: var(--btn-filter-surface-selected); /* @deprecated */
-  --btn-filter-border-active: var(--color-border-hover-muted);
+  --btn-filter-border-selected: var(--color-border-selected);
+  --btn-filter-border-active: var(--btn-filter-border-selected); /* @deprecated */
-  --table-head-column-bg-hover: var(--color-surface-secondary);
+  --table-row-bg-selected: var(--color-surface-selected);
+  --table-row-bg-selected-hover: var(--color-surface-selected-hover);
+  --table-row-bg-pressed: var(--color-surface-pressed);
+  --table-row-indicator-selected: var(--color-indicator-selected);
+  --table-head-column-bg-hover: var(--color-surface-hover);
-  --menu-item-bg-hover: var(--color-action-secondary-cta-hover);
+  --menu-item-bg-hover: var(--color-surface-hover);
+  --menu-item-indicator-selected: var(--color-indicator-selected);
-  --nav-item-bg-hover: var(--color-surface-hover);
-  --nav-item-bg-active: var(--color-surface-tertiary);
+  --nav-item-bg-hover: var(--color-surface-secondary-hover);
+  --nav-item-bg-pressed: var(--color-surface-secondary-pressed);
+  --nav-item-bg-current: var(--color-surface-secondary-selected);
+  --nav-item-bg-current-hover: var(--color-surface-secondary-selected-hover);
+  --nav-item-indicator-current: var(--color-indicator-selected);
+  --nav-item-bg-active: var(--nav-item-bg-current); /* @deprecated */
-  --input-bg-hover: var(--color-surface-hover);
+  --input-bg-hover: var(--input-bg);
-  --input-border-active: var(--color-border-focus);
+  --input-border-focus: var(--color-border-focus);
+  --input-border-active: var(--input-border-focus); /* @deprecated */
-  /* ── Checkbox ── ... slate-810 via --color-border-dark for the idle border ... */
+  /* ── Checkbox, radio, switch ── rest edge, disabled edge and switch track = --color-border-dark; hover steps to --color-border-hover-strong because --color-border-hover is slate-810 in light, the rest edge itself. */
-  --checkbox-bg-hover: var(--color-surface-hover-subtle);
-  --checkbox-border-hover: var(--color-border-hover-muted);
+  --checkbox-bg-hover: var(--color-surface-hover);
+  --checkbox-border-hover: var(--color-border-hover-strong);
+  --checkbox-fill-checked: var(--color-action-primary-cta);
+  --checkbox-fill-checked-hover: var(--color-action-primary-cta-hover);
+  --checkbox-fill-checked-pressed: var(--color-action-primary-cta-pressed);
+  --radio-border / --radio-bg-hover / --radio-border-hover / --radio-fill-checked(-hover/-pressed) / --radio-bg-disabled / --radio-fill-disabled: var() of the --checkbox-* twin
+  --switch-track-bg: var(--color-border-dark);
+  --switch-track-bg-hover: var(--color-border-hover-strong);
+  --switch-track-bg-checked: var(--color-action-primary-cta);
+  --switch-track-bg-checked-hover: var(--color-action-primary-cta-hover);
+  --switch-track-bg-disabled: var(--color-surface-disabled);
-  --tabs-nav-item-bg-active: var(--color-surface-selected);
+  --tabs-nav-item-bg-selected: var(--color-surface-selected);
+  --tabs-nav-item-bg-active: var(--tabs-nav-item-bg-selected); /* @deprecated */
-  --tabs-nav-item-surface-hover: var(--color-emphasis-link);
-  --tabs-nav-item-surface-selected: var(--color-emphasis-link-hover);
+  --tabs-nav-item-surface-hover: var(--color-text-primary);
+  --tabs-nav-item-surface-selected: var(--color-text-selected);
+  --tabs-nav-item-indicator-selected: var(--color-indicator-selected);
+  --tabs-nav-item-border-selected: var(--color-border-selected);
-  --tabs-browsing-item-bg-active: var(--color-surface-primary);
+  --tabs-browsing-item-bg-selected: var(--color-surface-primary);
+  --tabs-browsing-item-bg-active: var(--tabs-browsing-item-bg-selected); /* @deprecated */
+  --tabs-browsing-item-surface-selected: var(--color-text-selected);
+  --tabs-browsing-item-indicator-selected: var(--color-indicator-selected);
-  --tabs-browsing-item-bg-inactive-hover: var(--color-surface-emphasis);
+  --tabs-browsing-item-bg-inactive-hover: var(--color-surface-secondary-hover);
-  --kpi-bg-hover: var(--color-surface-hover);
-  --kpi-bg-active: var(--color-surface-selected);
+  --kpi-bg-hover: var(--kpi-bg);
+  --kpi-bg-selected: var(--color-surface-selected);
+  --kpi-bg-selected-hover: var(--color-surface-selected-hover);
+  --kpi-bg-active: var(--kpi-bg-selected); /* @deprecated */
-  --kpi-border-active: var(--color-border-focus);
+  --kpi-border-selected: var(--color-border-selected);
+  --kpi-border-active: var(--kpi-border-selected); /* @deprecated */
+  --card-border-primary / --card-border-hover / --card-border-selected / --card-bg-selected / --card-bg-selected-hover / --card-bg-disabled: var() of border-primary / border-hover / border-selected / surface-selected / surface-selected-hover / surface-secondary
+  --focus-ring-width: 2px;
+  --focus-ring-offset: 2px;
@@ bridge @theme inline (lines 581-608) @@
-  --color-accent: var(--btn-ghost-bg-hover);
-  --color-accent-foreground: var(--btn-ghost-surface);
+  --color-muted-foreground: var(--color-text-tertiary);
+  --color-accent: var(--menu-item-bg-hover);
+  --color-accent-foreground: var(--menu-item-surface);
-  --color-ring: var(--input-border-active);
+  --color-ring: var(--color-border-focus);
+  --color-sidebar-selected: var(--nav-item-bg-current);
+  --color-sidebar-selected-hover: var(--nav-item-bg-current-hover);
+  --color-sidebar-pressed: var(--nav-item-bg-pressed);
+  --color-sidebar-indicator: var(--nav-item-indicator-current);
-  --color-sidebar-ring: var(--input-border-active);
+  --color-sidebar-ring: var(--color-border-focus);
+  --color-table-row-selected: var(--table-row-bg-selected);
+  --color-table-row-selected-hover: var(--table-row-bg-selected-hover);
@@ bridge :root (lines 623-644) @@
+  (the same lines without the --color- prefix: --muted-foreground, --accent, --accent-foreground, --ring, --sidebar-selected, --sidebar-selected-hover, --sidebar-pressed, --sidebar-indicator, --sidebar-ring)
@@ .dark Surface (lines 683-688) @@
-  --color-surface-hover: var(--color-brand-dark-300);
-  --color-surface-hover-subtle: var(--color-brand-dark-200);
-  --color-surface-hover-strong: var(--color-brand-dark-400);
-  --color-surface-selected: var(--color-brand-dark-300);
+  --color-surface-hover: color-mix(in srgb, var(--color-slate-100) 10%, var(--color-slate-1000));
+  --color-surface-hover-strong: color-mix(in srgb, var(--color-slate-100) 16%, var(--color-slate-1000));
+  --color-surface-pressed: color-mix(in srgb, var(--color-slate-100) 20%, var(--color-slate-1000));
+  --color-surface-hover-subtle: var(--color-surface-hover); /* @deprecated */
+  --color-surface-selected: color-mix(in srgb, var(--color-brand-900) 46%, var(--color-slate-1000));
+  --color-surface-selected-hover: color-mix(in srgb, var(--color-brand-900) 56%, var(--color-slate-1000));
+  --color-surface-secondary-hover: color-mix(in srgb, var(--color-slate-100) 8%, var(--color-slate-950));
+  --color-surface-secondary-selected: color-mix(in srgb, var(--color-brand-900) 40%, var(--color-slate-950));
+  --color-surface-secondary-selected-hover: color-mix(in srgb, var(--color-brand-900) 50%, var(--color-slate-950));
+  --color-surface-secondary-pressed: color-mix(in srgb, var(--color-slate-100) 23%, var(--color-slate-950));
-  --color-surface-disabled: var(--color-slate-900);
+  --color-surface-disabled: color-mix(in srgb, var(--color-slate-100) 14%, var(--color-slate-1000));
@@ .dark Text @@
+  --color-text-selected: var(--color-brand-600);
@@ .dark Border (lines 712-721) @@
-  --color-border-hover: var(--color-brand-800);
+  --color-border-hover: color-mix(in srgb, var(--color-slate-100) 35%, var(--color-slate-1000));
+  --color-border-hover-strong: color-mix(in srgb, var(--color-slate-100) 50%, var(--color-slate-1000));
-  --color-border-hover-muted: var(--color-brand-800);
+  --color-border-selected: var(--color-brand-900);
+  --color-indicator-selected: var(--color-brand-700);
+  --color-border-hover-muted: var(--color-border-hover); /* @deprecated */
@@ .dark Action (lines 723-739) @@
-  --color-action-primary-cta-disabled: var(--color-brand-dark-300);
-  --color-action-secondary-cta: var(--color-slate-950);
-  --color-action-secondary-cta-hover: var(--color-slate-900);
+  --color-action-primary-cta-pressed: color-mix(in srgb, var(--color-brand-1000) 65%, var(--color-slate-1000));
+  --color-action-primary-cta-disabled: color-mix(in srgb, var(--color-brand-1000) 40%, var(--color-slate-850));
+  --color-action-destructive-cta-pressed: color-mix(in srgb, var(--color-red-700) 80%, var(--color-slate-1000));
@@ .dark Accent @@
+  --color-accent-info-light: var(--color-brand-dark-200);
@@ base (line 835) @@
-    @apply border-border outline-ring/50;
+    @apply border-border outline-ring;
@@ base: new utilities (after @layer base) @@
+/* No outline-hidden beside these: Tailwind 4.1.14 emits it after them at equal specificity. */
+@utility focus-ring {
+  outline: var(--focus-ring-width) solid transparent;
+  outline-offset: var(--focus-ring-offset);
+  &:focus-visible {
+    outline-style: solid;
+    outline-color: var(--color-ring);
+  }
+}
+@utility focus-ring-inset {
+  outline: var(--focus-ring-width) solid transparent;
+  outline-offset: calc(-1 * var(--focus-ring-offset));
+  &:focus-visible {
+    outline-style: solid;
+    outline-color: var(--color-ring);
+    --tw-inset-shadow: inset 0 0 0 calc(var(--focus-ring-width) + 1px) var(--color-bg-primary);
+    box-shadow: var(--tw-inset-shadow), var(--tw-inset-ring-shadow), var(--tw-ring-offset-shadow), var(--tw-ring-shadow), var(--tw-shadow);
+  }
+}
@@ animation: .btn-swish and glowPulse (lines 963-964, 1037-1043) @@
-    --swish-from: #7AC4FF;
-    --swish-to: #A07EFF;
+    --swish-from: var(--color-blue-400);
+    --swish-to: var(--color-brand-800);
-    box-shadow: 0 0 20px 0px rgba(142, 91, 255, 0.55);
+    box-shadow: 0 0 20px 0px color-mix(in srgb, var(--color-brand-900) 55%, transparent);
```

### 5.2 Component migrations

Files are relative to `frontend/packages/`. "New" is the target class recipe or structural change; the finding ids say which audit items each row closes.

| Priority | Files | Findings | New | Note |
|---|---|---|---|---|
| P0 | ui/theme.css | F8-01, F8-02, F8-16, F8-04, F8-05, F8-12, F8-17, F8-20 (+12 more) | Apply themeCssDiff in full (neutral surface ladder, secondary ladder, brand-400 / 46% selected + selected-hover, border-selected brand-1000 / brand-900, indicator-selected brand-1000 / brand-700, border-hover-strong, text-selected, pressed tokens, the opaque ring-selected mixes, accent-info-light, cta-disabled dark mix, surface-disabled dark rung, the three rewritten comments, -active aliases, bridge repoints, new si | Fixes selected == hover in both themes (F8-01); wires the dead KPI / nav / tabs / filter tokens (F8-02, F8-16, F3-22, F2-24); bridge repoint makes hover:bg-accent / hover:bg-sidebar-accent neutral unedited (F8-05); dissolves all three F8-12 dark collapses: #51 |
| P0 | new ui/src/novee/styles/focus-ring.ts; button.tsx:27, toggle.tsx:10, checkbox.tsx:58, radio-group.tsx:28, switch.tsx:16, slider.tsx:56, tabs.tsx:45, NovTabs.tsx:302-310, SegmentedControl.tsx:122, OptionCard.tsx:26-28, sidebar.tsx:483/698, DetailCell.tsx:58, Ta | F7-12, F4-13, F1-15, F3-13, F5-09, F6-01, F3-30, F1-33 (+9 more) | FOCUS_RING = "focus-ring"; FOCUS_RING_INSET = "focus-ring-inset"; FOCUS_FIELD = "focus-visible:border-[var(--input-border-focus)] focus-visible:ring-1 focus-visible:ring-inset focus-visible:ring-[var(--input-border-focus)]"; FOCUS_FIELD_WITHIN = its focus-within: twin. No outline-hidden in the constants: tailwindcss 4.1.14 emits .ring-1 > .focus-ring-inset > .focus-ring > .outline-hidden whatever the candidate order, | One recipe per placement replaces nine (F8-10, F7-12, F4-13, F1-15, F3-13, F5-09, F6-01, F2-13); stacked tab ring (F3-30) and two-hue destructive ring (F1-33) go; mouse-firing rings become focus-visible (F2-20, F6-22, F6-25); UA-outline controls get the DS rin |
| P0 | ui/src/shadcn/components/ui/button.tsx:10-49, badge.tsx:10-20, webapp IntegrationsPageClient.tsx:27 | F1-03, F1-04, F1-05, F1-08, F1-09, F1-17, F1-19, F1-23 (+3 more) | ACTIVE = "aria-pressed:bg-[var(--btn-filter-bg-selected)] aria-pressed:hover:bg-[var(--btn-filter-bg-selected-hover)] aria-pressed:text-[var(--btn-filter-surface-selected)] aria-pressed:border aria-pressed:border-[var(--btn-filter-border-selected)] aria-pressed:ring-1 aria-pressed:ring-inset aria-pressed:ring-[var(--btn-filter-border-selected)]" (outline, secondary, ghost); ACTIVE_SOLID = "aria-pressed:ring-2 aria-pr | Pressed is a lightness step above hover with an edge that outranks the hover edge (F1-03, F5-04); one recipe for tinted variants (F1-04, F1-09); solids keep their fill under a 2px inset ring that clears 3:1 (60% over transparent composited to 2.85 / 2.41:1 and |
| P0 | ui/src/shadcn/components/ui/toggle.tsx:10-17, SegmentedControl.tsx:122-145 | F1-01, F1-07, F1-20, F1-25 | Toggle: `data-[state=off]:hover:bg-surface-hover hover:text-text-primary active:bg-surface-pressed data-[state=on]:bg-[var(--btn-filter-bg-selected)] data-[state=on]:text-[var(--btn-filter-surface-selected)] data-[state=on]:border data-[state=on]:border-[var(--btn-filter-border-selected)] data-[state=on]:ring-1 data-[state=on]:ring-inset data-[state=on]:ring-[var(--btn-filter-border-selected)] disabled:text-text-disa | Visible ON state (F1-01), one hover (F1-07), segment hover + pointer (F1-25), hover token out of the selected fill (F1-20). |
| P0 | ui/src/novee/styles/facet-pill.ts:17-44, QuickFilter.tsx:92-102, FacetToggleChip.tsx:56, TableFacetFilter.tsx:198, DataGridFilterTrigger.tsx:9-41, DataGridFilterChips.tsx:363 | F1-12, F1-13, F1-14, F1-26, F1-31, F2-25 | facet-pill active: `border-border-selected bg-surface-selected text-text-selected ring-1 ring-inset ring-border-selected hover:bg-surface-selected-hover`; inactive: `hover:bg-surface-hover hover:border-border-hover active:bg-surface-pressed`; open `has-data-[state=open]:bg-surface-hover`; disabled text-text-disabled. QuickFilter: <button aria-pressed={selected}> + FOCUS_RING. TableFacetFilter rows `hover:bg-accent ${ | 2px brand edge + brand label + selected-hover (F1-12, F1-14); one neutral hover (F1-13); focus differs from hover (F1-26); active = aria-pressed (F2-25); summary chip distinct (F1-31). |
| P0 | ui/src/novee/components/KPI/KPI.tsx:57-66 | F1-02 | <button type="button" aria-pressed={selected}>: `border border-[var(--kpi-border)] hover:border-[var(--kpi-border-hover)] hover:shadow-md active:bg-surface-pressed aria-pressed:bg-[var(--kpi-bg-selected)] aria-pressed:border-[var(--kpi-border-selected)] aria-pressed:ring-1 aria-pressed:ring-inset aria-pressed:ring-[var(--kpi-border-selected)] aria-pressed:hover:bg-[var(--kpi-bg-selected-hover)] ${FOCUS_RING}` | Keyboard-reachable stat cards on the --kpi-* tokens. |
| P0 | dropdown-menu.tsx:84/102, select.tsx:165-172, command.tsx:158, MultiSelectItem.tsx:83-103, TimePicker.tsx:137-140, GroupBySelect.tsx:111-116, DateFilter.tsx:206-212, DataGrid option lists, PopoverActionRow.tsx:78 | F2-01, F2-02, F2-03, F2-04, F2-05, F2-10, F2-11, F2-12 (+3 more) | Radix / cmdk items keep focus:bg-accent / data-[selected=true]:bg-accent (neutral via the bridge); data-[disabled]:opacity-50 -> text-text-disabled; the check glyph everywhere is text-[var(--menu-item-indicator-selected)] + font-medium, no selected fill; MultiSelectItem checkbox role="checkbox" aria-checked; TimePicker / GroupBySelect / DateFilter on SelectedCheck. | One highlight hue and one selected idiom (F2-01, F2-02, F2-11, F2-12, F2-15); selected != hover (F2-03, F2-04, F2-05); real ARIA (F2-10); primitives out (F2-16); disabled = text-disabled (F2-18). |
| P0 | trigger-hover.ts:7, SelectTriggerAffordance.tsx:51, SimpleMultiSelect.tsx:764-785, MultiSelect.tsx:870-898, DateRangeFilter.tsx:58-84, select.tsx:26, EditableCellTrigger.tsx:7-18, AssetSelectDropdown.tsx:87-91 | F2-06, F2-07, F2-08, F2-09, F2-14, F2-19, F6-29, F6-23 | TRIGGER_HOVER_FILL = "hover:border-[var(--input-border-hover)]". Value-bearing triggers render <Button variant="outline" active={hasValue}>. DateRangeFilter: <button> on selectTriggerVariants. Open on every picker: `data-[state=open]:border-[var(--input-border-focus)] data-[state=open]:ring-1 data-[state=open]:ring-inset data-[state=open]:ring-[var(--input-border-focus)]` + TriggerChevron. Clear x: FOCUS_RING. select | One 'has a value' mechanism (F2-06, F2-07); DS ring on clear and trigger (F2-08); keyboard-operable (F2-09); one open recipe (F2-14, F6-23); disabled fixed (F2-19); dark works (F6-29). |
| P0 | webapp ChipPickerItem.tsx:25-35, issue-action-menu-items.tsx:143-147, SidebarAccountMenu.tsx:48, HelpMenu.tsx:29, PageTopBarProjects.tsx:116-149, TicketingUserPicker, SeverityThresholdSelect, AssetSelectDropdown.tsx:182-188, RepositoryMultiSelect, SeveritySele | F2-21, F2-22, F7-14, F6-18, F6-19, F2-23, F7-04, F7-05 (+3 more) | Delete MENU_ITEM_CLASS; render DropdownMenuItem / DropdownMenuRadioItem (PageTopBarProjects aria-current="true" + SelectedCheck; TicketDestinationPicker menuitemradio + aria-checked) or CommandItem: highlight = bg-accent, selected = check + font-medium, no fill. DisabledHoverMenuItem keeps the highlight, uses text-text-disabled, is aria-disabled not Radix-disabled, stays focusable, shows the reason on focus. Plain ro | Highlight never suppressed, disabled-with-reason stays focusable (F2-21, F7-14); pickers on DS items (F2-22, F6-18, F7-06); selected != hover (F6-19, F2-23, F7-04, F7-05, F5-03); aria-current (F2-29). |
| P0 | ui/src/shadcn/components/ui/sidebar.tsx:483-492 and 698-699, webapp AppSidebarItem.tsx:37-42, AppSidebarCollapsibleItem.tsx:26, SidebarAccountMenu.tsx:161, CollapsibleGroupHeader.tsx:67-75, MenuCrumb | F3-01, F3-02, F3-03, F3-04, F3-05, F3-06, F3-28, F8-03 (+2 more) | Base: `relative ... hover:bg-sidebar-accent active:bg-sidebar-pressed data-[state=open]:bg-sidebar-accent data-[active=true]:bg-sidebar-selected aria-[current=page]:bg-sidebar-selected data-[active=true]:font-medium data-[active=true]:hover:bg-sidebar-selected-hover data-[active=true]:before:absolute data-[active=true]:before:inset-y-1 data-[active=true]:before:left-0 data-[active=true]:before:w-0.5 data-[active=true | Hover, pressed and current + brand bar are three fills (F3-01, F3-02, F3-03, F8-03); visible account hover (F3-05); one nav hover family (F3-06); aria-current / aria-expanded (F3-04, F3-18); open = hover held (F3-19); dead classes removed (F3-28). |
| P0 | webapp/src/lib/settings/workflows/editor/ActionGallery.tsx:167-177, 216 | F3-07, F5-02 | `relative ... hover:bg-surface-secondary-hover active:bg-surface-secondary-pressed aria-pressed:bg-surface-secondary-selected aria-pressed:font-medium aria-pressed:hover:bg-surface-secondary-selected-hover aria-pressed:before:... before:w-0.5 before:bg-indicator-selected ${FOCUS_RING_INSET}`; gallery cards at :216 take Card interactive. | The rail sits on bg-secondary, so it takes the sidebar recipe: brand fill + bar + weight vs neutral hover. |
| P0 | ui NovTabs.tsx:296-313 (base string `text-sm font-medium` at :296), tabs.tsx:45, webapp BrowsingTabBar.tsx:56-135, VeeVeeTabStrip.tsx:118-119, ui NetworkTrafficPanel/RequestResponseInspector.tsx:205-225 (ViewTabs, inline), EntityTabs, IntegrationSetupDialog ta | F3-08, F3-09, F3-10, F3-11, F3-12, F3-24, F3-25, F3-26 (+2 more) | NovTabs base `text-sm font-normal disabled:text-text-disabled` (weight becomes a step). pill: `border border-transparent data-[state=inactive]:hover:bg-[var(--tabs-nav-item-bg-hover)] data-[state=active]:bg-[var(--tabs-nav-item-bg-selected)] data-[state=active]:text-[var(--tabs-nav-item-surface-selected)] data-[state=active]:border-[var(--tabs-nav-item-border-selected)] data-[state=active]:ring-1 data-[state=active]: | Selected tabs leave the hover tokens (F3-08, F4-28); six grammars become NovTabs variants (F3-09, F3-21); ink hover, brand selected with edge / bar + weight (F3-10, F3-11, F3-25); visible hovers (F3-12, F3-24); every variant carries a structural cue (CR-03, F8 |
| P0 | ui DataGridRow.tsx:142-170, DataGridDataRow.tsx:81-99, table.tsx:56/80/93, CollapsibleGroupHeader.tsx:67-91, NetworkTrafficRow.tsx:97-113, FileExplorer.tsx:475/535-538/636-651, DetailCell.tsx:58, SortableHeader.tsx:26, DataGridHeaderCell.tsx:141/202, Notificat | F4-02, F4-03, F4-04, F4-05, F4-06, F4-07, F4-08, F4-09 (+19 more) | One DataGridRowShell for both rows: `group/row relative data-[clickable]:hover:bg-table-row-hover data-[selected]:bg-table-row-selected data-[selected]:hover:bg-table-row-selected-hover` + before: 2px bar in --table-row-indicator-selected + `has-[[data-state=open]]:bg-table-row-hover data-[clickable]:active:bg-[var(--table-row-bg-pressed)] ${FOCUS_RING_INSET}`; clickable rows get tabIndex={0}, aria-selected, Enter /  | Six row recipes on one shell (F4-03, F4-04, F4-05, F4-25, F4-26); rows keyboard-operable with an inset ring (F4-11, F4-12, F4-14, F4-15, F4-21, F4-22, F7-01); one neutral hover per ground, gated header hover (F4-06 to F4-10, F4-16, F4-17, F4-23, F4-24); tree k |
| P0 | ui OptionCard.tsx:8-30 (+ OptionCardGroup), card.tsx:11, CardLink, FlowNodeCard.tsx:23-24, FileUploadDropZone.tsx:616-661, RuleCard.tsx:37, DashboardWidget.tsx:32; webapp ReportKindCard.tsx:64-70, AssessmentTypeCard.tsx:55-83, AssetEnvironmentSection x2, JiraS | F5-01, F5-05, F5-06, F5-07, F5-08, F5-12, F5-14, F5-15 (+21 more) | OptionCard: idle `border-[var(--card-border-primary)]`; INTERACTIVE `hover:-translate-y-0.5 hover:border-[var(--card-border-hover)] hover:shadow-md active:bg-surface-pressed ${FOCUS_RING}`; selected `border-[var(--card-border-selected)] bg-[var(--card-bg-selected)] ring-1 ring-inset ring-[var(--card-border-selected)] hover:bg-[var(--card-bg-selected-hover)]` + an indicator slot (check or radio dot in text-[var(--colo | One selectable-card recipe replaces six copies and five mechanisms (F5-07, F5-14, F5-16, F7-08, F7-17, F1-18); checked card shows focus (F5-01); selected != hover (F3-27, F7-02, F7-03, F5-06, F7-25); one hover border (F5-08, F5-28, F5-05); primitives and alpha |
| P0 | webapp ApplicationWizardSummaryView.tsx:281-294, AssessmentWizardSummaryView.tsx:429-441 | F5-11, F7-15, F7-26 | One DS DayOfWeekToggleGroup on ToggleGroup (each day a Toggle with aria-pressed): rest `rounded-full size-8 border border-border-primary text-text-secondary`, off hover surface-hover, pressed surface-pressed, on = ACTIVE, on + hover surface-selected-hover, ${FOCUS_RING}; active prop renamed pressed. | Keyboard-operable with name, role and state (F5-11, F7-15); 'active' means aria-pressed only (F7-26). |
| P0 | ui input.tsx:6-19, textarea.tsx:11-13, select.tsx:26/95, checkbox.tsx:53-75, radio-group.tsx:28, switch.tsx:16, slider.tsx:56, calendar.tsx:69-209, SegmentedDateInput.tsx:349-396, TagInput.tsx:73-92, RichTextEditor.tsx:58, OptimizablePromptField.tsx:122-181, E | F6-03, F6-04, F6-05, F6-06, F6-08, F6-09, F6-10, F6-11 (+18 more) | Input outline: `border border-input hover:border-[var(--input-border-hover)] ${FOCUS_FIELD} disabled:bg-[var(--input-bg-disabled)] disabled:text-text-disabled disabled:opacity-100 read-only:border-dashed read-only:bg-transparent` (ring-0 rules deleted), aria-invalid = border-destructive + 1px inset ring-destructive; ghost `focus-visible:shadow-[inset_0_-1px_0_var(--input-border-focus)]`. Textarea / Select / Radio / p | Border-only hover and one focus stroke (F6-05, F6-06, F6-14); read-only keeps its ring (F6-04, F6-11, F6-03); disabled is tokens (F6-10); ghost and title inputs get one cue (F6-12, F6-13, F6-36); TagInput and RichTextEditor own their boxes (F6-15, F6-33); chec |
| P1 | ToolbarIconButton.tsx:13-78, CopyToClipboardButton.tsx:67-83, NotificationBellButton.tsx:11-38, RowActionButton.tsx:36-37, DataGridColumnManager.tsx:210, RichTextEditor.tsx:203-205, EditableTitle.tsx:187, NotificationItem.tsx:188; webapp icon-button copies | F1-06, F1-27, F1-30, F6-07, F1-10, F2-27, F4-18, F6-24 (+1 more) | ToolbarIconButton, CopyToClipboardButton, NotificationBellButton, DataGridFilterTrigger compose <IconButton variant="ghost" \| "outline"> (hover --btn-ghost-bg-hover, pressed --btn-ghost-bg-pressed, open = hover held, aria-pressed = ACTIVE). RowActionButton (nested in a hovered row; scan-states rule 10 allowlists surface-hover-strong as its open fill): `hover:bg-surface-hover-strong data-[state=open]:bg-surface-hover- | One hover token for icon buttons (F1-06, F1-27, F7-07, F6-24); pressed differs from hover (F6-07, F1-30); open / active differ from hover (F1-10, F2-27, F4-18). |
| P1 | ui/src/novee/components/Chip/Chip.tsx:21-60 | F1-24 | interactive defaults to false; when true render <button> with the chip hover tokens + FOCUS_RING; the border is always rendered (F8-17). | Hover chips become focusable buttons. |
| P1 | ui pagination.tsx:55-70, PaginationFooter.tsx:69-86, TablePagination.tsx:54-73, Breadcrumb.tsx:111, Stepper, WizardStep, StatusStepper; webapp NewAssetFlowShell.tsx:128-181, IntegrationStepper.tsx:123-126, StepRailButton.tsx:24-34, MarkdownSectionsTab.tsx:145- | F3-14, F3-15, F3-16, F3-17, F3-20, F7-19, F3-29 | PaginationLink: `aria-[current=page]:bg-[var(--btn-filter-bg-selected)] aria-[current=page]:text-[var(--btn-filter-surface-selected)] aria-[current=page]:font-semibold aria-[current=page]:ring-1 aria-[current=page]:ring-inset aria-[current=page]:ring-[var(--btn-filter-border-selected)] aria-[current=page]:hover:bg-[var(--btn-filter-bg-selected-hover)] aria-disabled:text-text-disabled ${FOCUS_RING_INSET}`. One DS Step | Current = fill + 2px edge + weight, distinct from hover and focus (F3-14, F3-29, F7-19); one stepper vocabulary (F3-16, F3-17); crumb never dimmer (F3-15); pagination disabled is one recipe (F3-20). |
| P1 | webapp IssueFixTab.tsx:52, ChatMessages.tsx:72, AssetDetailsSection.tsx:217-256, StatusChangeDropdown.tsx:278, SavedGuidelines.tsx:127, settings CTAs, InviteUsersDialog.tsx:592, NewAssetFlowShell.tsx:128, IntegrationTile, SlackTile, ScopeRules, IssueMitigation | F7-09, F7-10, F7-11, F7-16, F7-18, F7-20, F7-21, F7-22 (+2 more) | Clickable bordered cards -> <Card variant="interactive">; detail-cell triggers -> Button ghost / IconButton; links `text-emphasis-link hover:text-emphasis-link-hover hover:underline`; pasted buttonVariants and the 22 redundant hover:bg-action-primary-cta-hover classes deleted; aria-disabled:opacity-50 only on IntegrationTile, SlackTile, DemoIntegrationTile, ScopeRules; thick-border radios -> RadioGroupItem; switches  | Cards, triggers, links and popovers converge on DS recipes (F7-09, F7-10, F7-11, F7-20, F7-22, F7-29); hand-rolled controls gain hover and focus (F7-16); ARIA matches (F7-18); disabled is tokens except whole tiles (F7-21); no state tokens as decoration (F7-23) |
| P1 | acul/src/index.css:3 (imports @novee/ui/theme.css), acul/src/components/PasswordInput.tsx:24, acul/src/components/MethodList.tsx:26, acul/src/screens/organization-picker/index.tsx:115 | F8-05, F8-10 | Nothing in Phase 1: the three sites re-render through the --color-accent bridge (hover:bg-accent goes neutral). Phase 2: `outline-none focus-visible:ring-2 focus-visible:ring-border-focus` -> ${FOCUS_RING} on the eye button, ${FOCUS_RING_INSET} on the list rows; organization-picker drops hover:bg-primary/5 and hover:border-primary for `hover:bg-surface-hover hover:border-[var(--card-border-hover)]`; disabled:opacity- | acul was outside the audit walk (no finding of its own) but imports theme.css, so the token flip and the bridge repoint reach it; listed so the Phase 1 re-render check and the Phase 2 focus sweep cover it. |
| P2 | ui/theme.css @layer components (.btn-swish 963-964, glowPulse 1037-1043) | F8-23 | --swish-from: var(--color-blue-400); --swish-to: var(--color-brand-800); color-mix(in srgb, var(--color-brand-900) 55%, transparent) | Same tokens btn-halo uses. |
| P2 | ui/scripts/audit-tokens.mjs:250-254 and 391-409, new ui/scripts/scan-states.mjs, eslint configs, ui-storybook main.ts, Foundations/States.stories.tsx, ui/AGENTS.md | F8-13, F8-11, F8-14, F8-10, F8-06, F1-28, F3-23 | See guardrails: STATE_ALIAS deleted, DEPRECATED set, failing state-role, ring-role and collapse checks with COLLAPSE_ALLOW; scan-states rules 1-11; ESLint rules; pseudo-states addon + Foundations/States; AGENTS.md vocabulary; rename active / isActive props that mean current or selected. | The selected = active formalisation hid F8-01 (F8-06, F1-28, F3-23). |

Won't fix in this model (tracked as follow-ups):

- F1-29, F8-09: Renaming the component-layer --*-surface (text) tokens to --*-text is a mechanical pass that must land together with an update to audit-tokens' ROLE_RE and FG_ROLES (which only recognise surface|border|fill), or the composed-pair text check silently stops covering those tokens. Scheduled as a follow-up PR with deprecated aliases; nothing in this model depends on the name.
- F2-30: Popover panel chrome (radius, border, shadow) is the open panel's presentation, not an interaction state of the trigger; tracked as a PopoverContent variant follow-up.

### 5.3 Guardrails

So the drift cannot return, the model ships with executable checks rather than prose rules.

**audit-tokens: state-role check replaces STATE_ALIAS** (`frontend/packages/ui/scripts/audit-tokens.mjs (~line 250 and the collapse report ~391)`)

Delete STATE_ALIAS / normState. Add DEPRECATED (tokens carrying a /* @deprecated */ marker in theme.css), excluded from every check. Extend ROLE_RE to (bg|surface|border|fill|indicator|ring) and FG_ROLES with indicator so --nav-item-indicator-current is checked against --nav-item-bg-current. Per family, resolve --<family>-bg-<state> for state in {hover, hover-strong, pressed, selected, selected-hover, current, current-hover, disabled} and FAIL --check when, in either theme, hover == selected, hover == pressed, selected == selected-hover, hover == disabled, selected == disabled, or --<family>-border-selected == --<family>-border-hover or == border-focus (passes as specified: border-selected is #8149eb light / #8e55fd dark against a ring of #8e55fd / #ae92ff). Ring-role check: every --<family>-ring-<state> must resolve to a hex (a mix containing `transparent` is unresolvable and FAILS with 'ring tokens are opaque two-colour mixes over the family bg') and must clear 3:1 against --<family>-bg (btn-primary 3.89:1, btn-destructive 3.39:1). Promote the identity-collapse report to a failing check for the semantic state roles (surface-hover, -hover-strong, -pressed, -selected, -selected-hover, -disabled, surface-secondary-*, border-hover, border-hover-strong, border-selected, indicator-selected, action-primary-cta-disabled, text-selected): two of them on one dark hex, or one sharing a dark hex with a non-state semantic token of a different light value, is an error unless the pair is in COLLAPSE_ALLOW = [[--color-indicator-selected, --color-emphasis-link-hover, 'a 2px bar and hovered link text are never adjacent; brand-700 is the only dark step that clears 3:1 on every selected rung without touching the ring']]; the allowlist is printed in the report so it cannot grow silently. Border-vs-border pairings outside those roles (border-hover = border-dark in light) stay informational. Assert --focus-ring-width and --focus-ring-offset are 2px. All new mixes use the two-colour color-mix form the resolver already parses.

**scan-states.mjs (new, in `pnpm audit:theme`)** (`frontend/packages/ui/scripts/scan-states.mjs over ui/src, webapp/src and acul/src, same walk / ALLOW / push helpers as scan-colors.mjs, cn() arguments joined per element`)

ERRORS: (1) hover:bg-(surface-secondary|surface-tertiary|surface-emphasis|muted)\b (a ground as a hover); (2) (ring|border|outline|bg)-brand-\d+ inside a state prefix (hover|focus|focus-visible|active|aria-pressed|aria-\[current=...\]|data-\[state=...\]|data-\[selected...\]):; (3) focus-visible:ring-0|focus:ring-0|outline-none|outline-hidden with no focus-ring|focus-ring-inset|FOCUS_RING|FOCUS_RING_INSET|FOCUS_FIELD|focus-visible:(ring|outline|border|shadow) sibling in the same className expression, except an element whose file applies FOCUS_FIELD_WITHIN to an ancestor box (the RichTextEditor ProseMirror root); an element that carries BOTH outline-(none|hidden) and focus-ring(-inset)? is also an error, because .outline-hidden is emitted after the utility and cancels it; (4) bare focus:ring-|focus:outline|focus:bg-|focus:border-|has-focus: outside the Radix item files (dropdown-menu, select, command, context-menu, menubar); (5) ring-ring/50|ring-\[3px\]|focus-visible:ring-2 focus-visible:ring-(ring|border-focus) (old recipes; enabled after Phase 2); (6) border-border-hover(?!-strong)\b or border-border-hover-muted on a line that also carries aria-pressed|aria-\[current|data-\[state=(on|active|checked)\]|data-\[selected|aria-selected|aria-checked|isSelected|isActive|selected \? (a hover edge as a selected edge; enabled after Phase 3); (7) bg-surface-hover(-subtle|-strong)?\b not preceded by hover:|active:|data-\[state=open\]:|data-\[drag-active\]:|has- (a hover token as a rest or selected fill; the drop zone styles drag-over from its data-drag-active attribute, not from a JS conditional). WARNINGS: (8) bg-surface-selected|aria-pressed:bg-|data-\[state=(on|active|checked)\]:bg-|aria-\[current=...\]:bg-|data-\[selected...\]:bg- with no cue sibling (font-medium|font-semibold|border-border-selected|-border-selected\)|indicator-selected|SelectedCheck|before:) within the expression or the next 3 lines (the F8-21 pattern; error after Phase 3); (9) opacity-\d+ under disabled:|aria-disabled:|data-\[disabled outside the TILE allow list (IntegrationTile, SlackTile, DemoIntegrationTile, ScopeRules); (10) data-\[state=open\]:bg- whose value is not accent|surface-hover|surface-hover-strong|sidebar-accent|surface-secondary-hover|[var(--btn-ghost-bg-hover)]|[var(--tabs-nav-item-bg-hover)] or a FOCUS_FIELD class (surface-hover-strong is the open fill of a control nested in a hovered row: RowActionButton, in-row filter trigger); (11) aria-current: without brackets (compiles to [aria-current="true"]). --check exits 1 on errors; --json for CI.

**ESLint rules** (`frontend/packages/ui/eslint.config.js and frontend/packages/webapp/eslint.config.mjs (+ eslint-rules/*.js)`)

(a) custom rule novee/clickable-needs-role: a JSXOpeningElement div / span / li with onClick must also carry role and tabIndex, or asChild (F4-11, F4-12, F5-11, F7-15, F2-09, F6-16). (b) novee/selected-needs-aria: a cn() argument of the form `<expr> && "...bg-surface-selected..."` or `? "...border-border-selected..."` requires aria-selected, aria-checked, aria-pressed or aria-current on the same element (F7-18, F5-27, F3-04, F2-29). (c) no-restricted-syntax on literals matching /\bfocus-visible:ring-0\b/, /\bring-ring\/50\b/, /\bhover:bg-(surface-secondary|muted)\b/, /\bring-brand-\d/, /\baria-current:/. (d) no-restricted-imports in webapp for the deprecated shadcn tabs. Rules ship at warn in Phase 0 and flip to error per rollout.

**Storybook: pseudo-states addon, Foundations/States matrix, per-family InteractionStates, vitest a11y assertion** (`frontend/packages/ui-storybook/.storybook/main.ts; new ui/src/novee/stories/Foundations/States.stories.tsx; an InteractionStates export per family`)

Add storybook-addon-pseudo-states. Foundations/States renders rows (Button outline / ghost / primary, Toggle, SegmentedControl, QuickFilter, FacetToggleChip, DropdownMenuItem, SelectItem, NovTabs x4, SidebarMenuButton, DataGridRow, TableRow, OptionCard, KPI, Input, SelectTrigger, Checkbox, Radio, Switch) by columns (rest, hover, pressed, selected, selected+hover, selected+focus, current, open, focus, disabled), driven by parameters.pseudo (hover, active, focusVisible) and the real attributes (aria-pressed, data-state, aria-current, disabled), under a globals.theme toggle so Chromatic captures both themes. The vitest story test (addon-vitest + addon-a11y) runs axe on every cell and asserts via getComputedStyle: hover != selected != rest background; selected+hover != selected; focus cell outline-width 2px, outline-style solid, outline-color --color-ring (fails if any rule leaves outline-style none); selected+focus cell: the selected fill and label are unchanged, the outline is present, and for inset rows boxShadow contains both the 3px page-coloured inset stroke and the 1px selected ring (--tw-inset-shadow and --tw-ring-shadow both resolved), for outset pills and cards the ring-1 edge is still in boxShadow; every selected cell contains a cue (data-slot=indicator, SelectedCheck, a checked input, or font-weight >= 500 plus a border in --color-border-selected); disabled cells have opacity 1 unless in the TILE list.

**Tailwind compile test for the focus constants and ARIA variants** (`frontend/packages/ui/src/novee/styles/focus-ring.test.ts (vitest, compile() from tailwindcss)`)

Compile theme.css plus [FOCUS_RING, FOCUS_RING_INSET, FOCUS_FIELD, 'outline-hidden', 'outline-none', 'ring-1', 'aria-pressed:ring-1', 'data-[state=active]:shadow-sm', 'aria-[current=page]:bg-ring', 'aria-current:bg-ring'] together, in that candidate order and in reverse, and assert: walking the emitted stylesheet in order, no rule after .focus-ring / .focus-ring-inset with specificity >= (0,2,0) sets outline-style: none for a :focus-visible selector (the case the old assertion missed: .outline-hidden is emitted after both utilities at (0,1,0) and loses only because the :focus-visible block restates outline-style); focus-ring emits `outline: var(--focus-ring-width) solid transparent` and a `&:focus-visible` block with both `outline-style: solid` and `outline-color: var(--color-ring)`; focus-ring-inset emits the negative offset, `--tw-inset-shadow: inset 0 0 0 calc(var(--focus-ring-width) + 1px) var(--color-bg-primary)` and a box-shadow equal to Tailwind's own variable list (the string .ring-1 and .aria-pressed\:ring-1 emit); FOCUS_RING / FOCUS_RING_INSET contain no `outline-` token; aria-current: compiles to [aria-current="true"], aria-[current=page]: to [aria-current="page"]. Guards the semantics across Tailwind upgrades.

**AGENTS.md section `## Interaction states`** (`frontend/packages/ui/AGENTS.md after `## Authoring rules``)

Classify by duration. TRANSIENT (hover, pressed, open, highlight) is neutral: surface-hover / -hover-strong / -pressed on bg-primary, surface-secondary-* on bg-secondary; border-hover for field and card edges, border-hover-strong for checkbox / radio / switch. PERSISTENT (selected, current, on, checked) is a brand tint (a deliberate departure from the neutral-fill majority: the slate ladder has no spare rung and the tint is never the only cue) plus ONE cue: border-selected (brand-1000 / brand-900) 2px edge on page-ground pills, pill and segmented tabs and cards; indicator-selected (brand-1000 / brand-700) bar / underline / check / dot everywhere else and on every secondary ground; neither is ever the ring's hex; text-selected for labels. Selected tabs and segments take no hover. FOCUS is --color-ring through FOCUS_RING, FOCUS_RING_INSET or FOCUS_FIELD / FOCUS_FIELD_WITHIN; never focus:, focus-within on a self-focusable element, ring-0, a brand primitive, or outline-none / outline-hidden next to a focus-ring utility. OPEN is the hover fill held plus a rotated chevron. DISABLED is text-disabled + a token fill at opacity-100; opacity-50 only on whole tiles; menu items Radix-disabled when inert, aria-disabled + reason and focusable when there is something to explain. CHECKED is action-primary-cta with a white glyph. Style from the attribute and emit it wherever a selected look is drawn. Component tokens are --<family>-<role>-<state>; -active is deprecated. `pnpm audit:theme` runs audit-tokens, scan-colors and scan-states; a PR that adds a state adds its column to the family's InteractionStates story.

### 5.4 Rollout

**Phase 0: scaffolding, no visual change**

- Scope: --focus-ring-width / -offset, @utility focus-ring / focus-ring-inset, focus-ring.ts constants + compile test, scan-states.mjs in warning mode, ESLint rules at warn, storybook-addon-pseudo-states + the empty Foundations/States grid, the AGENTS.md section, and the --color-muted-foreground bridge (62 webapp sites start rendering tertiary). The focus constants ship without outline-hidden and the compile test asserts the cascade (outline-style stays solid under :focus-visible with outline-hidden present).
- PRs: PR 1 (ui + ui-storybook), PR 2 (webapp eslint). Ships without touching consumers.
- Verification: pnpm audit:theme green; focus-ring.test.ts; Storybook builds with the addon; eyeball the text-muted-foreground sites.

**Phase 1: token flip plus the sites that would otherwise regress, one PR**

- Scope: The whole themeCssDiff (including the three rewritten comments), the DS primitives whose strings reference renamed tokens (button, toggle, facet-pill, QuickFilter, SegmentedControl, KPI, sidebar, NovTabs, tabs, table, DataGridRowShell, OptionCard, input / textarea / select / checkbox / radio / switch, trigger-hover) and the webapp sweep the neutral border-hover and surface-hover force: ~33 non-hover border-border-hover lines and 11 border-hover-muted lines that mean selected -> border-border-selected or the card / rail recipes; 9 ui + 17 webapp non-hover bg-surface-hover(-subtle) selected fills -> bg-surface-selected; static panels -> accent-info-light. Everything else re-renders through the tokens, including acul/src, which imports theme.css (PasswordInput.tsx:24, MethodList.tsx:26, organization-picker/index.tsx:115). ui/design-sync/baseline/tokens.css and the second ui/design-sync/* snapshot still declare --color-action-secondary-cta(-hover): they are frozen baselines of the retired sync pipeline, no script in `pnpm audit:theme` (audit:tokens + audit:colors) or elsewhere in ui reads them (verified by grep), so they stay untouched here and are deleted in Phase 4.
- PRs: PR 3, with the Foundations/States grid filled in so Chromatic reviewers compare against the model.
- Verification: audit-tokens --check with the state-role, ring-role and promoted collapse checks (0 errors; the #513a84 group keeps only category-bg-brand, the #ae92ff group loses border-hover and hover-muted and gains nothing, the #3f4046 group loses surface-disabled and action-secondary-cta-hover, the #c3b0ff group is brand-700 + emphasis-link-hover + indicator-selected via COLLAPSE_ALLOW, --btn-primary-ring-selected resolves to #e6dbfb); scan-states --check with rules 1, 2, 3, 4, 7, 11 as errors; Chromatic on Foundations/States and every InteractionStates story in both themes; Playwright smoke on the Issues, Assets and Assessments grids, the sidebar, Integrations filters and the assessment wizard in both themes, a keyboard-only pass with a screenshot per focus stop, and the acul login, method list and organization picker screens in both themes.

**Phase 2: focus recipe sweep**

- Scope: Replace the ~60 focus recipes (28|13 ring-ring/50, 26|13 ring-[3px], 13|9 focus-visible:ring-2, 2|4 ring-brand-*, 6|0 ring-[var(--input-border-active)], 3|10 focus-visible:ring-0, 10|0 focus:ring-, 3|0 has-focus:) with FOCUS_RING / FOCUS_RING_INSET / FOCUS_FIELD / FOCUS_FIELD_WITHIN, deleting every outline-none / outline-hidden on those elements (ui, webapp, acul 3 files); make clickable rows, KPI, QuickFilter, day pills, DateRangeFilter and the repository trigger real buttons with keyboard handlers; delete read-only:focus-visible:ring-0, the TemplateEditorForm ring-0 overrides and the destructive red ring.
- PRs: PR 4 (ui), PR 5 (webapp), PR 5b (acul, 3 files); no colour changes.
- Verification: scan-states rule 5 and the ESLint rules at error; keyboard Playwright pass repeated; the story vitest focus and selected+focus columns green in both themes.

**Phase 3: consumer consolidation**

- Scope: Webapp menus onto DropdownMenuItem / CommandItem; the six option-card copies onto OptionCard / OptionCardGroup; VeeVeeTabStrip, BrowsingTabBar, ViewTabs, Jira tabs onto NovTabs; rails onto StepRailButton; icon buttons onto IconButton; TagInput boxed; RichTextEditor owns its box; TitleInput; NameCell; ListRow; DayOfWeekToggleGroup; StepIndicator; delete common/RepositoryMultiSelect; replace hand-rolled switches and thick-border radios; rename active / isActive props.
- PRs: PR 6..n by area (shell + top bar, issues, assets + onboarding, settings + integrations, reports + chat, dashboard), independent.
- Verification: scan-states rules 6 and 8 flipped to error at zero count; ESLint clickable-needs-role and selected-needs-aria at error; Chromatic and Playwright per area.

**Phase 4: alias removal**

- Scope: Delete surface-hover-subtle, border-hover-muted, every *-active alias, --input-border-active, --btn-ghost-bg-active, ACTIVE_GHOST and the Button secondary alias; remove DEPRECATED from audit-tokens; delete the two ui/design-sync/* baseline folders; schedule the --*-surface -> --*-text rename with its ROLE_RE update.
- PRs: One PR, one release after Phase 3.
- Verification: grep for every retired name returns zero outside history; audit-tokens --check green without DEPRECATED; design-tokens.json keys reviewed.

## 6. Open decisions for the team

These are taste-level choices the model leaves open. Each is a token edit, not a component edit, once the model is in.

1. Selected label colour: the spec puts brand on fill, edge and label (text-selected). If design reads that as three purples on one pill, swap --btn-filter-surface-selected, --tabs-nav-item-surface-selected and --tabs-browsing-item-surface-selected to var(--color-text-primary): a token edit, not a component edit.
2. Whether selected tabs and segments stay inert to hover (as specified, per Radix / Fluent / Carbon) or take a selected-hover rung like pills and rows.
3. Light selected edge on brand-1000 (= the indicator and the primary CTA fill; 1.19:1 from the brand-900 ring) versus brand-900 (= the ring, separated by shape only): the spec picks brand-1000 so the audit-tokens clause border-selected != border-focus holds in both themes and CR-10 is met literally. If design prefers the lighter edge, delete that clause, write 'offset ring vs inset edge is the separator' into AGENTS.md, and accept one hex for two roles in light. The former decision about the 2.98:1 dark sidebar bar is closed: indicator-selected is brand-700 in dark (3.91:1 on the hovered current fill).
4. Focus ring hue: keep brand-900 / brand-800 (4.31 / 5.94:1, already tuned) or move to a high-contrast neutral (Fluent, GOV.UK); the inner stroke makes it a one-token swap.
5. Light neutral rungs on ramp steps (slate-300 / 400 / 700, as specified) versus ink mixes: ramp steps keep the file's convention and the only composed-pair collision (pressed = border-primary) is solved by slate-700.
6. Brand chips on tinted rows: keep the chip fill on the 42% rung (1.06:1 from the dark selected fill) and rely on the chip's border, or move the chip fill one rung, which changes every brand chip.
7. Dark indicator-selected shares brand-700 with emphasis-link-hover (allowlisted). The only other dark step that clears 3:1 on every selected rung is brand-800, which is the ring; brand-600 is text-selected. If the allowlist is unwanted, retarget emphasis-link-hover to brand-600 (#d4c6ff, 1.21:1 from brand-700) instead of moving the indicator.

## 7. Appendix and method notes

- All 234 verified findings with evidence: [`interaction-states-audit-2026-10-findings.md`](interaction-states-audit-2026-10-findings.md).
- Verification: every finding was re-opened at its cited lines by an independent pass that tried to refute it (5 refuted and dropped); every blocker and high finding then passed a user-perception review. The proposed model was scored by three judges and the final specification went through a completeness critique and one repair round; the mechanical coverage check (every finding id in a migration row or a won't-fix) passes.
- Contrast figures were computed from the resolved token manifest (`scripts/audit-tokens.mjs --emit-manifest`) with WCAG 2.x relative luminance; `color-mix` was resolved per channel in sRGB. Values should be re-measured in the browser after the token flip.
- Out of scope: the backoffice (separate palette) and Figma (no longer a reference for the design system).
- Audited commit of `novee-io/novee`: `ebc9335`.
