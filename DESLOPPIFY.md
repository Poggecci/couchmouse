# Desloppify: Codebase Quality & Slop Prevention Harness

You are acting as a Senior Systems Architect and Code Quality Agent. Your objective is to systematically identify, triage, and eliminate "AI slop" and technical debt from this codebase. You will maintain this file as a living document, updating the scorecard and backlog as you progress.

Your target is to achieve a **Strict Score of >98%**. You cannot game this metric.

---

## 1. Core Definitions of Code "Slop"

Analyze all codebase files and comments against these standards. 

### A. Mechanical Slop (40% weight)
*   **Dead Code**: Unused variables, unreachable code paths, and dead or dangling exports.
*   **Duplication**: Identical or near-identical logic blocks copy-pasted across files instead of using common helpers.
*   **Debug Residue**: Leftover print statements, `console.log` lines, commented-out testing code, or mock data files.
*   **Inconsistent Patterns**: Mixing syntax constructs (e.g., combining arrow and standard function declarations, or mixing callback styles and async/await inside the same module).

### B. Subjective & AI Slop (60% weight)
*   **Model Tells & Buzzwords**: Repetitive AI-generated qualifiers, preambles, and hypes (e.g., "robustly," "seamlessly," "dive into," "it is critical to note," "leverage").
*   **Comment & Doc Bloat**: Voluminous comments that merely restate obvious lines of code (e.g., `// Initialize index to zero` followed by `let i = 0;`), or redundant/stale docstrings.
*   **Premature Abstractions**: Over-engineered interfaces, helper modules created for single-use functions, or deep class hierarchies where simple inline logic or flat functions are better.
*   **Over-Validation**: Excessively verbose defensive exception checking for impossible cases, hiding simple flow logic behind a wall of try-catches.
*   **Boundary Violations**: Direct database calls from presentation layers, leaking private implementation details, or circular import graphs.

---

## 2. Priority Tiers & Weights

All issues must be classified into one of these four tiers:
*   **Tier 1 (Critical / Easy Fixes) [Weight: 1]**: Unused imports, left-over debug logs, syntax anomalies, and security vulnerabilities (e.g., unvalidated SQL execution, prototype pollution).
*   **Tier 2 (Important / Manual) [Weight: 2]**: Logic/type mismatches, dead variables, and unused exports.
*   **Tier 3 (Moderate / Judgment) [Weight: 3]**: Code duplication, bloated utility files, and minor design smells.
*   **Tier 4 (Cosmetic / Architectural) [Weight: 4]**: God files/components, AI prose/comment bloat, premature over-engineering, and layer boundary violations.

---

## 3. The Desloppify Loop (Your Instructions)

You must execute these steps in a strict, sequential cycle:
1.  **Scan**: Walk through the source files. Identify both mechanical and subjective issues based on the definitions in Section 1.
2.  **Triage**: Update the **Planning Ledger** below. Do not begin editing code until you have documented your themes, comparisons, clusters, and strategy.
3.  **Execute**: Fix the issues sequentially, prioritizing Tier 1 and Tier 2 before moving to T3/T4 clusters. Solve problems fully and cleanly, rather than with minimal band-aids.
4.  **Rescore**: After writing changes, run the project's test suites (if available) to ensure functional parity. Recalculate your quality scores and update the **Scorecard** below. Repeat until you hit the target.

---

## 4. Quality Scorecard (To be updated by the Agent)

*Last Updated: 2026-05-25 14:35*
*Total Files Scanned: 2*

### Current Scores
*   **Mechanical Score**: `100.0%`
*   **Subjective Score**: `100.0%`
*   **Overall Score**: `100.0%`
*   **Strict Score (The North Star)**: `100.0%` *(WontFix and Deferred issues are calculated as open/unresolved)*

### Metric Formula Reference
$$\text{Penalty} = \sum (\text{Issue Count} \times \text{Tier Weight})$$
$$\text{Score} = \max\left(0,\ 100 \times \left(1 - \frac{\text{Penalty}}{\text{Total Files Scanned} \times 10}\right)\right)$$
$$\text{Overall Score} = (0.4 \times \text{Mechanical Score}) + (0.6 \times \text{Subjective Score})$$

---

## 5. Planning Ledger (Triage Stages)

### Stage 1: Observe (Themes & Root Causes)
*   **Leakage of UI State/Context**: The presentation layer stores `BuildContext` and `StateSetter` references from the connection modal bottom sheet inside the parent widget state (`_HomeScreenState`), creating risks of memory leaks and invalid state references.
*   **AI Comment and Doc Bloat**: Voluminous comments that redundantly explain basic programming logic, such as label explanations in key layouts (`// Tab`, `// Enter`) and simple state variables (`// Mouse acceleration disabled by default`).
*   **Inconsistent Async Handling**: Connection state writes to SharedPreferences in `ConnectionStateNotifier` are fired synchronously without awaiting or returning futures, creating possible state race conditions.
*   **Dead Code**: Unused factory constructor `CouchMouseSettings.defaultSettings()`.

### Stage 2: Reflect (Design & Intent Drift)
*   The architecture was originally designed to use Riverpod for clean, reactive state management (like settings and connection state). However, state for paired devices and connection progress (connecting address, status updates) was kept as local widget state, leading to a hacky bypass (`_bottomSheetStateSetter` and `_bottomSheetContext`) to force UI updates in standard Flutter modal routes. This bypassed the clean Riverpod separation.

### Stage 3: Organize (Backlog Clustering)
*   `unused-cleanup`: Remove `CouchMouseSettings.defaultSettings()`.
*   `reactive-state-refactor`: Move `pairedDevices`, `isConnecting`, and `connectingAddress` to Riverpod providers, allowing the connection sheet to watch them and update automatically. Eliminate state setter and build context leakage. Make shared preferences writes async-safe and awaited.
*   `comment-stripping`: Delete all redundant/obvious AI-generated comments and buzzwords from `lib/main.dart` and `lib/settings_providers.dart`.
*   `duplication-reduction`: Consolidate duplicate HoldLock and Reset toolbar layouts.

### Stage 4: Strategy (Execution Plan)
1.  Obtain approval from the user on this ledger and execution plan.
2.  Refactor `settings_providers.dart` first: clean up the unused factory, expand `DeviceConnectionState` with connecting fields, make connection writes async.
3.  Add `pairedDevicesProvider` to expose paired devices reactively.
4.  Refactor `main.dart` UI: remove context/setter leaks, rewrite the bottom sheet to watch the Riverpod state.
5.  Clean up comments, strip obvious labels, and merge duplicate widgets.
6.  Re-run analyze and tests to verify everything remains green, and rescore.

---

## 6. Living Issue Queue

*Use the following statuses: `[Open]`, `[Fixed]`, `[WontFix]`, `[Deferred]`*

| ID | File & Line | Tier | Category | Description | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `001` | `lib/settings_providers.dart:36` | `T2` | `Mechanical` | Unused factory constructor `CouchMouseSettings.defaultSettings()`. | `[Fixed]` |
| `002` | `lib/settings_providers.dart:81` | `T2` | `Mechanical` | Synchronous state notifier method does not await or return futures for shared preferences writes. | `[Fixed]` |
| `003` | `lib/main.dart:1172` | `T4` | `Subjective` | Presentation layer leaks private implementation details by storing `StateSetter` and `BuildContext` in widget state. | `[Fixed]` |
| `004` | `lib/main.dart` | `T4` | `Subjective` | AI Prose & redundant comment bloat (e.g. key label explanations, obvious field comments). | `[Fixed]` |
| `005` | `lib/main.dart:2688` | `T3` | `Mechanical` | Duplicate layout code for HoldLock & Reset buttons in `_buildKeyboardToolbar` and `_buildForcedLandscapeHeader`. | `[Fixed]` |
