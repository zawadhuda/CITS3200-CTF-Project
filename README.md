# CITS3006 CTF Project

Repository for our CITS3006 Penetration Testing group project.

## Team

| Member | GitHub Username | Responsibilities |
|---|---|---|
| Zawad | @zawadhuda | TBD |
| Michael Ang | TBD | TBD |
| Dhava Wikhananda Adhi | TBD | TBD |
| Hamish Haslam | TBD | TBD |
| Yashwardhan | TBD | TBD |

## Project Overview

This repository contains the source code, scripts, testing material,
technical documentation, and supporting evidence for our CITS3006
group project.

## Repository Structure

- `src/` - Main project source code (Flask app, challenge workers, VM setup)
- `scripts/` - Supporting scripts and utilities (`package_app.sh` builds the clean VM app dir)
- `challenges/` - Standalone CTF services (auth service, vault) — not part of the web app
- `docs/` - Technical documentation and design notes (`FLAGS.md` is authors-only, never ships to the VM)
- `evidence/` - Screenshots and supporting project evidence

## Team Workflow

1. Create a GitHub Issue for each task.
2. Assign the Issue to a team member.
3. Create a branch from `main`.
4. Complete the work on that branch.
5. Commit and push the changes.
6. Open a Pull Request.
7. Another team member reviews the Pull Request.
8. Merge the approved Pull Request into `main`.

## Branch Naming

Examples:

- `feature/task-1`
- `feature/network-scanner`
- `fix/input-validation`
- `docs/report`
- `test/task-2`

## Commit Message Examples

- `feat: add task 1 implementation`
- `fix: handle invalid input`
- `docs: update project documentation`
- `test: add task 1 tests`

## Project Management

Development tasks are tracked using GitHub Issues and the GitHub Project board.

Formal documentation, meeting notes, reports, research, and presentation
material are stored in the team's shared Google Drive.

## Important

All penetration-testing activities must only be performed against systems
and targets authorised for the CITS3006 project.
