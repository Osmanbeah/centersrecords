---
name: Center Tracker
colors:
  surface: '#f5fbf9'
  surface-dim: '#d5dbd9'
  surface-bright: '#f5fbf9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff5f3'
  surface-container: '#e9efed'
  surface-container-high: '#e4e9e7'
  surface-container-highest: '#dee4e2'
  on-surface: '#171d1c'
  on-surface-variant: '#414844'
  inverse-surface: '#2c3231'
  inverse-on-surface: '#ecf2f0'
  outline: '#717973'
  outline-variant: '#c1c8c2'
  surface-tint: '#3f6653'
  primary: '#012d1d'
  on-primary: '#ffffff'
  primary-container: '#1b4332'
  on-primary-container: '#86af99'
  inverse-primary: '#a5d0b9'
  secondary: '#0e6c4a'
  on-secondary: '#ffffff'
  secondary-container: '#a0f4c8'
  on-secondary-container: '#19724f'
  tertiary: '#242623'
  on-tertiary: '#ffffff'
  tertiary-container: '#3a3c39'
  on-tertiary-container: '#a5a6a2'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#c1ecd4'
  primary-fixed-dim: '#a5d0b9'
  on-primary-fixed: '#002114'
  on-primary-fixed-variant: '#274e3d'
  secondary-fixed: '#a0f4c8'
  secondary-fixed-dim: '#85d7ad'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#e2e3de'
  tertiary-fixed-dim: '#c6c7c2'
  on-tertiary-fixed: '#1a1c19'
  on-tertiary-fixed-variant: '#454744'
  background: '#f5fbf9'
  on-background: '#171d1c'
  surface-variant: '#dee4e2'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 30px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  margin-mobile: 1.25rem
  gutter-mobile: 1rem
  stack-sm: 0.5rem
  stack-md: 1rem
  stack-lg: 1.5rem
---

## Brand & Style
The design system for this product centers on clarity, reliability, and ease of use in professional administrative contexts. The brand personality is grounded and authoritative yet approachable, reducing the cognitive load associated with financial collection and attendance tracking.

The design style is **Corporate Modern** with a focus on **Soft Minimalism**. It prioritizes high legibility and a calm emotional response through a warm, organic color palette and generous negative space. The UI avoids aggressive shadows or complex gradients, opting instead for a "Tactile Paper" feel that suggests stability and organized record-keeping.

## Colors
This design system utilizes a nature-inspired palette to evoke a sense of growth and trust.

- **Primary (#1B4332):** A Deep Forest Green used for primary actions, headers, and active states. It provides the "anchor" for the interface.
- **Secondary (#74C69D):** A Soft Sage Green used for success states, badges, and secondary accents.
- **Background (#F7F7F2):** A warm off-white/cream surface that reduces eye strain compared to pure white and enhances the "professional ledger" feel.
- **Text (#2D3332):** A deep charcoal for high-contrast legibility, avoiding the harshness of absolute black.
- **Border (#E5E5E0):** A subtle hairline neutral for defining structure without creating visual noise.

## Typography
**Inter** is the sole typeface for this design system, chosen for its exceptional legibility and neutral, professional character.

- **Headlines:** Use Bold weights with slight negative letter-spacing to create a strong visual hierarchy for page titles and section headers.
- **Body Text:** Standardize on 16px for primary information to ensure accessibility in high-activity environments.
- **Labels:** Use uppercase with increased letter-spacing for small metadata or "overlines" above titles.
- **Numerical Data:** For collection amounts and attendance counts, use the tabular figures feature of Inter to ensure vertical alignment in lists and tables.

## Layout & Spacing
The layout follows a **Fluid Grid** model optimized for mobile-first usage. 

- **Margins:** A consistent 20px (1.25rem) side margin ensures content does not feel cramped against the edge of the device.
- **Vertical Rhythm:** A base 4px/8px spacing system is used. Components should be separated by 16px (stack-md) for related items and 24px (stack-lg) for new sections.
- **Touch Targets:** All interactive elements maintain a minimum height of 48px to accommodate efficient data entry.
- **Alignment:** Left-aligned content is preferred for readability in lists and forms, while numerical collection data should be right-aligned for easy comparison.

## Elevation & Depth
This design system uses **Tonal Layers** supplemented by **Subtle Shadows** to communicate hierarchy.

- **Level 0 (Background):** The warm off-white surface (#F7F7F2).
- **Level 1 (Cards/Containers):** Pure white (#FFFFFF) surfaces with a 1px hairline border (#E5E5E0).
- **Level 2 (Active/Floating):** Used for primary buttons or active modal states. This level uses an "Ambient Shadow": a very soft, diffused shadow (0px 4px 12px) with a low-opacity tint of the primary color (10% opacity).

Avoid heavy drop shadows or glows; depth should feel like stacked sheets of high-quality paper.

## Shapes
The shape language is characterized by **Rounded Corners**, which soften the professional aesthetic and make the app feel more modern and inviting.

- **Standard Elements:** Buttons, input fields, and small cards use a 12px (0.75rem) radius.
- **Large Containers:** Bottom sheets and full-width cards use a 16px (1rem) radius.
- **Indicator Shapes:** Progress bars and selection chips use fully rounded (pill-shaped) ends to differentiate them from structural layout elements.

## Components

- **Buttons:** Primary buttons are solid Forest Green (#1B4332) with white text. Secondary buttons use a Sage Green outline. All buttons have a height of 48px-52px.
- **Input Fields:** Use a subtle grey background or a simple 1px bottom border. Labels should persist above the field in the `label-md` style.
- **Cards:** White background with 12px rounding. Use these for individual student records or collection summaries.
- **List Items:** High-density lists for attendance should include a leading icon or avatar, a primary title, and a trailing metadata label (e.g., status or time).
- **Icons:** Use linear, 2px stroke icons. 
    - **plus-square:** For "New Entry" (Attendance/Payment).
    - **list:** For "Records" (History).
    - **users:** For "Manage" (Student/Center Directory).
- **Status Chips:** Use secondary soft greens for "Paid" or "Present" and a muted warm grey for "Pending" to maintain the calm palette.