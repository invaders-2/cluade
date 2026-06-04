# Local Session Cleanup Template

Copy this template to `claude/processes/local-session-cleanup.md` in your project and customize for project-specific cleanup checks.

---

```markdown
# Project-Specific Session Cleanup

Project-specific checks to run after the generic session-cleanup ultrathink.

## Required Checks

Run these checks every session:

- [ ] **[Check name]** - [Brief description of what to verify]
- [ ] **[Check name]** - [Brief description of what to verify]

## Conditional Checks

Run these checks when the condition applies:

### If [condition, e.g., "API changes made"]
- [ ] [Check specific to this condition]
- [ ] [Another check]

### If [another condition]
- [ ] [Relevant check]

## Project-Specific Files

Key files to verify are current:

| File | Purpose | Update When |
|------|---------|-------------|
| [path/to/file] | [purpose] | [trigger for updates] |
| [path/to/file] | [purpose] | [trigger for updates] |

## Notes

[Any project-specific notes about cleanup priorities or common issues]

---

*Local cleanup checklist for [project name]*
```

---

## Example: Tableau Project

```markdown
# Project-Specific Session Cleanup

Project-specific checks for Tableau analysis project.

## Required Checks

- [ ] **Workbook sync** - Verify .twb files match analysis state
- [ ] **Data source freshness** - Check extract refresh dates
- [ ] **Dashboard screenshots** - Update if visualizations changed

## Conditional Checks

### If data model changed
- [ ] Update ERD in docs/
- [ ] Verify calculated fields still work
- [ ] Check dashboard performance

### If new data source added
- [ ] Document connection in LOCAL_CONTEXT.md
- [ ] Add to refresh schedule

## Project-Specific Files

| File | Purpose | Update When |
|------|---------|-------------|
| docs/data-dictionary.md | Field definitions | Schema changes |
| docs/refresh-schedule.md | Extract timing | New sources |

---

*Local cleanup checklist for Tableau*
```

---

## Example: API Project

```markdown
# Project-Specific Session Cleanup

Project-specific checks for API development project.

## Required Checks

- [ ] **API docs** - Verify OpenAPI spec matches implementation
- [ ] **Test coverage** - Check coverage didn't drop
- [ ] **Changelog** - Add entries for user-facing changes

## Conditional Checks

### If endpoints added/modified
- [ ] Update Postman collection
- [ ] Verify rate limiting configured
- [ ] Check authentication requirements

### If database migrations
- [ ] Verify rollback script exists
- [ ] Check index performance
- [ ] Update seed data if needed

## Project-Specific Files

| File | Purpose | Update When |
|------|---------|-------------|
| docs/api.yaml | OpenAPI spec | Endpoint changes |
| CHANGELOG.md | Version history | Any release |
| docs/deployment.md | Deploy process | Infrastructure changes |

---

*Local cleanup checklist for API*
```

---

## Usage

1. Copy the template to `claude/processes/local-session-cleanup.md`
2. Customize checks for your project's needs
3. Session-cleanup skill will automatically detect and load this file
4. Findings merge with generic ultrathink output

## Tips

- Keep checks specific and actionable
- Use conditional sections to avoid unnecessary work
- Include file paths for quick reference
- Update the checklist as project evolves

---

*Template for project-specific cleanup checklists*
