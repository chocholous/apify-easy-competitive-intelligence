# Hiring Signal Analysis

**When to use**: Infer competitor's strategic direction from hiring patterns.

## Data Gathering

```
# 1: LinkedIn job listings
call-actor: curious_coder/linkedin-jobs-scraper

# 2: Careers page (Discover first — don't guess the URL)
#    SERP query: "[competitor] careers open positions jobs"
#    The actual careers page is often on an ATS platform (Comeet, Greenhouse,
#    Lever, Workday, BambooHR) rather than [competitor-url]/careers.
#    Use SERP to find the real URL, then scrape it.
call-actor: apify/website-content-crawler  # use the discovered URL

# 3: Glassdoor — culture, salaries, internal signals
call-actor: memo23/glassdoor-scraper-ppr

# 4: Recent hiring news + external job boards
call-actor: apify/google-search-scraper
  input: { "queries": "[competitor] hiring jobs careers [current-year]\n[competitor] layoffs OR expansion [previous-year] [current-year]\nsite:indeed.com [competitor] jobs" }
```

**0 LinkedIn results = signal** (not hiring aggressively). Glassdoor compensates — reviews reveal culture/strategy even without active hiring.

## Analysis

Categorize roles by department. Hiring velocity (scaling/stable/contracting). Technology signals from JDs. Geographic expansion. Seniority mix: hiring leaders = new initiative, hiring ICs = scaling existing.
