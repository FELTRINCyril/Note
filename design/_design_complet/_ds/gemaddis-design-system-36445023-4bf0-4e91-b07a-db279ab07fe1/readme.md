# GemAddis — Design System

Brand and UI design system for **GemAddis**, a French distributor & integrator of electronics-assembly (SMT/CMS) equipment.

## Company context
GemAddis (Seynod, 74 — Annecy) is a **distributor & integrator** that delivers a *complete, interconnected solution* for the assembly of printed-circuit boards — not just machines. Its offer spans four pillars:

- **Équipements** — production-line machines: screen-printing (sérigraphie), pick & place, reflow (refusion), inspection (AOI / SPI / X-ray, partner **Vitrox**), wave/selective/vapour-phase soldering, dispensing, depaneling, transit.
- **Outillages** — the tooling that goes *inside* the equipment: SMT stencils, wave-solder frames, test interfaces, Jedec trays, press-fit & bespoke tooling (manufactured in-house).
- **Consommables** — supplies for the equipment and the boards produced: solder paste, flux, cleaning agents, alloys, Galden.
- **Logiciel** — a software layer (**KreAddis** + **Odoo**) that **interconnects all the machines** and feeds a **MES / ERP**, giving traceability and connected production.

Clients are electronics industrials such as Valeo, Asteelflash, Celduc. GemAddis is the result of the merger of **Gemido** (stencil & frame manufacturing) and **Addis Electronic** (equipment distribution). Brand values: *écoute, conseil, réactivité, proximité, innovation.*

### Baseline / positioning
The brand promise is a **global, connected solution** — equipment + tooling + consumables + software — across the whole electronics-assembly chain, *de la machine au MES/ERP*. Default deck baseline:

> **Une solution globale** — Équipements · Outillages · Consommables · Logiciel MES/ERP. *« Équipements, outillages et consommables, interconnectés par notre logiciel KreAddis & Odoo pour alimenter votre MES / ERP. »*

Alternative baselines to choose from: *« De la machine au MES — la chaîne d'assemblage électronique de bout en bout »* · *« Plus qu'un équipement : une solution connectée pour votre Process »*. Avoid narrow taglines like "lignes de production CMS" — they undersell the tooling, consumables and software pillars.

Deliverables this system supports: commercial & technical presentations, quotes/offers, industrial documents.

### Sources
- Website: https://www.gemaddis.com (product catalogue, copy tone, imagery references — fetched June 2026).
- Uploaded asset: `uploads/logo_gemaddis.png` (primary horizontal logo).
- Brand brief: primary orange `#F96514`, secondary slate `#495458`, typeface **Arial**, tone industrial/technical, title-slide convention (PCB photo + trapezoidal orange banner + logo). **Light mode only — the brand does not want dark backgrounds.**

No codebase or Figma was provided — foundations are derived from the brief, the logo, and the public website.

---

## CONTENT FUNDAMENTALS
- **Language:** French. All product/UI copy is in French (technical terms often kept in English/industry jargon: *pick & place, AOI, SPI, X-ray, SMEMA, Hermes*).
- **Voice:** Industrial, technical, precise, serious — no whimsy, no hype, no emoji. Speaks as a knowledgeable partner ("nous"), addresses the client as "vous".
- **Casing:** Sentence case for prose. **UPPERCASE** reserved for labels, eyebrows, buttons, banners (with wide letter-spacing). Headings are bold sentence case.
- **Emphasis:** Key value phrases are **bolded inline** inside running text — a defining habit on the site, e.g. "des **solutions sur-mesure**", "un véritable **partenariat technique**", "une **solution** pour votre Process".
- **Proof points:** Short, factual stat strips — "+20 ans d'expérience", "Livraison sous 24-48h", "Paiement sécurisé", "Support technique 7J/7".
- **CTAs:** Imperative and short — "Découvrir", "Catalogue", "En savoir plus", "Configurez et commandez".
- **Examples of tone:** *"Une offre complète pour les professionnels de l'industrie électronique."* · *"Gemaddis vous offre plus qu'un équipement, une solution pour votre Process."*
- No emoji. Unicode used only for technical/typographic punctuation (×, µm, →, ·, ™, ®).

## VISUAL FOUNDATIONS
- **Colors:** White-dominant pages. **Orange `#F96514`** is the accent — used *sparingly* for CTAs, the trapezoid banner, ticks, rules, KPI numbers and top-edges. **Slate `#495458`** and its scale carry structure, text and dark surfaces. Near-black ink `#1A1A1A` (the logo "DDIS") is the strongest text. Status colors are muted/industrial. Avoid large orange fills and avoid gradients except subtle dark PCB scrims.
- **Type:** Arial (system) throughout — Regular + Bold only. Bold + uppercase + wide tracking for labels; bold sentence-case for headings; regular 1.6–1.65 line-height for body. Tight negative tracking on large display sizes.
- **Spacing:** 4px base scale; generous, airy padding (slides breathe). Clear grid, aligned columns.
- **Backgrounds:** **Light only — no dark mode.** Mostly flat white or `--gem-slate-50`. Technical/blueprint sections use a **light blueprint texture** (fine slate grid + faint solder-pad dots + a subtle warm orange glow over `--gem-slate-50`). Full-bleed photography of PCBs / production lines is the hero imagery; image-slots sit over the light blueprint as a fallback. Avoid dark teal/slate fills behind content.
- **Geometry:** Sharp, franc angles. The signature device is the **trapezoidal (skewed -12°) orange banner**. Corners are near-square (radius 2–4px); pill only for chips/toggles.
- **Borders:** 1px hairline `--gem-slate-200/300`. A **3px orange top-edge** marks emphasis cards and footers. Accent left-rule (3px orange) on stats.
- **Shadows:** Restrained and functional — `sm`/`md`/`lg` are soft, low-spread slate shadows. No glow, no neon.
- **Cards:** White surface, hairline border, square-ish corners, subtle `shadow-sm`; optional orange top edge; hover lifts 2px to `shadow-lg`.
- **Hover/press:** Hover = darker orange (`--gem-orange-600`) or slate-50 tint; press = 1px translate-down. Inputs focus to orange border + faint orange ring.
- **Motion:** Precise, quick (120–260ms), `cubic-bezier(0.2,0,0.2,1)` — no bounce, no playful easing. Fades/translations only.
- **Transparency/blur:** Minimal. Light slate scrims at most; no dark photo overlays, no frosted-glass UI.
- **Imagery vibe:** Cool, technical PCBs and machinery, clean factory lines, shown on **light** layouts. Orange is the single warm accent.

## ICONOGRAPHY
- The brand has **no proprietary icon font**. The website uses small per-product **SVG/PNG glyphs** (catalogue menu thumbnails) and photographic product images — these are product-specific assets, not a reusable line-icon set.
- This system therefore standardizes on **Lucide** (CDN) as the line-icon set for UI needs — thin, geometric, even stroke, which matches the precise industrial tone. Load from `https://unpkg.com/lucide@latest`. **(Substitution — flagged: GemAddis has no official UI icon set; confirm or replace.)**
- The **orange tick** (a 18–24px × 3px orange bar) is the brand's recurring non-glyph "icon" before eyebrows/labels — prefer it over decorative icons.
- **No emoji.** Unicode symbols (→, ×, ·, µm, ™) only where typographically correct.
- Logos live in `assets/` (`logo_gemaddis.png` full-color for light; `logo_gemaddis_white.png` knockout for dark/photo backgrounds).

---

## Index / manifest
**Root**
- `styles.css` — entry point (imports only).
- `tokens/colors.css`, `tokens/typography.css`, `tokens/spacing.css` — design tokens.
- `assets/` — `logo_gemaddis.png`, `logo_gemaddis_white.png`.
- `SKILL.md` — Agent-Skill entry for downloadable use.

**Components** (`components/`) — `window.GemAddisDesignSystem_364450`
- `core/` — `Button`, `Badge`, `Card`, `Stat`, `Overline`
- `forms/` — `Input`
- `brand/` — `TrapezoidBanner`

**Slides** (`slides/`) — title-convention deck kit: `index.html` (deck), `TitleSlide`, `SectionSlide`, `ContentSlide`, `ClosingSlide`.

**Specimen cards** (`guidelines/`) — colors, type, spacing, brand cards shown in the Design System tab.

> Starting points: `Button`, `Card`, `TrapezoidBanner` (components) and `slides/index.html` (screen).
