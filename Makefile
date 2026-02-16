.PHONY: help validate-structure validate-skill validate-all-skills

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

validate-structure: ## Verify all required files and directories exist
	@echo "Validating repo structure..."
	@errors=0; \
	for f in .github/agents/customer_newsletter.agent.md \
		AGENTS.md \
		.github/prompts/README.md \
		.github/prompts/run_pipeline.prompt.md \
		.github/skills/editorial-review/SKILL.md \
		reference/editorial-intelligence.md \
		reference/github_common_jargon.md \
		reference/public_repo_guide.md \
		README.md Makefile .gitignore; do \
		if [ ! -f "$$f" ]; then echo "MISSING: $$f"; errors=$$((errors + 1)); fi; \
	done; \
	for d in archive/2024 archive/2025 workspace/archived output; do \
		if [ ! -d "$$d" ]; then echo "MISSING DIR: $$d"; errors=$$((errors + 1)); fi; \
	done; \
	prompt_count=$$(find .github/prompts -name "phase_*.prompt.md" 2>/dev/null | wc -l | tr -d ' '); \
	if [ "$$prompt_count" -ne 6 ]; then echo "WRONG COUNT: prompts ($$prompt_count != 6)"; errors=$$((errors + 1)); fi; \
	if [ "$$errors" -eq 0 ]; then echo "✅ All structure checks passed"; else echo "❌ $$errors check(s) failed"; exit 1; fi

validate-skill: ## Validate a skill directory (SKILL=.github/skills/skill-name)
	@if [ -z "$(SKILL)" ]; then echo "Usage: make validate-skill SKILL=.github/skills/skill-name"; exit 1; fi
	@python3 tools/validate_skill.py $(SKILL)

validate-all-skills: ## Validate all skills
	@errors=0; \
	for d in .github/skills/*/; do \
		if python3 tools/validate_skill.py "$$d" 2>/dev/null; then \
			true; \
		else \
			errors=$$((errors + 1)); \
		fi; \
	done; \
	if [ "$$errors" -eq 0 ]; then echo "✅ All skills passed validation"; else echo "❌ $$errors skill(s) failed"; exit 1; fi

validate-fleet: ## Validate fleet skill-building output (run after fleet completes)
	@bash tools/validate_fleet_output.sh

score-structural: ## Run Layer 1 structural rubric scoring
	@bash tools/score-structural.sh

score-heuristic: ## Run Layer 2 heuristic quality scoring (gate: structural must pass first)
	@bash tools/score-heuristic.sh

score-all: ## Run all scoring layers in order (cheapest first)
	@bash tools/score-structural.sh && bash tools/score-heuristic.sh

build-preflight: ## Phase 0: Pre-flight checks (env, learnings, hypotheses)
	@bash tools/run_build.sh preflight

build-fleet: ## Phase 1: Fleet parallel skill building (8 sub-agents)
	@bash tools/run_build.sh fleet

build-score: ## Phase 2: Layered scoring (structural then heuristic)
	@bash tools/run_build.sh score

build-test: ## Phase 3: Sequential benchmark testing per skill
	@bash tools/run_build.sh test

build-rework: ## Phase 4: Diagnose weakest, fix one thing, re-measure (max 5 cycles)
	@bash tools/run_build.sh rework

build-refactor: ## Phase 5: Slim agent from 455 to ~150 lines
	@bash tools/run_build.sh refactor

build-ship: ## Phase 6: Multi-layer ship gate
	@bash tools/run_build.sh ship

build-all: ## Run full loop: preflight -> fleet -> score -> [rework] -> test -> refactor -> ship
	@bash tools/run_build.sh all

editorial-analyze: ## Phase A: Structural analysis of all 14 newsletters (free, deterministic)
	@bash tools/run_editorial_intel.sh analyze

editorial-mine: ## Phase B+C: Fleet parallel editorial mining (6 LLM agents)
	@bash tools/run_editorial_intel.sh mine

editorial-synthesize: ## Phase D: Synthesize findings into skills and references
	@bash tools/run_editorial_intel.sh synthesize

editorial-all: ## Run full editorial intelligence pipeline (analyze -> mine -> synthesize)
	@bash tools/run_editorial_intel.sh all

score-selection: ## Score selection quality: compare skill output vs benchmark (SKILL_OUT= BENCH=)
	@if [ -z "$(SKILL_OUT)" ] || [ -z "$(BENCH)" ]; then echo "Usage: make score-selection SKILL_OUT=path BENCH=path"; exit 1; fi
	@bash tools/score-selection.sh $(SKILL_OUT) $(BENCH)

validate-newsletter: ## Validate a newsletter file (FILE=path/to/newsletter.md)
	@if [ -z "$(FILE)" ]; then echo "Usage: make validate-newsletter FILE=output/newsletter.md"; exit 1; fi
	@bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh $(FILE)

validate-kb: ## Run kb link health check (dry-run)
	@python3 .github/skills/kb-maintenance/scripts/check_link_health.py --dry-run

kb-poll: ## Poll sources for new content (dry-run)
	@python3 .github/skills/kb-maintenance/scripts/poll_sources.py --dry-run

newsletter: ## Generate newsletter pipeline (START= END= EVENTS= BENCHMARK_MODE=optional)
	@if [ -z "$(START)" ] || [ -z "$(END)" ]; then echo "Usage: make newsletter START=YYYY-MM-DD END=YYYY-MM-DD [EVENTS=path]"; exit 1; fi
	@STRICT=$${STRICT:-1} BENCHMARK_MODE="$(BENCHMARK_MODE)" bash tools/run_newsletter.sh $(START) $(END) $(EVENTS)

newsletter-prepare: ## Prepare cycle marker (START= END= NO_REUSE=1 optional)
	@if [ -z "$(START)" ] || [ -z "$(END)" ]; then echo "Usage: make newsletter-prepare START=YYYY-MM-DD END=YYYY-MM-DD [NO_REUSE=1]"; exit 1; fi
	@if [ "$(NO_REUSE)" = "1" ]; then \
		bash tools/prepare_newsletter_cycle.sh $(START) $(END) --no-reuse; \
	else \
		bash tools/prepare_newsletter_cycle.sh $(START) $(END); \
	fi

newsletter-validate-strict: ## Strict contract validation (START= END= REQUIRE_FRESH=1 optional BENCHMARK_MODE=optional)
	@if [ -z "$(START)" ] || [ -z "$(END)" ]; then echo "Usage: make newsletter-validate-strict START=YYYY-MM-DD END=YYYY-MM-DD [REQUIRE_FRESH=1] [BENCHMARK_MODE=mode]"; exit 1; fi
	@if [ "$(REQUIRE_FRESH)" = "1" ]; then \
		if [ -n "$(BENCHMARK_MODE)" ]; then \
			bash tools/validate_pipeline_strict.sh $(START) $(END) --require-fresh --benchmark-mode $(BENCHMARK_MODE); \
		else \
			bash tools/validate_pipeline_strict.sh $(START) $(END) --require-fresh; \
		fi; \
	else \
		if [ -n "$(BENCHMARK_MODE)" ]; then \
			bash tools/validate_pipeline_strict.sh $(START) $(END) --benchmark-mode $(BENCHMARK_MODE); \
		else \
			bash tools/validate_pipeline_strict.sh $(START) $(END); \
		fi; \
	fi

newsletter-validate-benchmark: ## Strict benchmark-mode validation (START= END= MODE=, REQUIRE_FRESH=1 optional)
	@if [ -z "$(START)" ] || [ -z "$(END)" ] || [ -z "$(MODE)" ]; then echo "Usage: make newsletter-validate-benchmark START=YYYY-MM-DD END=YYYY-MM-DD MODE=feb2026_consistency [REQUIRE_FRESH=1]"; exit 1; fi
	@if [ "$(REQUIRE_FRESH)" = "1" ]; then \
		bash tools/validate_pipeline_strict.sh $(START) $(END) --require-fresh --benchmark-mode $(MODE); \
	else \
		bash tools/validate_pipeline_strict.sh $(START) $(END) --benchmark-mode $(MODE); \
	fi

newsletter-fresh: ## Prepare no-reuse cycle, then run newsletter with strict gate (START= END= EVENTS=)
	@if [ -z "$(START)" ] || [ -z "$(END)" ]; then echo "Usage: make newsletter-fresh START=YYYY-MM-DD END=YYYY-MM-DD [EVENTS=path]"; exit 1; fi
	@bash tools/prepare_newsletter_cycle.sh $(START) $(END) --no-reuse
	@STRICT=$${STRICT:-1} bash tools/run_newsletter.sh $(START) $(END) $(EVENTS)

newsletter-orchestrated: ## Controlled phase-by-phase run with explicit agent delegation (START= END= MODEL= BENCHMARK_MODE= NO_REUSE=1)
	@if [ -z "$(START)" ] || [ -z "$(END)" ]; then echo "Usage: make newsletter-orchestrated START=YYYY-MM-DD END=YYYY-MM-DD [MODEL=claude-opus-4.6] [BENCHMARK_MODE=feb2026_consistency] [NO_REUSE=1]"; exit 1; fi
	@MODEL="$${MODEL:-$(MODEL)}" BENCHMARK_MODE="$${BENCHMARK_MODE:-$(BENCHMARK_MODE)}" NO_REUSE="$${NO_REUSE:-$(NO_REUSE)}" bash tools/run_newsletter_orchestrated.sh $(START) $(END)

test-archive: ## Run archive_workspace.sh test suite
	@bash tools/test_archive_workspace.sh

test-validator: ## Run newsletter validator self-test (known-good + known-bad)
	@bash tools/test_validator.sh

test-benchmark: ## Run multi-cycle benchmark regression (Dec, Aug, Jun)
	@bash tools/test_benchmark_regression.sh

test-all: ## Run ALL test suites (structure, unit, scoring, benchmark)
	@bash tools/test_all.sh

check-intel-sync: ## Check intelligence file propagation across all surfaces
	@bash tools/check_intelligence_sync.sh

test-intel-effectiveness: ## Test intelligence gap encoding effectiveness (target >=30%)
	@bash tools/test_intelligence_effectiveness.sh

test-polishing: ## Test polishing rules and benchmark data
	@bash tools/test_polishing_rules.sh


## Archive VS Code and CLI session logs (uses new SLM skill)
archive-sessions: ## Copy VS Code + CLI session logs to runs/sessions/
	@bash .github/skills/session-log-manager/scripts/session-archive.sh --repo briancl2-customer-newsletter

## Scan session stores, report sizes, flag hotspots
session-health: ## Session log health check
	@bash .github/skills/session-log-manager/scripts/session-health-check.sh

## Archive sessions for a specific repo (REPO=name)
session-archive: ## Archive sessions (REPO=briancl2-customer-newsletter)
	@bash .github/skills/session-log-manager/scripts/session-archive.sh --repo $(REPO)

## Compress archived sessions older than 7 days
session-rotate: ## Rotate and compress old session archives
	@bash .github/skills/session-log-manager/scripts/session-rotate.sh
