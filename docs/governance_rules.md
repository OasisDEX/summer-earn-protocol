Overview

SIP0 establishes the governance process for Lazy Summer Protocol, providing a structured framework for community participation, proposal submission, and decision-making. This process ensures that all proposed changes are thoroughly vetted and receive broad community support before implementation.

Motivation

A well-defined governance process is essential for effective decision-making and community engagement. By establishing clear procedures for submitting and approving Summer Improvement Proposals (SIPs), SIP0 empowers token holders and protects the protocol’s integrity, ensuring transparency and accountability.

Proposal Stages
1. Idea Submission (Lazy Summer Protocol Forum)
Community members post their ideas in the Lazy Summer Forum for initial feedback.
Posts should include the following details:
Background: Context and relevance of the idea.
Problem Statement: The issue the proposal addresses.
Potential Solution: A brief description of the proposed change.
2. Request for Comments (RFC) Phase
After idea submission, the proposal enters a minimum 3-day RFC period in the forum.
The goal is to refine the idea based on community feedback.
RFCs must be clearly labeled and structured for easier discussion.
The proposer integrates insights from the discussion to improve clarity and feasibility.
3. SIP Submission
Requirements for submission:
The SIP must have all the necessary details (e.g., Summary, Motivation, Specifications).
4. On-Chain Voting
SIPs undergo a 4-day on-chain voting period, during which token holders vote “Yes” or “No.”
The proposer must hold or be delegated at least 10,000 $SUMR tokens.
Voting requirements:
The quorum is defined as 35% of the actively delegated token supply at the time of the vote.
Passing Threshold: Over 50% of votes cast must be in favor for the proposal to pass (abstentions do not count toward the total).
5. Execution
Approved SIPs enter a TimeLock contract with a 2-day waiting period before automatic execution.
The TimeLock allows time for community review or emergency action if unforeseen issues arise.
Rejected Proposals

• If a SIP fails to meet quorum or does not receive enough votes to pass, it is considered rejected.

• Rejected proposals may be resubmitted after revisions, incorporating community feedback from the previous vote.

• A resubmitted proposal should include a summary of changes made based on past discussions.

Naming Convention
Sub-numbering System for Unique SIP Identification
Overview
The sub-numbering system introduces a structured way to uniquely identify Summer Improvement Proposals (SIPs) within the same topic. By appending sub-numbers to the primary SIP number, this system ensures clarity and scalability while maintaining an intuitive format for users to follow.

Format
The naming convention for SIPs will be:

SIP[Primary Number].[Sub-number]

• Primary Number (SIP[Number]): Represents the main topic category of the proposal. Each number corresponds to a specific category of governance activity (e.g., Vault Onboarding, ARK Onboarding).

• Sub-number ([.Sub-number]): Sequentially identifies individual proposals within the same topic, ensuring unique identifiers for every SIP.

How It Works
The sub-numbering system operates as follows:

1. Assignment

Each new proposal within a category receives:

• The next available sub-number to ensure chronological tracking within that topic.

• Sub-numbers are independent across primary categories. For example, SIP1.1 and SIP2.1 are unrelated, as they belong to different topics.

2. Reference

Proposals are referenced using their complete identifier (e.g., SIP1.2, SIP2.1). This ensures discussions and archives are clear and clear when multiple proposals fall under the same primary number.

Advantages
Clarity: Proposals within the same category are clearly distinguished, avoiding ambiguity in discussions and documentation.
Scalability: As the protocol grows, the system accommodates unlimited proposals within each topic.
Consistency: A standardized format makes proposals easy to reference, track, and organize.
Searchability: Users can quickly locate related proposals by searching for the primary SIP number (e.g., all SIP1 proposals).
Examples

• SIP1.1: Proposal to deploy USDC Fleet on Mainnet
• SIP1.2: Proposal to adjust Fleet deposit cap parameters

• SIP2.1: Proposal to add ARKs to an existing Fleet
• SIP2.2: Proposal to remove underperforming ARKs from a Fleet

• SIP3.2: Proposal to add $SUMR rewards to XYZ Fleet.

Proposed Categories
SIP0 - Governance Process
SIP1 - Vault/Fleet Management (Onboarding & Offboarding)
    - Includes Fleet deployment, configuration changes, and vault-level operational decisions
SIP2 - ARK Management (Onboarding & Offboarding)
    - Includes adding/removing ARKs to existing Fleets and ARK-specific configurations
SIP3 - Token Rewards
SIP4 - Governance Parameters
SIP5 - Special Governance Votes (One-Off Proposals)
Process to Add More SIP Categories
As the protocol evolves, new categories and templates for Summer Improvement Proposals (SIPs) may be required to accommodate additional governance needs. Here’s a structured process for defining and integrating new SIP categories and templates.

1. Identify the Need for a New SIP Category

• Trigger Events:

• A community member submits a proposal that doesn’t fit existing categories.

• A governance discussion identifies a new area of focus.

• Expansion of protocol functionality (e.g., new products or integrations) necessitates unique proposal types.

• Proposal Analysis:

• Determine if the new proposal type is recurring or a one-off. For recurring cases, a new SIP category is warranted.

• Assess if the new category overlaps significantly with existing ones. If so, modify or expand the scope of the current category instead.

2. Submit a Governance Proposal to Add a New SIP Category

• Follow the standard governance process to propose a new SIP category:

• Title: Propose a new SIP category name, description and template.

• Motivation: Explain why the new category is necessary and how it aligns with protocol needs.

• Template Structure: Provide a draft template for the proposed category, ensuring it includes all relevant sections (e.g., Summary, Abstract, Specifications).

3. Approval and Documentation

• Community Feedback:

• Present the proposal in the governance forum for feedback and refinement.

• Voting:

• If the proposal gains sufficient community support, move it to the voting stage. If the necessity (or not) of the new SIP template is too obvious, this can be a simple Yes/No in the proposal.

• Documentation Update:

• Upon approval, update the governance documentation to include the new SIP category.

• Clearly list the new SIP category in the Naming Convention section.

4. Integrate the New SIP Category

• Assign a new Primary Number to the category:

• Example: If the last category was SIP5 (Protocol Fee Adjustments), the new category becomes SIP6.

• Provide examples for the new category in the documentation to help proposers understand its scope and application.

5. Monitor and Evolve

• Review Usage:

• Track how frequently the new category is used to ensure it fulfills its intended purpose.

• Collect community feedback on whether the category and template require adjustments.

• Periodic Updates:

• Conduct periodic reviews of all SIP categories and templates to ensure they remain relevant.

• Merge, split, or modify categories as the protocol grows.