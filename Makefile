.PHONY: help check validate-structure validate-skill validate-all-skills

check: ## Run the full repo validation battery
	@bash tools/test_all.sh

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

validate-structure: ## Verify all required files and directories exist
	@echo "Validating repo structure..."
	@errors=0; \
	for f in .github/agents/customer_newsletter.agent.md \
		.github/agents/upgrade-advisor.agent.md \
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

publish-public-snapshot: ## Publish allowlisted public-safe snapshot (PUBLIC_REPO= path, ARGS= optional)
	@if [ -z "$(PUBLIC_REPO)" ]; then echo "Usage: make publish-public-snapshot PUBLIC_REPO=/path/to/public [ARGS='--no-commit']"; exit 1; fi
	@bash tools/publish_public_snapshot.sh $(ARGS) "$(PUBLIC_REPO)"

kb-poll: ## Poll sources for new content (dry-run)
	@python3 .github/skills/kb-maintenance/scripts/poll_sources.py --dry-run

newsletter: ## Generate newsletter pipeline (START= END= EVENTS= BENCHMARK_MODE=optional)
	@if [ -z "$(START)" ] || [ -z "$(END)" ]; then echo "Usage: make newsletter START=YYYY-MM-DD END=YYYY-MM-DD [EVENTS=path]"; exit 1; fi
	@STRICT=$${STRICT:-1} BENCHMARK_MODE="$(BENCHMARK_MODE)" bash tools/run_newsletter.sh $(START) $(END) $(EVENTS)

newsletter-gen: ## Live operator path: canonical prompt-rendered Copilot CLI run (START= END= MODE=production|benchmark MODEL=gpt-5.5)
	@if [ -z "$(START)" ] || [ -z "$(END)" ]; then echo "Usage: make newsletter-gen START=YYYY-MM-DD END=YYYY-MM-DD [MODE=production|benchmark] [MODEL=gpt-5.5]"; exit 1; fi
	@COPILOT_BIN="$${COPILOT_BIN:-copilot}"; if [ "$$COPILOT_BIN" = "copilot" ]; then COPILOT_BIN="$$(command -v copilot || true)"; [ -n "$$COPILOT_BIN" ] || COPILOT_BIN=/opt/homebrew/bin/copilot; fi; "$$COPILOT_BIN" --model "$${MODEL:-gpt-5.5}" --allow-all --deny-tool agent --no-ask-user --stream off -p "$$(bash tools/render_product_run_prompt.sh $(START) $(END) $${MODE:-production})"

newsletter-proof-run: ## Live operator path: retained proof run wrapper (START= END= MODE=production|benchmark [RUN_DIR=] [SESSION_LOG=] [MODEL=] [EXPERIMENT_ID=] [RUN_CLASS=] [FIXTURE_PACK=] [SOURCE_PRUNING_POLICY=] [OUTPUT_SHAPE_POLICY=])
	@if [ -z "$(START)" ] || [ -z "$(END)" ] || [ -z "$(MODE)" ]; then echo "Usage: make newsletter-proof-run START=YYYY-MM-DD END=YYYY-MM-DD MODE=production|benchmark [RUN_DIR=path] [SESSION_LOG=path] [MODEL=gpt-5.5] [EXPERIMENT_ID=id] [RUN_CLASS=class] [FIXTURE_PACK=id] [SOURCE_PRUNING_POLICY=path] [OUTPUT_SHAPE_POLICY=path]"; exit 1; fi
	@MODEL="$${MODEL:-gpt-5.5}" EXPERIMENT_ID="$${EXPERIMENT_ID:-}" RUN_CLASS="$${RUN_CLASS:-ordinary_proof}" FIXTURE_PACK="$${FIXTURE_PACK:-}" bash tools/run_product_newsletter.sh $(START) $(END) $(MODE) $$( [ -n "$(RUN_DIR)" ] && printf '%s ' --run-dir "$(RUN_DIR)" ) $$( [ -n "$(SESSION_LOG)" ] && printf '%s ' --session-log "$(SESSION_LOG)" ) $$( [ -n "$(SOURCE_PRUNING_POLICY)" ] && printf '%s ' --source-pruning-policy "$(SOURCE_PRUNING_POLICY)" ) $$( [ -n "$(OUTPUT_SHAPE_POLICY)" ] && printf '%s ' --output-shape-policy "$(OUTPUT_SHAPE_POLICY)" )

newsletter-cost-profiler: ## Build per-run and per-phase cost ledger from retained runs ([RUN_DIR=] [OUTPUT=] [PRICING_SNAPSHOT=])
	@python3 tools/newsletter_cost_profiler.py $$( [ -n "$(RUN_DIR)" ] && printf '%s %s ' --run-dir "$(RUN_DIR)" ) $$( [ -n "$(OUTPUT)" ] && printf '%s %s ' --output "$(OUTPUT)" ) $$( [ -n "$(PRICING_SNAPSHOT)" ] && printf '%s %s ' --pricing-snapshot "$(PRICING_SNAPSHOT)" )

newsletter-hotspot-auditor: ## Rank retained run cost/token hotspots ([PROFILER_JSON=] [RUN_DIR=] [OUTPUT=] [PRICING_SNAPSHOT=])
	@python3 tools/newsletter_hotspot_auditor.py $$( [ -n "$(PROFILER_JSON)" ] && printf '%s %s ' --profiler-json "$(PROFILER_JSON)" ) $$( [ -n "$(RUN_DIR)" ] && printf '%s %s ' --run-dir "$(RUN_DIR)" ) $$( [ -n "$(OUTPUT)" ] && printf '%s %s ' --output "$(OUTPUT)" ) $$( [ -n "$(PRICING_SNAPSHOT)" ] && printf '%s %s ' --pricing-snapshot "$(PRICING_SNAPSHOT)" )

newsletter-phase-experimenter: ## Inventory, materialize, or run bounded phase experiments (COMMAND=inventory|materialize|phase4-fast|phase3-curation MANIFEST= TARGET_REPO= SURFACE_ID= optional)
	@if [ -z "$(COMMAND)" ] || [ -z "$(MANIFEST)" ]; then echo "Usage: make newsletter-phase-experimenter COMMAND=inventory|materialize|phase4-fast|phase3-curation MANIFEST=path [TARGET_REPO=path] [SURFACE_ID=id] [MODEL=gpt-5.5] [BENCHMARK_MODE=] [PHASE_TIMEOUT_SECONDS=900]"; exit 1; fi
	@python3 tools/newsletter_phase_experimenter.py $(COMMAND) --manifest "$(MANIFEST)" $$( [ -n "$(SURFACE_ID)" ] && printf '%s %s ' --surface-id "$(SURFACE_ID)" ) $$( [ -n "$(TARGET_REPO)" ] && printf '%s %s ' --target-repo "$(TARGET_REPO)" ) $$( [ -n "$(MODEL)" ] && printf '%s %s ' --model "$(MODEL)" ) $$( [ -n "$(BENCHMARK_MODE)" ] && printf '%s %s ' --benchmark-mode "$(BENCHMARK_MODE)" ) $$( [ -n "$(RUN_DIR_OVERRIDE)" ] && printf '%s %s ' --run-dir-override "$(RUN_DIR_OVERRIDE)" ) $$( [ "$(COMMAND)" = "phase3-curation" ] && [ -n "$(PHASE_TIMEOUT_SECONDS)" ] && printf '%s %s ' --phase-timeout-seconds "$(PHASE_TIMEOUT_SECONDS)" )

newsletter-render-prompt: ## Render the canonical product-run prompt (START= END= MODE=production|benchmark [SOURCE_PRUNING_POLICY=] [OUTPUT_SHAPE_POLICY=])
	@if [ -z "$(START)" ] || [ -z "$(END)" ]; then echo "Usage: make newsletter-render-prompt START=YYYY-MM-DD END=YYYY-MM-DD [MODE=production|benchmark] [SOURCE_PRUNING_POLICY=path] [OUTPUT_SHAPE_POLICY=path]"; exit 1; fi
	@bash tools/render_product_run_prompt.sh $(START) $(END) $${MODE:-production} $$( [ -n "$(SOURCE_PRUNING_POLICY)" ] && printf '%s ' --source-pruning-policy "$(SOURCE_PRUNING_POLICY)" ) $$( [ -n "$(OUTPUT_SHAPE_POLICY)" ] && printf '%s ' --output-shape-policy "$(OUTPUT_SHAPE_POLICY)" )

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

newsletter-orchestrated: ## Diagnostic-only phase-by-phase run with explicit agent delegation (START= END= MODEL= BENCHMARK_MODE= NO_REUSE=1)
	@if [ -z "$(START)" ] || [ -z "$(END)" ]; then echo "Usage: make newsletter-orchestrated START=YYYY-MM-DD END=YYYY-MM-DD [MODEL=gpt-5.5] [BENCHMARK_MODE=feb2026_consistency] [NO_REUSE=1]"; exit 1; fi
	@MODEL="$${MODEL:-$(MODEL)}" BENCHMARK_MODE="$${BENCHMARK_MODE:-$(BENCHMARK_MODE)}" NO_REUSE="$${NO_REUSE:-$(NO_REUSE)}" bash tools/run_newsletter_orchestrated.sh $(START) $(END)

newsletter-orchestrated-proof: ## Retained phase-by-phase proof run with phase token telemetry (START= END= MODE=production|benchmark [RUN_DIR=] [MODEL=] [PHASE3_STDOUT_NO_TOOLS=1])
	@if [ -z "$(START)" ] || [ -z "$(END)" ] || [ -z "$(MODE)" ]; then echo "Usage: make newsletter-orchestrated-proof START=YYYY-MM-DD END=YYYY-MM-DD MODE=production|benchmark [RUN_DIR=path] [MODEL=gpt-5.5] [PHASE3_STDOUT_NO_TOOLS=1]"; exit 1; fi
	@MODEL="$${MODEL:-gpt-5.5}" bash tools/run_instrumented_orchestrated_proof.sh $(START) $(END) $(MODE) $$( [ -n "$(RUN_DIR)" ] && printf '%s ' --run-dir "$(RUN_DIR)" )

stage16-fast: ## Stage 16 fast closure suite (bounded Phase 4-only check; no long orchestrated run)
	@bash tools/test_validator.sh
	@bash tools/test_benchmark_regression.sh
	@MODEL="$${MODEL:-$(MODEL)}" BENCHMARK_MODE="$${BENCHMARK_MODE:-feb2026_consistency}" PHASE_TIMEOUT_SECONDS="$${PHASE_TIMEOUT_SECONDS:-900}" bash tools/run_newsletter_phase4_fast.sh 2025-12-05 2026-02-13
	@bash tools/validate_pipeline_strict.sh 2025-12-05 2026-02-13 --benchmark-mode "$${BENCHMARK_MODE:-feb2026_consistency}"
	@bash .github/skills/newsletter-validation/scripts/validate_newsletter.sh output/2026-02_february_newsletter.md

test-archive: ## Run archive_workspace.sh test suite
	@bash tools/test_archive_workspace.sh

test-validator: ## Run newsletter validator self-test (known-good + known-bad)
	@bash tools/test_validator.sh

test-phase3: ## Run Phase 3 contract regression suite
	@if [ -f workspace/newsletter_phase3_working_set_2026-04-16.md ]; then \
		bash tools/test_phase3_contracts.sh; \
	else \
		echo "SKIP: Phase 3 contract tests require private April workspace fixture"; \
	fi

validate-phase3-instruction-contract: ## Validate the Phase 3 instruction/path contract
	@python3 tools/validate_phase3_instruction_contract.py

test-phase3-instruction: ## Run Phase 3 instruction/path contract regression suite
	@bash tools/test_phase3_instruction_contract.sh

test-phase-route-lock-telemetry: ## Run Phase telemetry route-lock regression suite
	@bash tools/test_phase_route_lock_telemetry.sh

backfill-receipt-order: ## Backfill receipt_order into a legacy receipt file (RECEIPTS= ARTIFACT_ROOT=)
	@if [ -z "$(RECEIPTS)" ] || [ -z "$(ARTIFACT_ROOT)" ]; then echo "Usage: make backfill-receipt-order RECEIPTS=path/to/newsletter_phase_receipts.json ARTIFACT_ROOT=path/to/artifacts"; exit 1; fi
	@python3 tools/backfill_receipt_order.py "$(RECEIPTS)" --artifact-root "$(ARTIFACT_ROOT)"

test-receipt-order-backfill: ## Run retained receipt-order backfill regression suite
	@bash tools/test_receipt_order_backfill.sh

test-product-prompt: ## Run product prompt renderer regression suite
	@bash tools/test_product_run_prompt.sh

test-product-validation: ## Run retained product validation replay suite
	@if [ -f tools/test_product_run_validation.sh ]; then \
		bash tools/test_product_run_validation.sh; \
	else \
		echo "SKIP: retained product validation requires private retained-run tooling"; \
	fi

test-product-audit: ## Run product run-audit collector suite
	@bash tools/test_product_run_audit.sh

test-product-snapshot: ## Run retained product snapshot suite
	@bash tools/test_product_run_snapshot.sh

test-source-pruning: ## Run source/candidate pruning experiment tests
	@bash tools/test_source_pruning_experiment.sh

test-phase3-compact-working-set-gate: ## Run Phase 3 compact working-set gate packet tests
	@if [ -f tools/test_phase3_compact_working_set_gate_packet.sh ]; then \
		bash tools/test_phase3_compact_working_set_gate_packet.sh; \
	else \
		echo "SKIP: Phase 3 compact working-set gate tests require private feature-flag tooling"; \
	fi

test-phase3-v2-readiness: ## Run Phase 3 V2 readiness regression tests
	@bash tools/test_phase3_v2_readiness.sh

test-cost-opt-stack: ## Run integrated cost optimization stack render tests
	@if [ -f tools/test_cost_opt_stack_orchestrator.sh ]; then \
		bash tools/test_cost_opt_stack_orchestrator.sh; \
	else \
		echo "SKIP: cost optimization stack tests require private feature-flag tooling"; \
	fi

test-current-cycle-cost-stack-inputs: ## Run current-cycle cost stack input builder tests
	@bash tools/test_current_cycle_cost_stack_inputs.sh

test-output-shape: ## Run output-shape experiment tests
	@bash tools/test_output_shape_experiment.sh

test-output-shape-amplification: ## Run output-shape amplification trace receipt tests
	@bash tools/test_output_shape_amplification_trace_receipt.sh

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
