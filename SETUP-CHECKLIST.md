# Setup Checklist

**Project:** saas202544
**Created:** 2025-11-08

---

## 🎯 Understanding Your Tools

**This guide helps you understand what needs installation vs. what's already available.**

**⚠️ IMPORTANT:** Most tools are **BUILT-IN** - you can start immediately!

---

## Phase 1: Planning & Documentation (✅ No Setup Needed)

**You can start RIGHT NOW with zero installation!**

### Built-in Tools Available

- ✅ **File operations** - Read, Write, Edit files
- ✅ **Search & find** - Glob patterns, Grep search
- ✅ **Task agents** - Explore codebase, Plan implementation
- ✅ **Web research** - WebSearch, WebFetch
- ✅ **Virtual agents** - All planning agents in CLAUDE.md

### What You Can Do

- Create roadmaps, PRDs, sprint plans
- Document technical decisions (ADRs)
- Write user stories and requirements
- Plan architecture and tech stack
- Research and compare options
- Manage todos and track progress

**No installation required for ANY of the above!**

---

## Phase 2: Ready to Code? Choose Your Tools

**Only install extensions when you're ready to write code.**

### Decision Matrix

| Your Situation | Recommended Tools | Why |
|----------------|-------------------|-----|
| **Planning only** | None (use built-ins) | Everything you need is available |
| **Solo MVP coding** | Claude Code Templates (minimal) | Best for quick development |
| **Small team coding** | Claude Code Templates + Skills | Add document processing |
| **Enterprise dev** | All three tiers | Full capabilities |
| **Framework-specific** | WSHobson + Claude Code Templates | Specialized framework help |
| **Document processing** | Claude Skills only | PDFs, Excel, Word, etc. |

---

## 🚀 Optional: Install Development Extensions

**Install these ONLY when you need them:**

### Option A: Claude Code Templates (Recommended for Development)

**What:** 163 specialized development agents and 210 commands

**When:** Ready to write code

**Install:**
```bash
# Frontend development
npx claude-code-templates@latest --agent development-team/frontend-developer

# Backend development
npx claude-code-templates@latest --agent development-team/backend-architect

# Full-stack development
npx claude-code-templates@latest --agent development-team/fullstack-developer

# Testing
npx claude-code-templates@latest --command testing/generate-tests
```

**Verify:**
```bash
# Check .claude/ directory created
ls .claude/
```

**Documentation:** See `.config/claude-code-templates-guide.md`

---

### Option B: Claude Skills (For Document Processing)

**What:** Pre-built capabilities for documents and specialized tasks

**When:** Need to process PDFs, Excel, Word documents

**Install:**
```bash
# Browse marketplace
/plugin marketplace add anthropics/skills

# Install specific skill
/plugin add xlsx       # Excel spreadsheets
/plugin add pdf        # PDF documents
/plugin add docx       # Word documents
/plugin add skill-creator  # Create custom skills
```

**Verify:**
```bash
# Check settings file
cat .claude/settings.local.json
# Look for: "Skill(xlsx)", "Skill(pdf)", etc.
```

**Documentation:** See `.config/recommended-claude-skills.md`

---

### Option C: WSHobson Agents (Framework Specialists)

**What:** Specialized agents for specific frameworks/languages

**When:** Working with specific frameworks (React, Python/FastAPI, etc.)

**Install:**
```bash
# Add marketplace
/plugin marketplace add wshobson/agents

# Install plugin
/plugin install full-stack-orchestration  # Full-stack coordination
/plugin install python-development        # Python/FastAPI specialist
/plugin install react-typescript          # React/TypeScript specialist
/plugin install database-design          # Database architecture
```

**Verify:**
```bash
# List installed plugins
/plugin list
```

**Documentation:** See `.config/wshobson-agents-guide.md`

---

### Option D: MCP Servers (External Integrations)

**What:** Connect to external services (APIs, databases, analytics)

**When:** Need integration with external tools

**Examples:**
- Socket MCP - Dependency security scanning
- Clarity MCP - Web analytics integration
- Figma MCP - Design system tokens
- Tableau MCP - BI dashboards

**Installation:** Varies by MCP server (see specific documentation)

**Documentation:** See `.config/MCP-USAGE-GUIDE.md`

---

## ✅ Verification Checklist

### Phase 1: Built-in Tools (Always Available)

- [ ] Can you use Read, Write, Edit tools? **YES (built-in)**
- [ ] Can you use Glob/Grep to search? **YES (built-in)**
- [ ] Can you use Task tool with Explore agent? **YES (built-in, no installation!)**
- [ ] Can you use WebSearch for research? **YES (built-in)**
- [ ] Can you create planning documents? **YES (built-in templates)**

**If any are "NO" - they should all be "YES"! These are built-in!**

### Phase 2: Installed Extensions (Optional)

**Check what you've installed:**

- [ ] **Claude Code Templates**
  - Verify: `.claude/` directory exists
  - Verify: Can use installed agents

- [ ] **Claude Skills**
  - Verify: `.claude/settings.local.json` shows installed skills
  - Verify: Can use `Skill(xlsx)` etc.

- [ ] **WSHobson Agents**
  - Verify: `/plugin list` shows installed plugins
  - Verify: Can invoke plugin commands

- [ ] **MCP Servers**
  - Verify: MCP server is running
  - Verify: Can connect to external services

---

## 🚨 Common Mistakes to Avoid

### ❌ Mistake #1: Thinking Task Tool Needs Installation

**WRONG:** "I need to install the Explore agent before using it"

**RIGHT:** "Task tool's Explore/Plan agents are built-in - I can use them immediately!"

**Example - Correct Usage:**
```
User: "Explore the codebase and find all API endpoints"
Claude: *Uses Task tool with subagent_type: "Explore" immediately*
```

### ❌ Mistake #2: Installing Everything Upfront

**WRONG:** Install all extensions before planning

**RIGHT:** Use built-ins for planning, install extensions when coding

**Timeline:**
- Week 1-2: Planning → Use built-ins only
- Week 3+: Coding → Install Claude Code Templates
- As needed: Documents → Install Claude Skills

### ❌ Mistake #3: Confusing Extensions with Built-ins

**Built-in (Always Available):**
- Task tool Explore agent ✅
- Task tool Plan agent ✅
- Glob/Grep tools ✅
- Virtual agents in CLAUDE.md ✅

**Requires Installation:**
- Claude Code Templates 📦
- Claude Skills (xlsx, pdf, docx) 📦
- WSHobson Agents 📦
- MCP Servers 📦

---

## 📚 Quick Reference

**See also:**
- `BUILT-IN-VS-INSTALLABLE.md` - Complete breakdown
- `_START-HERE.md` - Getting started guide
- `CLAUDE.md` - Virtual agents reference
- `.config/INTEGRATIONS.md` - Integration overview
- `.config/claude-code-templates-guide.md` - Development tools
- `.config/recommended-claude-skills.md` - Skills catalog

---

## 🎯 Your Next Steps

**Right Now (No Installation):**
1. ✅ Read `_START-HERE.md`
2. ✅ Say "help me get started" to Claude
3. ✅ Use built-in virtual agents for planning
4. ✅ Create roadmap, PRDs, sprint plans

**When Ready to Code:**
1. 📦 Install Claude Code Templates
2. 📦 Install Claude Skills (if needed for documents)
3. 📦 Install WSHobson (if framework-specific work)
4. 📦 Set up MCP servers (if external integrations needed)

**Remember:** Built-in tools handle 80% of work. Extensions are optional!

---

**Template Version:** 2.0
**Last Updated:** 2025-11-08
