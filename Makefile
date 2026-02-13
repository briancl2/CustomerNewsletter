.PHONY: help validate-structure validate-skill validate-all-skills

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

validate-structure: ## Verify all required files and directories exist
	@echo "Validating repo structure..."
	@errors=0; \
	for f in .github/agents/customer_newsletter.agent.md \
		AGENTS.md \
		.github/copilot-instructions.md \
		.github/prompts/README.md \
		.github/prompts/run_pipeline.prompt.md \
		.github/skills/editorial-review/SKILL.md \
		reference/editorial-intelligence.md \
		reference/github_common_jargon.md \
		reference/public_repo_guide.md \
		config/profile.yaml \
		docs/index.md \
		docs/quickstart.md \
		docs/how-it-works.md \
		docs/architecture.md \
		docs/configuration.md \
		docs/reports/newsletter_system_report_2026-02.md \
		docs/reports/newsletter_system_report_2026-02_context.md \
		docs/legacy/README.md \
		docs/how-we-maintain-this.md \
		mkdocs.yml \
		README.md Makefile .gitignore requirements.txt; do \
		if [ ! -f "$$f" ]; then echo "MISSING: $$f"; errors=$$((errors + 1)); fi; \
	done; \
	for d in archive/2024 archive/2025 workspace output docs docs/reports config legacy legacy/2026-02_pre-overhaul; do \
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

newsletter: ## Generate newsletter pipeline (START= END= EVENTS=)
	@if [ -z "$(START)" ] || [ -z "$(END)" ]; then echo "Usage: make newsletter START=YYYY-MM-DD END=YYYY-MM-DD [EVENTS=path]"; exit 1; fi
	@bash tools/run_newsletter.sh $(START) $(END) $(EVENTS)

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

## Code review staged changes via Copilot CLI
review:
	@bash .github/skills/reviewing-code-locally/scripts/local_review.sh

## Archive VS Code and CLI session logs
archive-sessions: ## Copy VS Code + CLI session logs to runs/sessions/
	@bash tools/archive_sessions.sh
