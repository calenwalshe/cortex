# Cortex Layer 3: Forcing Questions Framework

> Extracted from: upstream/gstack/office-hours/SKILL.md.tmpl (lines 152-235)
> Upstream version: v0.12.12.0 (11695e3)
> Adapted for: Cortex thinking layer

## Activation

These questions activate during **ideation, planning, and product discussions** —
when evaluating whether something is worth building, or how to scope it.
They enhance `/gsd:discuss-phase` and any brainstorming conversation.

## The Six Forcing Questions

Ask these ONE AT A TIME. Push on each one until the answer is specific,
evidence-based, and uncomfortable.

### Q1: Demand Reality
"What's the strongest evidence you have that someone actually wants this —
not 'is interested,' not 'signed up for a waitlist,' but would be genuinely
upset if it disappeared tomorrow?"

**Push until you hear:** Specific behavior. Someone paying. Someone expanding
usage. Someone who would have to scramble if you vanished.

**Red flags:** "People say it's interesting." "We got waitlist signups."
"VCs are excited about the space." None of these are demand.

### Q2: Status Quo
"What are your users doing right now to solve this problem — even badly?
What does that workaround cost them?"

**Push until you hear:** A specific workflow. Hours spent. Dollars wasted.
Tools duct-taped together. People hired to do it manually.

**Red flags:** "Nothing — there's no solution." If truly nothing exists
and no one is doing anything, the problem probably isn't painful enough.

### Q3: Desperate Specificity
"Name the actual human who needs this most. What's their title? What gets
them promoted? What gets them fired?"

**Push until you hear:** A name. A role. A specific consequence they face
if the problem isn't solved.

**Red flags:** Category-level answers. "Healthcare enterprises." "SMBs."
"Marketing teams." These are filters, not people.

### Q4: Narrowest Wedge
"What's the smallest possible version that someone would pay real money for —
this week, not after you build the platform?"

**Push until you hear:** One feature. One workflow. Something shippable in
days, not months, that someone would pay for.

**Red flags:** "We need the full platform first." "It wouldn't be
differentiated." Signs of attachment to architecture over value.

### Q5: Observation & Surprise
"Have you actually sat down and watched someone use this without helping them?
What did they do that surprised you?"

**Push until you hear:** A specific surprise. Something the user did that
contradicted assumptions.

**Red flags:** "We sent out a survey." "We did demo calls." "Nothing surprising."
Surveys lie. Demos are theater. "As expected" means filtered assumptions.

### Q6: Future-Fit
"If the world looks meaningfully different in 3 years — and it will — does
your product become more essential or less?"

**Push until you hear:** A specific claim about how their users' world changes
and why that makes the product more valuable.

**Red flags:** "The market is growing 20%." Growth rate is not a vision.

## Smart Routing

Not every conversation needs all six questions:

| Stage | Ask These |
|-------|-----------|
| Idea stage (no users) | Q1, Q2, Q3 |
| Has users (not paying) | Q2, Q4, Q5 |
| Has paying customers | Q4, Q5, Q6 |
| Pure engineering/infra | Q2, Q4 only |

## Integration with GSD

These questions enhance `/gsd:discuss-phase` — they don't replace it.
When GSD gathers context for a phase, these questions ensure the context
is grounded in reality, not assumptions.
