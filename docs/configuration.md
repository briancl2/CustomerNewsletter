# Configuration

The required personalization surface is `config/profile.yaml`.

## Schema

- `curator.name`
- `curator.voice`
- `audience.primary_roles`
- `audience.secondary_roles`
- `audience.industries`
- `time.timezone`
- `publishing.archive_url`
- `links.youtube_playlists` (list of `{label, url}`)
- `links.copilot_fridays_catalog_url`
- `sections.optional.personal_corner.enabled`
- `sections.optional.personal_corner.title`

## First Edits to Make

1. Update `curator.name` and `curator.voice`.
2. Adjust audience roles and industries.
3. Set your newsletter archive URL.
4. Replace playlist links with your own curation assets.
5. Decide whether to enable `personal_corner`.

## Wiring in the System

This profile is explicitly read by:
- `.github/agents/customer_newsletter.agent.md`
- `.github/skills/newsletter-assembly/SKILL.md`
- `.github/skills/events-extraction/SKILL.md`
