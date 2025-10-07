
# EcoMove Design System Documentation

## 1. Brand Personality
EcoMove is designed for eco-conscious users who want a modern, playful, and professional app experience.  
The design system emphasizes sustainability, clarity, and delight.

---

## 2. Color Palette

### Primary Colors
- **Eco Mint**: `#3CD4A0` (RGB: 60, 212, 160)  
  Usage: Primary CTAs, key highlights.

- **Vibrant Coral**: `#FF6B6B` (RGB: 255, 107, 107)  
  Usage: Route highlights, error states, important accents.

- **Solar Yellow**: `#FFD166` (RGB: 255, 209, 102)  
  Usage: Secondary buttons, notification accents.

### Neutral Colors
- **Off-White Sand**: `#F8F7F4` (RGB: 248, 247, 244)  
  Usage: Backgrounds.

- **Deep Charcoal**: `#1C1C1C` (RGB: 28, 28, 28)  
  Usage: Dark mode backgrounds, text.

- **Cool Grey**: `#A1A1A1` (RGB: 161, 161, 161)  
  Usage: Secondary text, dividers.

---

## 3. Typography

### Font Families
- **Headings:** Poppins (Google Font)  
- **Body Copy:** Inter (Google Font)  
- **Accent (badges, highlights):** Optional Handwritten-style font (e.g., Caveat) for playful highlights.

### Font Sizes & Usage
- H1: 32px / Bold — Page titles  
- H2: 24px / Semi-Bold — Section titles  
- H3: 20px / Medium — Sub-sections  
- Body Large: 16px / Regular — Primary body text  
- Body Small: 14px / Regular — Secondary text  
- Caption: 12px / Regular — Labels, meta information

**Do’s:**  
✔ Use Poppins for bold, friendly headers.  
✔ Keep Inter for readability in body text.  
✔ Limit accent font to gamified UI elements.  

**Don’ts:**  
✘ Don’t use handwritten font for navigation or dense text.  
✘ Don’t mix too many weights in the same block.

---

## 4. Layout & Spacing System

### Grid System
- **Mobile:** 8-column grid, 16px gutter  
- **Tablet:** 12-column grid, 20px gutter  
- **Desktop:** 12-column grid, 24px gutter  

### Spacing Scale
- 4px — Tiny (icon padding, small gaps)  
- 8px — Small (button paddings, inner spacing)  
- 16px — Medium (card padding, section spacing)  
- 24px — Large (component separation)  
- 32px — Extra Large (major section spacing)

**Do’s:**  
✔ Stick to multiples of 4px for consistency.  
✔ Use larger spacing for breathing room on main screens.  

**Don’ts:**  
✘ Avoid arbitrary pixel values.  
✘ Don’t crowd CTAs close to edges.

---

## 5. Components

### Buttons
- **Primary:** Eco Mint background, white text, pill shape, 16px padding.  
- **Secondary:** Solar Yellow background, charcoal text.  
- **Tertiary:** Text-only with Coral hover/active state.

**Do’s:**  
✔ Use Primary button for main action per screen.  
✔ Provide hover/tap animation (pulse or subtle shadow).  

**Don’ts:**  
✘ Don’t place more than one Primary CTA per screen.  
✘ Don’t use Coral as a Primary button background.

---

### Cards
- **Style:** Rounded corners (16px), soft shadow, off-white background.  
- **Content Layout:** Icon/visual at top, bold title, supporting text, optional badge.  

**Do’s:**  
✔ Use cards for route summaries, eco-badges, or trip results.  
✔ Keep consistent padding (16px).  

**Don’ts:**  
✘ Don’t overload cards with more than 3 levels of hierarchy.  
✘ Don’t use sharp corners (must remain rounded).

---

### Map & Route Display
- **Base Map:** Muted sand + mint hues.  
- **Routes:**  
  - Green = Eco-friendly  
  - Coral = Fastest  
  - Yellow = Cheapest  

**Do’s:**  
✔ Show primary route with bold color and animated path (growing vine effect).  
✔ Use icons for mode of transport.  

**Don’ts:**  
✘ Don’t default to generic blue Google Maps-style lines.  
✘ Don’t show more than 3 route types at once.

---

### Badges & Gamification
- **Eco Badge:** Animated icons (leaf sprout, tree, sparkle).  
- **Metric Highlight:** "You saved 5kg CO₂ this week!"  

**Do’s:**  
✔ Animate badges when earned.  
✔ Use playful accent font for badges.  

**Don’ts:**  
✘ Don’t animate constantly — limit to trigger events.  
✘ Don’t use badges for non-eco-related features.

---

## 6. Visual Hierarchy
1. **Map route highlight** = Hero element (largest, central).  
2. **Options Panel** = Secondary (tabs/cards with route summaries).  
3. **Detailed List** = Tertiary (expanded info).  

Flow ensures user first sees *where* they’re going, then *how* to get there, then details.

---

## 7. Microinteractions & Motion
- **Route Animation:** Line grows like a vine across map.  
- **Completion Feedback:** Leaf confetti when trip completed.  
- **Swipe-to-Compare:** Route options as flipping eco trading cards.

---

## 8. Accessibility Rules
- Minimum contrast ratio: 4.5:1 for text.  
- Button target size: 48x48px minimum.  
- Always provide icon + label (not just color).  

---

## 9. Do’s & Don’ts Recap
**Do’s:**  
✔ Keep design playful yet professional.  
✔ Maintain eco-friendly brand colors and animations.  
✔ Use spacing to guide attention.  

**Don’ts:**  
✘ Don’t clutter routes or overload screens.  
✘ Don’t deviate from rounded, friendly UI style.  
✘ Don’t mix too many visual metaphors.
