# Evaluation Plan

This plan describes how CALMQUEST *could* be evaluated. **No user study has been run yet**, and the repository contains no results from real participants.

## 1. What we want to learn

| Question | Type |
|---|---|
| Can first-time players start, understand and complete a session without help? | Usability |
| Do players understand the modes, the check-in and the consent choice? | Comprehension |
| Do players find the adaptive suggestions and assistance helpful or intrusive? | Experience |
| Is the game enjoyable, calm and low-pressure? | Experience |
| How do self-reported scores before and after a session compare? | Descriptive only |

A causal question ("does playing reduce self-reported stress compared with an alternative activity?") is **out of scope** for the MVP. It would require the design in section 5.

## 2. Phase A - Small usability test (next step)

- **Participants:** 5-8 adult volunteers, informed consent, no clinical population, no compensation pressure.
- **Procedure:** think-aloud play session (about 10 minutes), then a short interview.
- **Tasks:**
  1. start and complete the check-in;
  2. gather light and restore the Heart Tree;
  3. change mode in the pause menu;
  4. try Lantern Catch;
  5. finish and read the results;
  6. find where data is stored and delete it.
- **Measures:**
  - task success and critical incidents;
  - System Usability Scale (SUS);
  - perceived pressure (1-5 item);
  - comprehension of the consent and results screens (open questions);
  - the in-game experience rating.
- **Data handling:** in-game storage only with each participant's consent, plus notes without names. Participants can withdraw at any time.
- **Success criteria:**
  - every participant can finish a session unaided;
  - at least 80% correctly explain what is stored and how to delete it;
  - no participant reads the results screen as a diagnosis or a judgement.

## 3. Phase B - Preference evaluation

A within-subject comparison of the fixed Balanced mode against the player's own chosen or suggested mode, in counterbalanced order. It would measure preference, perceived helpfulness of assistance and enjoyment. The question is about **experience**, not health.

## 4. Analysis approach

- Use `analysis/analyze_sessions.py` and the notebook on exported, consented CSVs.
- Report denominators, missing data (how many skipped each question) and excluded invalid records.
- Use descriptive statistics and visualisations. With small samples, report effect sizes with uncertainty (e.g. bootstrap confidence intervals) rather than p-value claims.
- Describe paired score differences only as observations in the sample, for example: *"In this dataset, the average post-session self-reported score was lower than the average pre-session score."*

## 5. What a causal study would require

- Ethics review and a pre-registered protocol.
- Randomized comparison with an appropriate control activity of similar length (e.g. a non-adaptive version or a neutral task).
- A validated, appropriate outcome measure instead of a single 0-10 item, with a sample size justified by power analysis.
- Handling of expectancy effects, regression to the mean and missing data.
- Independent analysis and transparent reporting, including null results.

## 6. Threats to validity (current data)

- Self-selection: only players who opt in contribute data.
- Single subjective item, answered twice within minutes (anchoring, demand effects).
- No control condition; time of day and context are not captured.
- Skipped reflections may not be missing at random.
- Synthetic sample data in this repository has **no evidential value**.

## 7. Ethics and responsible-AI commitments

- No diagnosis, labels or clinical claims.
- Players can skip any question and stop at any time.
- No pressure to report improvement.
- No data leaves the device unless the player shares an export.
- Any future model would be evaluated against the rule-based baseline and reported with its limitations.
