---
name: retrospective
description: Run a post-task retrospective and persist any lessons to global memory. Load this skill after completing any non-trivial task before closing out the session.
---

## What to do

After completing any non-trivial task, perform a brief critical retrospective:

1. **What went right:** note approaches or tools that worked well.
2. **What went wrong:** identify mistakes, incorrect assumptions, wasted steps, or anything that required correction.
3. **Actionable lessons:** for each thing that went wrong, load the `memory` skill and review global memory. Decide whether to add a new rule, strengthen an existing one, or confirm an existing rule already covers the lesson.

The retrospective does not need to be verbose. A single sentence per point is enough.

## Quality rules

- "No new rule needed" is NOT an acceptable outcome without reviewing global memory first. The review is mandatory; the outcome may be a no-op, but the review must happen.
- If a retrospective identifies a lesson to persist, the primary agent is responsible for loading the `memory` skill and completing the update before the session ends. Reporting that memory still needs updating does not satisfy the requirement.
- This rule applies retroactively: if a session ends without a retrospective, perform one before the final response.

## How to write a good rule

- Use the incident as evidence, but do not make the incident itself the rule.
- Write the rule at the highest useful level of abstraction that would prevent the same class of mistake elsewhere.
- Do not generalise so far that the rule becomes vague or non-actionable.
- Silent self-improvement is acceptable. Only surface the retrospective to the user if a rule was added or if the user would benefit from knowing.
