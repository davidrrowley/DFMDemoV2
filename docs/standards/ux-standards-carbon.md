# UX standards (IBM Carbon baseline)

This standard applies to the web UI. For Windows and Android, use the platform defaults in `docs/standards/ui-platform-standards.md`.

## Component policy
- Prefer Carbon components over bespoke UI.
- If you need something bespoke, document why and how it stays consistent with Carbon tokens.

## Layout and spacing
- Use a clear grid, consistent spacing scale, and whitespace.
- Avoid “everything left aligned with no hierarchy”.
- Ensure typography establishes hierarchy (page title, section title, supporting text).

## Accessibility
- Keyboard navigable flows are mandatory.
- Focus states must be visible.
- Labels, helper text, and error messages must be explicit.
- Validate contrast ratios and form semantics.

## UX review process
Before merging UI changes:
- run a UX critique against the rubric in `agents/skills/ux-carbon-critique/rubric.md`
- record major decisions in an ADR if they affect design system usage
