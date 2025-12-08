# QA Strategy & Implementation Guide

This document outlines the comprehensive Quality Assurance (QA) layer for the Sustainable Transport app, designed to integrate seamlessly with CI/CD pipelines.

## Table of Contents

1. [Testing Pyramid](#testing-pyramid)
2. [Code Quality](#code-quality)
3. [Test Coverage Requirements](#test-coverage-requirements)
4. [Pre-commit Hooks](#pre-commit-hooks)
5. [CI/CD Integration](#cicd-integration)
6. [Performance Testing](#performance-testing)
7. [Accessibility Testing](#accessibility-testing)
8. [Security Testing](#security-testing)

## Testing Pyramid

### Backend (NestJS)

```
        /\
       /E2E\         ← Few, critical user flows
      /------\
     /Integration\   ← Service interactions
    /------------\
   /   Unit Tests  \  ← Many, fast, isolated
  /----------------\
```

**Unit Tests** (70% of tests)
- Service logic
- Utility functions
- DTOs validation
- Business rules

**Integration Tests** (20% of tests)
- Controller + Service interactions
- Database operations
- External API mocking
- Module dependencies

**E2E Tests** (10% of tests)
- Complete API endpoints
- Authentication flows
- Critical user journeys

### Frontend (Flutter)

```
        /\
       /E2E\         ← Critical user flows
      /------\
     /Widget Tests\  ← UI components
    /------------\
   /   Unit Tests  \  ← Business logic
  /----------------\
```

**Unit Tests** (60% of tests)
- Services (routes, auth, etc.)
- Controllers/State management
- Utility functions
- Business logic

**Widget Tests** (30% of tests)
- Individual widgets
- User interactions
- State changes
- Navigation

**E2E Tests** (10% of tests)
- Complete user flows
- Integration with backend
- Real device testing

## Code Quality

### Backend

**Linting**: ESLint
- Configuration: `.eslintrc.js`
- Rules: TypeScript best practices, NestJS patterns
- Auto-fix on save

**Formatting**: Prettier
- Configuration: `.prettierrc`
- Consistent code style
- Pre-commit formatting

**Type Safety**: TypeScript strict mode
- No `any` types
- Strict null checks
- Proper type definitions

### Frontend

**Linting**: Dart Analyzer + flutter_lints
- Configuration: `analysis_options.yaml`
- Rules: Flutter best practices
- Auto-fix available

**Formatting**: `dart format`
- Consistent code style
- Pre-commit formatting

## Test Coverage Requirements

### Minimum Coverage Thresholds

| Layer | Unit Tests | Integration | E2E | Total |
|-------|-----------|-------------|-----|-------|
| Backend | 80% | 60% | 5 critical flows | 70%+ |
| Frontend | 70% | 50% | 3 critical flows | 60%+ |

### Critical Paths (Must Have 100% Coverage)

**Backend:**
- Authentication/Authorization
- Route planning logic
- CO2 calculation
- Data validation

**Frontend:**
- Authentication flow
- Route planning UI
- Navigation controller
- Eco score calculation

## Pre-commit Hooks

Using **Husky** (backend) and **git hooks** (frontend) to run:

1. **Linting** - Catch code quality issues
2. **Formatting** - Ensure consistent style
3. **Unit Tests** - Fast feedback loop
4. **Type Checking** - Catch type errors

## CI/CD Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/qa.yml
name: QA Pipeline

on: [push, pull_request]

jobs:
  backend-qa:
    - Lint & Format
    - Type Check
    - Unit Tests
    - Integration Tests
    - Coverage Report
    - Security Scan

  frontend-qa:
    - Lint & Format
    - Analyze
    - Unit Tests
    - Widget Tests
    - Coverage Report

  e2e-tests:
    - Backend E2E
    - Frontend E2E
    - Integration E2E
```

## Performance Testing

### Backend
- API response time benchmarks
- Database query optimization
- Load testing (optional)

### Frontend
- Widget build performance
- Navigation smoothness
- Memory leak detection

## Accessibility Testing

### Frontend
- Screen reader compatibility
- Color contrast ratios
- Keyboard navigation
- Semantic HTML

## Security Testing

### Backend
- Authentication/Authorization
- Input validation
- SQL injection prevention
- XSS prevention
- Rate limiting

### Frontend
- Secure storage
- Token handling
- Input sanitization

## Test Organization

### Backend Structure
```
backend/
├── src/
│   └── [module]/
│       ├── [module].service.ts
│       ├── [module].service.spec.ts  ← Unit tests
│       ├── [module].controller.ts
│       └── [module].controller.spec.ts
└── test/
    ├── e2e/
    │   └── [feature].e2e-spec.ts     ← E2E tests
    └── integration/
        └── [module].integration.spec.ts
```

### Frontend Structure
```
Frontend/
├── lib/
│   └── [feature]/
│       ├── [feature].dart
│       └── [feature]_test.dart        ← Unit tests
└── test/
    ├── widget/
    │   └── [widget]_test.dart         ← Widget tests
    └── integration/
        └── [flow]_test.dart           ← E2E tests
```

## Running Tests

### Backend
```bash
# Unit tests
npm run test

# Watch mode
npm run test:watch

# Coverage
npm run test:cov

# E2E
npm run test:e2e
```

### Frontend
```bash
# All tests
flutter test

# Specific test
flutter test test/services/routes_service_test.dart

# Coverage
flutter test --coverage
```

## Coverage Reports

- **Backend**: Generated in `backend/coverage/`
- **Frontend**: Generated in `Frontend/coverage/`
- **CI**: Uploaded to coverage service (Codecov, Coveralls, etc.)

## Quality Gates

PRs must pass:
1. ✅ All linting checks
2. ✅ All formatting checks
3. ✅ All unit tests pass
4. ✅ Coverage threshold met
5. ✅ No critical security issues
6. ✅ E2E tests pass (for critical paths)

## Continuous Improvement

- Weekly test coverage reviews
- Monthly security audits
- Quarterly performance benchmarks
- Regular dependency updates

