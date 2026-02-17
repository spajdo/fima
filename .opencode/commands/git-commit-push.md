---
description: Commit and push to git
agent: build
---

Analyze changes and create a commit message. Follow this workflow:

1. Run `git status` and `git diff` to see all modifications
2. Generate a commit message using the format:
   - `feat: <description>` - for new features
   - `fix: <description>` - for bug fixes
   - `refactor: <description>` - for code refactoring
   - `docs: <description>` - for documentation changes
   - `chore: <description>` - for maintenance tasks
3. Ask "Is this commit message OK?" with the proposed message
4. If the user suggests changes, update the message and ask again
5. When the user says "yes":
   - Stage: `git add -A`
   - Commit: `git commit -m "<message>"`
   - Push: `git push`

Only commit when explicitly asked. Never commit automatically.
