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

## Template & Macro Combining (Multi-Step Workflows)

Users should be able to combine templates and macros into multi-step workflows — chain them together so a single action runs an entire charting sequence.

### Concept
- Create a "combined workflow" that chains any mix of templates and macros in a user-defined order
- A workflow might look like: Apply "Negative Assessment" template → Run "Vitals entry" macro → Apply "Pain Section - Chronic" sub-template → Run "Sign note" macro
- Users can reorder the steps, enable/disable individual steps, or run the whole sequence end-to-end
- Each step can be a full template, a section sub-template, or a recorded macro

### Workflow Builder
- A GUI to build and edit workflows:
  - Add steps from saved templates, sub-templates, and macros
  - Drag-and-drop or up/down buttons to reorder
  - Checkboxes to enable/disable individual steps
  - "Run All" button to execute the full sequence, or click individual steps to run just that one
- Workflows are saved as JSON files referencing the component templates/macros by name/path

### Use Cases
- **Full shift charting**: Combine a negative assessment template with specific abnormal section templates and any follow-up macros into one workflow
- **Admission charting**: Chain admission assessment template + fall risk macro + skin assessment template + education template
- **Quick re-chart**: Run the same multi-step charting sequence across multiple patients with one click

### Implementation Notes
- Builds on the existing template apply and macro playback infrastructure
- Workflow JSON stores an ordered array of steps, each referencing a template path or macro path plus a step type ("template" or "macro")
- The runner iterates steps sequentially, calling `NB_ApplyNamedTemplate` or `NB_ExecuteMacro` for each
- Between steps, wait for CPRS to settle and dismiss any intermediate popups
- Ties into the section-by-section concept — a workflow could include section sub-templates as individual steps
