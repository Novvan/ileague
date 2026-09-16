# contracts/fixtures

Golden JSON fixtures shared by the TypeScript (Nitro/`services/back-office`, `services/scheduling-engine`) and Dart (`services/player-app`) sides of the codebase. A contract-test suite on both sides parses the same fixtures and asserts agreement — this is what "TS↔Dart contract sync" actually means (not just "both exist," but "both interpret the same bytes the same way"). CI fails on divergence. See `implementationPlan/02-contracts-domain-model.md`, E2-T5.
