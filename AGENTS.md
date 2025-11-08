# AGENTS.md

**Universal AI Agent Guide** - Compatible with OpenAI Codex CLI, Claude Code, Cursor, Google Jules, and 20+ AI coding tools.

---

## Project Overview

- **Project**: saas202544
- **Created**: 2025-11-08
- **Type**: Azure SaaS Application
- **Architecture**: Cloud-native (Azure App Service, microservices-ready)
- **Tech Stack**: Next.js 14, Node.js, Azure SQL, Azure Redis, Azure Storage
- **Multi-Tenant**: false
- **Tenant Model**: single
- **Azure Org**: vrd
- **Azure Project**: 202544
- **Primary Region**: eus2
- **Secondary Region**: wus2
- **Purpose**: [Add 1-sentence description of what this project does]

**Azure Resources**: See `technical/azure-naming-standard.md` and `CLAUDE.md` for Azure-specific configuration.

---

## Dev Environment

### Setup
```bash
# Install dependencies
pnpm install

# Copy environment variables
cp .env.example .env.local

# Start development server
pnpm dev
```

### Prerequisites
- Node.js 18+ (or specify your version)
- Package manager: pnpm (or npm/yarn)
- Additional tools: [PostgreSQL, Docker, Redis, etc.]

### Environment Variables
- Copy `.env.example` to `.env.local` (gitignored)
- Required variables: See `.env.example` for documentation
- Never commit `.env.local` or any files containing secrets

---

## Repository Layout

```
/apps
  /web          - Frontend application (Next.js)
  /api          - Backend API (Express)
/packages
  /*            - Shared TypeScript libraries
/docs           - Documentation
/scripts        - Build and deployment scripts
```

**Key Directories**:
- Frontend code: `/apps/web`
- Backend code: `/apps/api`
- Shared packages: `/packages/*`
- Tests: Co-located with source files (`.test.ts` or `__tests__/`)

---

## Build Commands

```bash
# Build all packages
pnpm build

# Build specific package
pnpm turbo run build --filter <package-name>

# Development mode (watch & rebuild)
pnpm dev

# Clean build artifacts
pnpm clean
```

**Build Output**:
- Frontend: `/apps/web/.next`
- Backend: `/apps/api/dist`
- Packages: `/packages/*/dist`

---

## Testing Instructions

### Run Tests
```bash
# All tests
pnpm test

# Specific package tests
pnpm turbo run test --filter <package-name>

# Watch mode
pnpm test:watch

# Coverage report
pnpm test:coverage
```

### Test Types
- **Unit tests**: `*.test.ts` files
- **Integration tests**: `*.integration.test.ts`
- **E2E tests**: `pnpm test:e2e` (Playwright/Cypress)

### CI/CD
- **CI Location**: `.github/workflows/ci.yml`
- **Required Checks**: lint, test, typecheck (must all pass)
- **Coverage Threshold**: 80% (enforced in CI)

---

## Code Style Guidelines

### TypeScript
- **Strict mode**: Enabled (`tsconfig.json`)
- **Type safety**: No `any` types (use `unknown` if needed)
- **Exports**: No default exports in `/packages/*` (named exports only)

### Formatting & Linting
```bash
# Check linting
pnpm lint

# Fix auto-fixable issues
pnpm lint:fix

# Format code
pnpm format

# Type checking
pnpm typecheck
```

### Naming Conventions
- **Files**: kebab-case (e.g., `user-service.ts`)
- **Components**: PascalCase (e.g., `UserProfile.tsx`)
- **Functions/variables**: camelCase
- **Constants**: UPPER_SNAKE_CASE
- **Types/Interfaces**: PascalCase

### Code Organization
- One component/function per file (except small utilities)
- Co-locate tests with source files
- Group related functionality in directories

---

## Commit & PR Guidelines

### Commit Format
**Use Conventional Commits**: `<type>(<scope>): <description>`

**Types**:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `refactor:` Code refactoring (no functionality change)
- `test:` Adding or updating tests
- `chore:` Build process, tooling, dependencies

**Examples**:
```
feat(auth): add OAuth2 login flow
fix(api): resolve race condition in user creation
docs(readme): update installation instructions
```

### PR Requirements

**Title Format**: `[scope] Concise summary`

**Description Must Include**:
1. **Why**: What problem does this solve? What's the context?
2. **What changed**: Summary of technical changes made
3. **Risks**: Potential impacts, breaking changes, considerations

**Required Checks Before Merge**:
- ✅ `pnpm lint` passes
- ✅ `pnpm test` passes
- ✅ `pnpm typecheck` passes
- ✅ PR approved by at least 1 reviewer
- ✅ All CI checks green

**Review Checklist**:
- [ ] Code follows style guidelines
- [ ] Tests added/updated for new functionality
- [ ] Documentation updated if needed
- [ ] No secrets or credentials committed
- [ ] AGENTS.md updated if workflows changed

---

## Security Considerations

### Secrets Management
- **Never commit secrets**: Use `.env.local` (gitignored)
- **API keys**: Store in environment variables only
- **Credentials**: Use secrets management (Azure Key Vault, AWS Secrets Manager)

### Security Checks
```bash
# Audit dependencies
pnpm audit

# Fix vulnerabilities
pnpm audit fix

# Generate security report
pnpm audit --json > audit-report.json
```

### Security Tools
- **Dependency scanning**: Snyk integration in CI
- **Static analysis**: ESLint security plugins enabled
- **Secret detection**: GitGuardian or TruffleHog in pre-commit

### Security Gotchas
- Validate all user input (use Zod or similar)
- Sanitize data before rendering (prevent XSS)
- Use parameterized queries (prevent SQL injection)
- Rate limit API endpoints

---

## Deployment

### Environments

**Staging**:
- **Trigger**: Auto-deploy on merge to `develop` branch
- **URL**: `https://staging.example.com`
- **Database**: Staging DB (safe to reset)

**Production**:
- **Trigger**: Tag-based deploy (`git tag v1.x.x`)
- **URL**: `https://example.com`
- **Database**: Production DB (never reset)

### Deployment Commands
```bash
# Deploy to staging
git push origin develop

# Deploy to production
git tag v1.0.0
git push origin v1.0.0
```

### Platform
- **Frontend**: Vercel / Netlify
- **Backend**: Railway / Render / AWS
- **Database**: [Specify provider]

### Health Checks
- **Endpoint**: `/api/health`
- **Expected Response**: `{ "status": "ok", "version": "1.0.0" }`

---

## Database

### Setup
```bash
# Run migrations
pnpm db:migrate

# Seed development data
pnpm db:seed

# Reset database (dev only!)
pnpm db:reset
```

### Database Provider
- **Type**: PostgreSQL 14+
- **ORM**: Prisma / TypeORM / Drizzle
- **Connection**: Environment variable `DATABASE_URL`

### Migrations
- **Location**: `/prisma/migrations` or `/db/migrations`
- **Create migration**: `pnpm db:migrate:create <name>`
- **Run migrations**: `pnpm db:migrate` (automatic in CI/CD)

### Schema Changes
1. Update schema file (`schema.prisma` or similar)
2. Create migration: `pnpm db:migrate:create`
3. Review generated migration SQL
4. Test migration on staging first
5. Deploy to production

---

## Additional Resources

- **API Documentation**: `/docs/api.md` or Swagger at `/api/docs`
- **Architecture Decisions**: `/docs/adr/` (Architecture Decision Records)
- **Contributing Guide**: `CONTRIBUTING.md`
- **Full Coding Standards**: `/coding_standards.md` (if exists)
- **Changelog**: `CHANGELOG.md` (generated from commits)

---

## Optional Sections

<!--
Uncomment and customize these sections as needed for your project.
Remove sections that don't apply.
-->

<!--
## MCP Integration

### Available MCP Servers
- **Socket MCP**: Dependency security scanning
- **Clarity MCP**: Web analytics and user behavior
- **Custom MCPs**: [List custom MCP servers]

### Configuration
- **Location**: `~/.codex/config.toml` or project-specific
- **Usage**: AI agents automatically connect to configured MCPs
- **Documentation**: See `.codex/README.md`
-->

<!--
## Performance

### Targets
- 95th percentile API response time: < 200ms
- Time to First Byte (TTFB): < 100ms
- Largest Contentful Paint (LCP): < 2.5s

### Load Testing
```bash
# Run load tests
k6 run scripts/load-test.js

# Profiling (Node.js)
node --inspect apps/api/dist/index.js
```

### Monitoring
- **APM**: New Relic / Datadog / Sentry
- **Logs**: CloudWatch / Papertrail
- **Alerts**: PagerDuty for critical errors
-->

<!--
## Multi-Tenancy

### Tenant Model
- **Type**: Workspace-based (URL path: `/workspace-name/*`)
- **Isolation**: Row-level security in PostgreSQL
- **Tenant Context**: Middleware in `/apps/api/middleware/tenant.ts`

### Database Schema
- All tables include `tenant_id` column (indexed)
- Foreign keys include `tenant_id` for isolation
- Queries automatically scoped to current tenant

### Testing Tenant Isolation
```bash
# Test cross-tenant access
pnpm test:tenancy
```
-->

<!--
## API Design

### REST Principles
- Versioned endpoints: `/v1/*`
- Resource-based URLs: `/api/v1/users/{id}`
- HTTP methods: GET (read), POST (create), PUT (update), DELETE (delete)

### Authentication
- **Type**: JWT tokens in `Authorization: Bearer <token>` header
- **Refresh**: `/api/v1/auth/refresh`
- **Logout**: `/api/v1/auth/logout`

### Error Format
- **Standard**: RFC 7807 Problem Details
- **Example**:
  ```json
  {
    "type": "https://example.com/errors/not-found",
    "title": "Resource Not Found",
    "status": 404,
    "detail": "User with ID 123 not found"
  }
  ```

### Rate Limiting
- Anonymous: 100 requests/hour
- Authenticated: 1000 requests/hour
- Header: `X-RateLimit-Remaining`
-->

<!--
## UI Components

### Component Library
- **Base**: shadcn/ui + Radix UI primitives
- **Styling**: Tailwind CSS
- **Icons**: Lucide React
- **Forms**: React Hook Form + Zod validation

### File Naming
- Components: PascalCase.tsx (e.g., `UserProfile.tsx`)
- Utilities: camelCase.ts (e.g., `formatDate.ts`)
- Hooks: `use` prefix (e.g., `useAuth.ts`)

### State Management
- **Server state**: TanStack Query (React Query)
- **Client state**: Zustand / Jotai
- **URL state**: nuqs (Next.js) or React Router

### Accessibility
- All interactive elements keyboard accessible
- ARIA labels for screen readers
- Color contrast ratio ≥ 4.5:1
- Test with `pnpm test:a11y`
-->

<!--
## Monorepo Structure

### Build System
- **Tool**: Turborepo
- **Cache**: Remote caching enabled (Vercel)
- **Pipelines**: Defined in `turbo.json`

### Workspace Protocol
- **Package manager**: pnpm workspaces
- **Internal dependencies**: `workspace:*` protocol
- **Shared configs**: `/packages/config-*`

### Adding Packages
```bash
# Create new package
pnpm create turbo@latest --example basic packages/new-package

# Add dependency to specific package
pnpm add --filter @myorg/web <dependency>

# Link internal package
pnpm add --filter @myorg/web @myorg/shared-utils@workspace:*
```

### Build Order
Turborepo automatically determines build order based on `dependsOn` in `turbo.json`.
Shared packages are built before apps that depend on them.
-->

---

## Maintenance

### Keeping AGENTS.md Up-to-Date

**When to Update**:
- ✅ Workflow changes (new build commands, deployment process)
- ✅ New technologies added (new database, framework, tool)
- ✅ Security practices change (new secrets management)
- ✅ Repository structure changes (new directories, moved files)

**Who Updates**:
- PR authors update AGENTS.md when introducing workflow changes
- Reviewers check AGENTS.md is current during PR review
- Treat AGENTS.md like code - keep it accurate and concise

**Best Practices**:
- Link to existing docs instead of duplicating content
- Be explicit and concise
- Include commands that agents can run programmatically
- Remove outdated sections
- Keep total length reasonable (< 32 KiB recommended)

---

**Template Version**: 1.0
**Last Updated**: 2025-11-05
**Format**: AGENTS.md Universal Standard (compatible with 20+ AI coding tools)
