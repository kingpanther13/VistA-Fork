# CPRSBooster / Nursing Booster - Future Plans

## Section-by-Section Assessment Mode

The current template system applies a full assessment template all at once — every section gets the same saved state. In practice, most shift assessments have 8-10 negative/WNL systems and 1-2 abnormal ones that need specific charting. A section-by-section mode would make this faster and more flexible.

### Concept
- When applying a template, show a pre-apply dialog that lists each assessment section (Neuro, Cardiac, Respiratory, GI, GU, Skin, Musculoskeletal, Pain, Psychosocial, Safety, ADLs, etc.)
- Each section gets a dropdown or toggle:
  - **Negative** — auto-fill with saved WNL/normal defaults for that section
  - **Abnormal** — leave blank for manual charting, OR pick from a saved abnormal sub-template
  - **Skip** — don't touch this section at all
- Sections map to the top-level parent checkboxes and their corresponding TGroupBox groups in the CPRS reminder dialog

### Abnormal Sub-Templates
- Users can save per-section sub-templates for common abnormal findings
  - e.g. "Cardiac - AFib with RVR", "Respiratory - BiPAP/CPAP", "Neuro - CVA precautions", "Skin - Stage 2 sacral wound"
- The abnormal dropdown for each section would list any saved sub-templates for that body system
- Sub-templates would store just the checkboxes for that one section/group, not the whole assessment

### Implementation Notes
- Builds on the existing v5 template apply and group-matching infrastructure
- The section list can be auto-detected from the live dialog's TGroupBox structure
- Section names could be resolved from the top-level parent checkbox labels (or manually mapped for known VA assessment templates like VAAES ACUTE INPATIENT NSG SHIFT ASSESSMENT)
- Sub-templates would be small JSON files stored in a subfolder per assessment type (e.g. `NursingTemplates/Sections/Cardiac/`)
- The pre-apply dialog would be a new GUI (similar to the macro builder) with a listview of sections and per-row dropdowns
