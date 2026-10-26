# Architectural Deviations & Decisions

Per Section 1.2.1 of the Master Rulebook, every deliberate deviation from preexisting repo defaults is cataloged below with justification and mitigation:

| Area | Preexisting Repo Choice | Adopted Solution | Justification | Reversion Path |
|---|---|---|---|---|
| **Color System** | Default Teal seed (`#0F766E`) in `frontend/lib/main.dart` | Custom **Matcha & Almond design system** (PART 4): Matcha (`#809671`), Almond (`#E5E0D8`), Pistache (`#B3B792`), Chai (`#D2AB80`), Carob (`#725C3A`), Vanilla (`#E5D2B8`) | Explicit master rulebook exception (Section 1.2). Ensures WCAG AA/AAA contrast ratios (> 4.5:1), professional ledger aesthetic, and eliminates generic "AI-generated" vibe. | Revert `AppTheme.lightTheme` seed color in `lib/core/theme/` to `#0F766E`. |
| **Backend Framework** | Team started FastAPI (Python) scaffold | Retained FastAPI rather than introducing Node.js | Adheres to Rule 1.2: "The repository comes first." Team already committed Python requirements and FastAPI structure. | Node.js/Express can be substituted if team formally decides to migrate. |
| **Frontend Architecture** | Single flat `main.dart` | Structured clean architecture: `lib/core` (tokens, components, l10n, routing) + `lib/features` | Accommodates 12 modules and multiple screens cleanly without collisions. Leaves other feature slots open for teammates. | Screens can be flattened back into single packages if required. |
| **Navigation Architecture** | Separate Purchasing & Sales bottom tabs | 5-position bottom navigation with central prominent Scan button and unified Transactions hub (Orders, Suppliers, Inward Bills, Sales Reports) | Direct prompt mandate (Sections 4.1 & 4.2). Makes document scanning explicit and separates Stock In from Stock Out while maintaining 100% feature accessibility. | Revert `bottom_nav_bar.dart` and `main_shell_screen.dart` to 5-destination flat tab array. |
