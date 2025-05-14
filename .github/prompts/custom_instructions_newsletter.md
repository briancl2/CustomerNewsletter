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
  - **Embed links within text** for a clean layout, using either style:
    - **Bracket style**: `[[Descriptive Link Text]](URL)` at the end of a bullet point
    - **Inline style**: `[link text](URL)` embedded directly within the text for grouped minor updates
  - Avoid raw URLs.

---

## Mandatory Sections & Content

### 1. Copilot Updates
This section is critical and should almost always be present.
- **Feature Release Type**: Clearly label features as `(GA)` for Generally Available or `(PREVIEW)` for all other pre-release stages (Beta, Experimental, Private Preview, etc.). If the release type is unclear, do not associate one.
- **Feature Hierarchy**:
  - When a feature has both `GA` and `PREVIEW` components, **always include both**, with GA mentioned first
  - Never drop GA information when including a related Preview update
  - Example: `**Copilot Code Review Language Expansion** – Copilot Code Review is now generally available for C, C++, Kotlin, and Swift (`GA`), while support for remaining programming languages is available in public preview (`PREVIEW`). - [[GA Announcement]](URL) [[Preview Announcement]](URL)`
- **IDE Feature Updates**:
  - Follow the standard IDE update pattern in announcements: features generally start in VS Code (usually in Preview), then move to Visual Studio and JetBrains, followed by other IDEs (Eclipse, Xcode)
  - Highlight the most impactful IDE update in a dedicated bullet with complete details
  - Group minor IDE updates in a single "Other IDE Updates" bullet with inline links
  - Include this explanatory format when introducing major IDE parity updates:
    ```markdown
    -   **Improved IDE Feature Parity** 
        - **Visual Studio 17.14 Major Update** – Agent mode, Model Context Protocol (MCP) support, and Next Edit Suggestions now available in Visual Studio. - [[Announcement]](URL)
        - **Other IDE Updates** – JetBrains adds [multi-file editing capabilities](URL), Eclipse now has full [Copilot Chat with model picker](URL), and Xcode gains [`@workspace` context support](URL)
    ```
- **Sub-sections (always include, with rare exceptions):**
  - **Latest Releases**: New Copilot features, functionalities, and significant updates.
  - **Copilot at Scale**: Content focused on enterprise adoption, metrics, measuring impact, training strategies, and best practices for large organizations. This section will usually contain training and metrics content. It should also include the standard changelog links (see below).
- **Section Grouping**:
  - Create a dedicated subsection when a significant update requires multiple related bullet points (e.g., "Premium Model Quotas Delayed to June 4")
  - Group thematically related updates under descriptive headers
  - Use standard bullets for standalone updates
- Additional Copilot-related sub-sections can be added if relevant for a particular month. Note: Additional thematic sub-sections (e.g., 'Premium Model Usage Controls') can be created within 'Copilot Updates' if the month's news contains a distinct, significant topic that warrants its own heading. Raw notes should ideally indicate such a grouping.
- **Content Format for Announcements**:
  Use a format similar to:
  ```markdown
  -   **[Product Name/Feature Headline] (`GA`)** – {{One or two sentences describing the release, tailored for leadership/DevOps admin audience.}} - [[Descriptive Link Text 1]](URL1) [[Descriptive Link Text 2]](URL2)
  ```
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
    - [Eclipse Copilot Changelog](https://marketplace.eclipse.org/content/github-copilot#details)
    ```

### 2. Webinars, Events, and Recordings
A curated list of relevant upcoming engagements and links to recordings of past events if available.
- **Standard Content (include if relevant for the month):**
    `Also, watch the [Copilot Fridays back catalog](https://resources.github.com/copilot-fridays-english-on-demand/): Prompt Fundamentals, Copilot for MLOps/Data Science, Copilot for Infrastructure Engineers, GitHub Enterprise Managed Users for Copilot Users`
- **Format for Conference Events**:
  For major conferences like Microsoft Build or GitHub Galaxy, use tables with columns for Date, Time, Session, Description, and optionally Speakers:
  ```markdown
  #### Keynotes
  | Date | Time (PDT) | Session | Speakers | Description |
  |------|------------|---------|----------|-------------|
  | May 19 | 9:05 AM - 10:30 AM | [**Session Title**](URL) | Speaker Names | Brief description |

  #### Topic Sessions
  | Date | Time (PDT) | Session | Description |
  |------|------------|---------|----------|
  | May 19 | 11:45 AM - 12:45 PM | [**Session Title**](URL) | Brief description |
  ```

- **Format for Virtual Events**:
  For all virtual events, strictly use the following table format with focused category labels:
  ```markdown
  | Date | Event | Categories |
  |------|-------|-----------|
  | May 22 | [Event Title](URL) | Copilot for Security, Beginner |
  ```
  
  For the Categories column:
  - Generally use 1-3 specific, confident category labels per event
  - For skill level, use only "Introductory" or "Advanced" when clearly applicable; omit skill level if neither applies
  - Be conservative in labeling - only use categories you can confidently determine from the event title or description
  - Use specific GitHub-related terms, abbreviations, and product names rather than generic concepts
  - Categories should be drawn from the following (though not limited to):
    - Copilot (or Copilot for [Specific Role] if clearly indicated)
    - Copilot Roadmap (for forward-looking Copilot features/releases)
    - GHAS or GitHub Advanced Security
    - Dependabot
    - Actions
    - ADO (Azure DevOps)
    - GHE (GitHub Enterprise)
    - Platform (for enterprise infrastructure topics)
    - Enterprise Administration
    - DevOps Integration
    - Supply Chain Security
    - Security (when security is a focus but not specifically GHAS)
    - Product Roadmap
    - Compliance
    - Developer Productivity
  
  When considering categories (though this information is for Copilot's guidance only and won't appear in the table), keep in mind the target audience:
  - Platform Engineers
  - DevSecOps Teams
  - Engineering Managers
  - Developers
  - DevOps Engineers
  - Security Teams
  - IT Leadership
  - Enterprise Administrators

- **Format for In-person Events**:
  For in-person events, use bullet points with location:
  ```markdown
  * City, State - **Month Day** - [Event Name](URL)
    Brief description (1 sentence, optional)
  ```

### 3. Dylan's Corner (Mandatory)
A specialized section written from Dylan's perspective with a "Did You Know?" format that focuses on specialized Copilot features, legal/compliance aspects, or unique use cases that customers may not be aware of. This section should:
- Use a conversational tone that's different from the rest of the newsletter
- Focus on one specific topic per newsletter
- Include links to relevant documentation
- Typically follow this format:
  ```markdown
  # Dylan's Corner

  ### Did You Know?
  {{A paragraph or two about a specialized Copilot feature, legal/compliance aspect, or unique use case}}

  {{Optional second paragraph with more details, examples, or benefits}}

  📚 Learn more: [Link Description 1](URL) | [Link Description 2](URL)
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
2.  **Feature Type Priority**:
    -   **GA features** over preview features when both exist
    -   **IDE feature parity updates** following this pattern: VS Code → Visual Studio → JetBrains → other IDEs (Eclipse, Xcode)
    -   **Administration, governance, and management features**
    -   **Metrics and tools that measure product impact**
    -   **Security, compliance, and risk management**
    -   Then Codebases/Packages/Actions/GHAS features as applicable
3.  **Relevance to Audience**:
    -   Features that appeal to Engineering Managers, DevOps Leads, IT Leadership, and Developers in large, regulated industries.
    -   **Note**: Enterprise customers cannot use Copilot Free/Individual/Pro/Pro+, so avoid mentioning these plans
4.  **Feature Maturity**:
    -   Prioritize `(GA)` features.
    -   Include `(PREVIEW)` features (which encompasses Beta, Experimental, etc.) if they are impactful and relevant, ensuring they are clearly labeled. The goal is to capture customer attention with exciting developments while managing expectations about feature maturity.
5.  **Information Density**:
    -   Emphasize major updates with detailed bullets
    -   Group minor related updates with inline links for conciseness
    -   Create dedicated subsections only for significant topics that require multiple bullets
    -   Balance detail with brevity to maintain readability

Each newsletter should balance:
- **New launches** (product updates, roadmap highlights).
- **Metrics & best practices** (ways to measure success, often in "Copilot at Scale").
- **Learning resources** (training materials, certifications, often in "Copilot at Scale" or a dedicated section).
- **Upcoming events** (webinars, conferences, workshops).

---

## Tone & Style
- **Professional but conversational**: Write clearly but with a natural, engaging tone.
- **Maintain a consistent style** across all issues.
- **Personalized for my audience**: Reinforce that the newsletter is specifically curated for large enterprise customers in regulated industries.
- **Strictly avoid em dashes (—)**. Use commas, parentheses, or rephrase the sentence.
- **Use consistent GitHub terminology**: Refer to the `/Reference/GitHub_Common_Jargon.md` file for standard GitHub terminology, product names, and industry-specific language to ensure consistency and authenticity. This helps ground the newsletter in GitHub's ecosystem and makes it resonate with both technical and leadership audiences.

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
