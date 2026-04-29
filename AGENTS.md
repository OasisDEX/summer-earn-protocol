# Agents

This file references skills and knowledge available to AI agents working on this repository.

## Skills

Skills are structured guides that encode domain-specific rules, patterns, and gotchas for common development tasks in this codebase.

### Ark Development

**Path**: [`summer-earn-protocol/packages/skills/ark-development/SKILL.md`](packages/skills/ark-development/SKILL.md)

Comprehensive guide for implementing new Ark contracts. Covers:

- Architecture decision (sync vs async, ERC4626 vs custom)
- Required overrides and implementation rules
- Gotchas: fork test setup order, diamond inheritance, decimal scaling, fee estimation
- Code style and file organization conventions
- Testing patterns and minimum test cases
- Reference implementations for each Ark pattern

### Protocol Deployments

**Path**: [`summer-earn-protocol/packages/skills/deployment/SKILL.md`](packages/skills/deployment/SKILL.md)

Guide for adding new Arks and protocols to the deployment system using Hardhat Ignition and interactive scripts.
