## Purpose
This newsletter is personally curated for my customers to provide updates on **new launches, features, metrics, learning resources, and upcoming events**. It helps scale engagement by keeping customers informed on key developments, even when I can’t meet with them individually. The primary goals are:
- **Awareness**: Keeping customers up to date with recent product updates and industry trends relevant to large enterprises, particularly in Healthcare and Manufacturing.
- **Engagement**: Encouraging interaction and discussion on relevant topics.
- **Education**: Providing learning resources to help customers maximize value from GitHub products.
- **Event Registration**: Promoting webinars, conferences, and training sessions.
- **Scalable Customer Touchpoint**: Provide a consistent, valuable touchpoint each month, especially for customers with whom direct engagement time is limited. Many customers also leverage this content by copying and pasting resources, updates, and event links into their internal developer community portals and newsletters.

---

## Audience Focus
- **Primary Audience**: Engineering Managers, DevOps Leads, and IT Leadership within large, regulated enterprises (Healthcare, Manufacturing).
- **Secondary Audience**: Developers. Content should appeal to both, but the distribution list primarily consists of leadership and platform engineering roles.

---

## Standard Introduction & Closing

**Introduction Template:**
"This is a personally curated newsletter for my customers, focused on the most relevant updates and resources from GitHub this month. Highlights for this month include [Placeholder for 2-3 key highlights]. If you have any feedback or want to dive deeper into any topic, please let me know. Feel free to share this newsletter with others on your team as well. You can find an archive of past newsletters [here](https://github.com/briancl2/CustomerNewsletter)."

**Closing Template:**
"If you have any questions or want to discuss these updates in detail, feel free to reach out. As always, I’m here to help you and your team stay informed and get the most value from GitHub."

---

## Structure & Formatting
- **Flexible structure overall**, but with mandatory sections.
- **Every section must have a title** (e.g., `### Copilot Updates`, `## Security News`).
- **Use Markdown formatting consistently**:
  - **Bold** important details (product names, headlines, dates).
  - Use **bullet points** (`*` or `-`) for lists of features, resources, or events for easy readability.
  - **Embed links within text** for a clean layout (e.g., `[Link Text](URL)`). Avoid raw URLs.

---

## Mandatory Sections & Content

### 1. Copilot Updates
This section is critical and should almost always be present.
- **Feature Release Type**: Clearly label features as `(GA)` for Generally Available or `(PREVIEW)` for all other pre-release stages (Beta, Experimental, Private Preview, etc.). If the release type is unclear, do not associate one.
- **Sub-sections (always include, with rare exceptions):**
    -   **Latest Releases**: New Copilot features, functionalities, and significant updates.
    -   **New Resources**: Links to new documentation, blog posts, learning paths, public repos, or tools related to Copilot.
    -   **Copilot at Scale**: Content focused on enterprise adoption, metrics, measuring impact, training strategies, and best practices for large organizations. This section will usually contain training and metrics content. It should also include the standard changelog links (see below).
- Additional Copilot-related sub-sections can be added if relevant for a particular month. Note: Additional thematic sub-sections (e.g., 'Premium Model Usage Controls') can be created within 'Copilot Updates' if the month's news contains a distinct, significant topic that warrants its own heading. Raw notes should ideally indicate such a grouping.
- **Content Format for Announcements (Latest Releases, New Resources, etc.):**
    Use a format similar to:
    `*   **[Product Name/Feature Headline] (`(GA)` or `(PREVIEW)`)** – {{One or two sentences describing the release, tailored for leadership/DevOps admin audience, but also noting developer impact if applicable. If the announcement covers multiple distinct sub-features, consider using nested bullet points under the main description for clarity.}} - [[Descriptive Link Text 1]](URL1) [[Descriptive Link Text 2]](URL2)`
    *Note on Link Text:* Link text should be descriptive of the link's destination (e.g., 'View the docs', 'Get the Plugin', 'Read the announcement').
    *Example 1 (Feature focused):*
    `*   **Agent Mode (`(GA)`)** – Copilot Agent Mode is now generally available, enabling developers to trigger multi-step tasks autonomously such as debugging and running tests. - [[Enable Agent mode in VS Code]](https://code.visualstudio.com/updates/v1_99#_agent-mode-is-available-in-vs-code-stable) [[Announcement]](https://github.blog/news-insights/product-news/github-copilot-agent-mode-activated/)`
    *Example 2 (Resource focused):*
    `*   **Copilot Adoption at Scale Guide (`(GA)`)** – An open-source guide and checklist for rolling out GitHub Copilot across an enterprise, covering best practices and onboarding. - [[GitHub Repo]](https://github.com/samqbush/copilot-adoption?tab=readme-ov-file)`
- **Standard Content for 'Copilot at Scale' (always include):**
    ```markdown
    ### Stay up to date on the latest releases
    - [GitHub Copilot Changelog](https://github.blog/changelog/label/copilot/feed/)
    - [VS Code Copilot Changelog](https://code.visualstudio.com/updates/#_github-copilot)
    - [Visual Studio Copilot Changelog](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes#github-copilot)
    - [JetBrains Copilot Changelog](https://plugins.jetbrains.com/plugin/17718-github-copilot/versions/stable)
    - [XCode Copilot Changelog](https://github.com/github/CopilotForXcode/blob/main/ReleaseNotes.md)
    ```

### 2. Webinars, Events, and Recordings
A curated list of relevant upcoming engagements and links to recordings of past events if available.
- **Standard Content (include if relevant for the month):**
    `Also, watch the [Copilot Fridays back catalog](https://resources.github.com/copilot-fridays-english-on-demand/): Prompt Fundamentals, Copilot for MLOps/Data Science, Copilot for Infrastructure Engineers, GitHub Enterprise Managed Users for Copilot Users`
- **Format for Upcoming Events:**
    ```markdown
    ### Upcoming Virtual Events
    *   **[Month Day]** – [[Event Title/Series Name]]([Link to registration/details])
    *   **[Month Day]** – [[Event Title/Series Name]]([Link to registration/details])

    ### Upcoming In-person Events
    *   [City, ST] - **[Month Day]** - [[Event Name]]([Link to event page])
    *   [City, ST] - **[Month Day]** - [[Event Name]]([Link to event page])
    ```
    *Example based on provided structure:*
    ```markdown
    ### Upcoming Virtual Events
    Also, watch the [Copilot Fridays back catalog](https://resources.github.com/copilot-fridays-english-on-demand/): Prompt Fundamentals, Copilot for MLOps/Data Science, Copilot for Infrastructure Engineers, GitHub Enterprise Managed Users for Copilot Users
    *   **Apr 15** - [[Copilot Metrics API Roadmap Webinar]](https://github.registration.goldcast.io/webinar/162b1da3-f526-4479-9f0f-4346fa29376f)
    *   **Apr 17** – Copilot Fridays: [[Level up your Prompting]](https://github.registration.goldcast.io/series/ff0939de-f20a-4395-80ff-4bc606e356fd)

    ### Upcoming In-person Events
    *   Las Vegas, NV - **Apr 9** - [[Google Next]](https://resources.github.com/events/github-at-google-cloud-next-apr2025/)
    *   Seattle, WA - **May 19** - [[Microsoft Build]](https://build.microsoft.com/en-US/home)
    ```

### Other Potential Sections (Flexible based on monthly content):
- Security Updates
- DevOps & Integrations (e.g., Azure DevOps, JFrog)
- GitHub Advanced Security (GHAS)
- GitHub Actions
- General Platform Updates
- Learning Resources (if not covered under Copilot at Scale)

---

## Content Selection Criteria
When deciding what to include:
1.  **Prioritize recency**: Focus on updates from the past month.
2.  **Relevance to Audience**:
    -   **Administration, governance, and management features**.
    -   **Metrics and tools that measure product impact**.
    -   **Security, compliance, and risk management**.
    -   Features that appeal to Engineering Managers, DevOps Leads, IT Leadership, and Developers in large, regulated industries.
3.  **Feature Maturity**:
    -   Prioritize `(GA)` features.
    -   Include `(PREVIEW)` features (which encompasses Beta, Experimental, etc.) if they are impactful and relevant, ensuring they are clearly labeled. The goal is to capture customer attention with exciting developments while managing expectations about feature maturity.

Each newsletter should balance:
- **New launches** (product updates, roadmap highlights).
- **Metrics & best practices** (ways to measure success, often in "Copilot at Scale").
- **Learning resources** (training materials, certifications, often in "Copilot at Scale" or a dedicated section).
- **Upcoming events** (webinars, conferences, workshops).

---

## Tone & Style
- **Professional but conversational**: Write clearly but with a natural, engaging tone.
- **Maintain a consistent style** across all issues.
- **Personalized for my audience**: Reinforce that the newsletter is specifically curated for them.
- **Strictly avoid em dashes (—)**. Use commas, parentheses, or rephrase the sentence.
- Avoid phrases that strongly signal AI generation (e.g., "Certainly!", "I can help with that!", "Here is the...").

---

## Call to Action (CTA)
Each newsletter should include clear CTAs:
- Encourage customers to **register for events**.
- Invite feedback and interaction (e.g., "Let me know if you’d like to discuss this in more detail," or use the standard closing).
- Provide direct links to **important resources, documentation, and blog posts**.

---

## Example Section Format (General Guidance for non-event/Copilot announcement sections)
This is a general template; specific sections like Copilot Announcements and Events have more detailed formats above.
```markdown
**[Section Title]**

**Brief introduction** (1-2 sentences summarizing the key point or theme of the section).
*   **[Item Name/Resource Title] (`(GA)` or `(PREVIEW)`)**: [Concise description of the item and its benefit/relevance to the audience.] ([Link to blog/docs/resource])
*   **[Another Item]**: [Description] ([Link])
```
