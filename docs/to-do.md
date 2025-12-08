- ✅ test navigation (implemented mock location simulation - see Frontend/TESTING_NAVIGATION.md)
- adapt UI to navigation
- verify Eco impact data
- put things into docker like gbfs for gira and so on
- find out how the app should be deployed (artifact for OS-independence maybe)
- find out how we host this in an aws server so that the app can be click-and-run instead of us having to start the server first
  - this has to do with the centralization of spin-up
- add performance testing once the spin-up has been centralized

## QA & Testing (from QA_STRATEGY.md)
- increase test coverage to meet 70% threshold (currently very low - only 2 spec files exist)
- add tests for critical paths: authentication, route planning, CO2 calculation, data validation
- add frontend widget tests (30% of frontend tests per strategy)
- add frontend E2E tests (10% of frontend tests per strategy)
- enforce coverage thresholds in CI/CD (currently just reports, doesn't fail)
- add security scanning to CI/CD (npm audit, Snyk, or similar)
- enable TypeScript strict mode gradually (currently disabled in tsconfig.json)

## Production Readiness
- set up monitoring/observability (logging, error tracking, metrics)
- implement proper error handling and user-friendly error messages
- set up environment variable management for production
- create database migration strategy for production deployments
- add health check endpoints for all services
- set up backup/restore procedures for database

## Documentation
- update README with setup instructions
- document API endpoints (Swagger/OpenAPI)
- create deployment runbook
- document environment variables needed
