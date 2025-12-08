# CI/CD Setup Guide

This document explains the CI/CD pipeline setup for the Sustainable Transport app.

## Overview

The CI/CD pipeline runs automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches

## Pipeline Structure

### 1. Backend QA Job

Runs the following checks:
- ✅ **Linting** - ESLint with TypeScript rules
- ✅ **Formatting** - Prettier code style check
- ✅ **Type Checking** - TypeScript compilation check
- ✅ **Unit Tests** - Jest unit tests with coverage
- ✅ **Integration Tests** - Service integration tests
- ✅ **Coverage Report** - Uploads to Codecov (optional)

**Environment:**
- Node.js 20
- PostgreSQL 15 (test database)
- Prisma migrations run automatically

### 2. Frontend QA Job

Runs the following checks:
- ✅ **Code Analysis** - Flutter analyzer
- ✅ **Formatting** - Dart format check
- ✅ **Unit Tests** - Flutter test suite
- ✅ **Coverage Report** - Uploads to Codecov (optional)

**Environment:**
- Flutter 3.24.0 (stable)

### 3. E2E Tests Job

Runs end-to-end tests:
- ✅ **Backend E2E** - Full API endpoint tests
- ✅ **Frontend E2E** - Complete user flow tests (when implemented)

**Note:** E2E tests run after backend and frontend QA pass.

## Local Setup

### Pre-commit Hooks (Husky)

Pre-commit hooks run automatically before each commit:

1. **Linting** - Catches code quality issues
2. **Formatting** - Ensures consistent style
3. **Type Checking** - Catches type errors
4. **Unit Tests** - Fast feedback loop

**Setup:**
```bash
cd backend
npm install
npm run prepare  # Sets up Husky
```

### Running Tests Locally

**Backend:**
```bash
cd backend

# All tests
npm test

# Unit tests only
npm run test:unit

# Integration tests
npm run test:integration

# E2E tests
npm run test:e2e

# With coverage
npm run test:cov

# Watch mode
npm run test:watch
```

**Frontend:**
```bash
cd Frontend

# All tests
flutter test

# With coverage
flutter test --coverage

# Analyze code
flutter analyze
```

## Quality Gates

PRs must pass all checks:
1. ✅ All linting checks
2. ✅ All formatting checks
3. ✅ All unit tests pass
4. ✅ Coverage threshold met (70% backend, 60% frontend)
5. ✅ No critical security issues
6. ✅ E2E tests pass (for critical paths)

## Coverage Reports

Coverage reports are generated in:
- **Backend**: `backend/coverage/`
- **Frontend**: `Frontend/coverage/`

In CI, coverage is uploaded to Codecov (if configured).

## Troubleshooting

### Pre-commit hooks not running

```bash
cd backend
npm run prepare
chmod +x .husky/pre-commit
```

### Tests failing in CI but passing locally

1. Check database connection string
2. Verify environment variables
3. Check Node.js/Flutter versions match CI

### Coverage below threshold

Run tests with coverage locally:
```bash
npm run test:cov
```

Check which files need more tests and add them.

## Next Steps

1. **Add more tests** - Increase coverage to meet thresholds
2. **Configure Codecov** - Set up coverage reporting service
3. **Add security scanning** - Integrate Snyk or Dependabot
4. **Performance testing** - Add load testing for critical endpoints
5. **Deployment** - Add deployment jobs after QA passes

