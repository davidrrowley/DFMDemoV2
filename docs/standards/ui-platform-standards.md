# UI platform standards

## Scope
These standards define the default design systems for each platform in this template.

## Platform baselines
- Web: IBM Carbon (React or Web Components) for components, layout, and tokens.
- Windows: Fluent UI for controls, navigation, and typography.
- Android: Material Design 3 for components, motion, and theming.

## Token alignment
- Maintain a single canonical token set for color, typography, spacing, radius, elevation, and motion.
- Map canonical tokens to each platform system and document any deltas.
- Avoid platform-only overrides unless required; record the rationale when used.

## Cross-platform parity
- Keep information hierarchy and terminology consistent across platforms.
- Prefer native platform patterns for navigation, density, and accessibility.
- Track intentional differences per feature and review them periodically.

## References
- Carbon Design System: https://www.carbondesignsystem.com/
- Carbon React: https://carbondesignsystem.com/developing/frameworks/react/
- Carbon Web Components: https://carbondesignsystem.com/developing/frameworks/web-components/
- Fluent UI: https://developer.microsoft.com/en-us/fluentui
- Material Design 3: https://m3.material.io/
