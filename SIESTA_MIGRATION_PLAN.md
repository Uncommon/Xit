# Siesta Library Migration Plan

**Date:** February 10, 2026  
**Project:** Xit  
**Purpose:** Migrate from Siesta networking library to native URLSession APIs

## Executive Summary

This document outlines a comprehensive plan to migrate the Xit project away from the Siesta REST client library to native iOS/macOS URLSession APIs. The migration will improve maintainability, reduce external dependencies, and leverage modern Swift concurrency features (async/await).

## Current State Analysis

### Siesta Usage Overview

The Siesta library is currently used in the following areas:

1. **Service Layer** (`Xit/Services/`)
   - `BasicAuthService.swift` - Base authentication service (107 lines using Siesta)
   - `TeamCityAPI.swift` - TeamCity build status integration (~400 lines)
   - `BitbucketServerAPI.swift` - Bitbucket Server API (~450 lines)
   - `Services.swift` - Service management and coordination (298 lines)
   - `ServicesData.swift` - Pull request protocols and data types
   - `BuildStatusCache.swift` - Build status data management
   - `PullRequestCache.swift` - Pull request data management

2. **Extensions**
   - `SiestaExtensions.swift` - Custom Siesta extensions adding async/await support

3. **Testing**
   - `Repository/Fakes.swift` - Mock implementations for testing

4. **UI Controllers**
   - `RemoteSheetController.swift` - Remote repository management

**Note:** While Siesta was originally adopted for its caching capabilities, this turned out not to be needed for this application. The migration will use simple URLSession without implementing HTTP-level caching.

### Key Siesta Features Currently Used

1. **Resource Management**
   - `Service.resource()` - Creates resource instances per URL
   - `Resource.load()` - Initiates network requests

2. **Configuration**
   - `Service.configure()` - Configures headers, transformers, and behavior
   - Pipeline transformers for JSON/XML parsing
   - HTTP Basic Authentication setup

3. **Observation Pattern**
   - `Resource.addObserver()` - Observes resource state changes
   - Event-driven updates (`.newData`, `.error`, `.notModified`)

4. **Data Access**
   - `Resource.latestData` - Response data
   - `Resource.latestError` - Error information
   - Request cancellation
   - Request decoration (adding headers, auth)

6. **Response Transformation**
   - JSON to Dictionary/Array
   - XML document parsing
   - Custom content transformers

### Dependencies

- **Package:** `https://github.com/bustoutsolutions/siesta`
- **Referenced in:** `Xit.xcodeproj/project.pbxproj`
- **Package version:** Specified in `Package.resolved`

## Migration Goals

1. **Remove External Dependency:** Eliminate Siesta package dependency
2. **Modernize Networking:** Use native URLSession with async/await
3. **Maintain Functionality:** Preserve all existing API integrations
4. **Improve Testing:** Enable better unit testing with protocol-based design
5. **Simplify Architecture:** Remove unnecessary caching infrastructure
## Architecture Design

### New Networking Layer

#### 1. Core Protocol Layer

```swift
// NetworkService.swift
protocol NetworkService {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func request(_ endpoint: Endpoint) async throws -> Data
}

// Endpoint.swift
struct Endpoint {
    let baseURL: URL
    let path: String
    let method: HTTPMethod
    let headers: [String: String]
    let queryItems: [URLQueryItem]?
    let body: Data?
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
    }
}
```

#### 2. URLSession-Based Implementation

```swift
// URLSessionNetworkService.swift
final class URLSessionNetworkService: NetworkService {
    private let session: URLSession
    private let decoder: JSONDecoder
    
    init(session: URLSession = .shared, 
         decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }
    
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func request(_ endpoint: Endpoint) async throws -> Data
}
```

#### 3. Authentication Layer

```swift
// AuthenticationManager.swift
protocol AuthenticationProvider {
    func configure(request: inout URLRequest) async throws
}

// BasicAuthProvider.swift
final class BasicAuthProvider: AuthenticationProvider {
    private let username: String
    private let password: String
    
    func configure(request: inout URLRequest) async throws {
        let credentials = "\(username):\(password)"
        let base64 = credentials.data(using: .utf8)?.base64EncodedString()
        request.setValue("Basic \(base64 ?? "")", 
                        forHTTPHeaderField: "Authorization")
    }
}
```

### Service Layer Refactoring

#### 1. Base Service Class

```swift
// BaseHTTPService.swift
class BaseHTTPService {
    let networkService: NetworkService
    let account: Account
    private let authProvider: AuthenticationProvider
    
    @Published var authenticationStatus: Services.Status
    
    init(account: Account, 
         password: String,
         networkService: NetworkService) {
        self.account = account
        self.authProvider = BasicAuthProvider(
            username: account.user, 
            password: password
        )
        self.networkService = networkService
        self.authenticationStatus = .notStarted
    }
    
    func authenticate() async throws
    func makeRequest<T: Decodable>(path: String, 
                                   method: HTTPMethod) async throws -> T
}
```

#### 2. TeamCity Service

```swift
// TeamCityHTTPService.swift
final class TeamCityHTTPService: BaseHTTPService, 
                                  BuildStatusService {
    
    func buildStatus(_ branch: String, 
                     buildType: String) async throws -> BuildStatusResponse
    
    func buildTypes(for remoteURL: String) async throws -> [BuildType]
    
    // Implement BuildStatusService protocol methods
}
```

#### 3. Bitbucket Service

```swift
// BitbucketHTTPService.swift
final class BitbucketHTTPService: BaseHTTPService, 
                                   PullRequestService {
    
    func getPullRequests() async throws -> [BitbucketPullRequest]
    
    func approve(request: any PullRequest) async throws
    
    // Implement PullRequestService protocol methods
}
```

## Migration Strategy

### Phase 1: Foundation ✅ **COMPLETE** (Week 1-2)

**Goal:** Create new networking infrastructure alongside existing code

**Status:** Completed February 12, 2026

1. **Create New Files** ✅
   - ✅ `NetworkService.swift` - Core protocol with async/await support
   - ✅ `Endpoint.swift` - Request configuration with URLRequest conversion
   - ✅ `URLSessionNetworkService.swift` - URLSession implementation with logging
   - ✅ `AuthenticationProvider.swift` - Auth protocols
   - ✅ `BasicAuthProvider.swift` - Basic auth implementation with error handling
   - ✅ `NetworkError.swift` - Comprehensive error types
   - ✅ `NetworkConfiguration.swift` - Configuration with sensible defaults

2. **Testing Infrastructure** ✅
   - ✅ `MockNetworkService.swift` - Thread-safe mock implementation for tests
   - ✅ `NetworkServiceTests.swift` - Comprehensive unit tests using Swift Testing
   - ✅ `MockURLProtocol` - Thread-safe protocol mock for parallel test execution

3. **Success Criteria** ✅
   - ✅ All new networking classes compile without errors
   - ✅ All 9 unit tests pass consistently
   - ✅ Tests verified with parallel execution (5 consecutive runs)
   - ✅ No impact on existing code
   - ✅ Modern Swift practices (async/await, Sendable, actors)
   - ✅ Follows project coding style (CONTRIBUTING.md)

**Achievements:**
- Built complete networking layer with URLSession
- Implemented protocol-based design for testability
- Created thread-safe mock infrastructure supporting parallel tests
- Converted tests to Swift Testing framework
- Fixed MockURLProtocol race conditions for parallel execution
- Zero compilation errors or warnings
- Full documentation in PHASE_1_COMPLETION.md and MOCKURLPROTOCOL_FIX.md

### Phase 2: Service Migration (Week 3-4)

**Goal:** Migrate one service completely while maintaining backward compatibility

1. **Create Parallel Implementation** ✅
   - ✅ `BaseHTTPService.swift` - New URLSession-based base class
   - ✅ Keep existing Siesta code functional
   - ✅ Add feature flag `Services.useNewNetworking`

2. **Migrate TeamCityAPI**
   - Create `TeamCityHTTPService.swift`
   - Implement all BuildStatusService methods
   - Add comprehensive tests
   - Test with real TeamCity instance

3. **Testing Strategy**
   - Unit tests for each endpoint
   - Integration tests with mock server
   - Manual testing with real services
   - A/B testing with feature flag

4. **Success Criteria**
   - TeamCity integration works identically
   - All tests pass
   - No regressions in UI

### Phase 3: Complete Service Migration (Week 5-6)

**Goal:** Migrate remaining services

1. **Migrate BitbucketServerAPI**
   - Create `BitbucketHTTPService.swift`
   - Implement all PullRequestService methods
   - Port all Bitbucket-specific logic
   - Comprehensive testing

2. **Update Services Manager**
   - Refactor `Services.swift` to use new architecture
   - Remove Siesta Service inheritance
   - Update service creation logic
   - Maintain singleton pattern

3. **Update Extensions**
   - Remove `SiestaExtensions.swift`
   - Create Swift-native extensions if needed
   - Update any dependent code

4. **Success Criteria**
   - All services migrated
   - No Siesta imports in service layer
   - All existing functionality preserved

### Phase 4: Remove Siesta (Week 7)

**Goal:** Complete removal of Siesta dependency

1. **Code Cleanup**
   - Remove all `import Siesta` statements
   - Delete Siesta-related files
   - Remove feature flags
   - Code review and refactoring

2. **Remove Package Dependency**
   - Remove from `project.pbxproj`
   - Remove from `Package.resolved`
   - Update documentation

3. **Update Tests**
   - Remove Siesta from test targets
   - Update mock implementations
   - Ensure test coverage maintained

4. **Documentation**
   - Update README if applicable
   - Document new networking architecture
   - Create migration notes for future reference

5. **Success Criteria**
   - Project builds without Siesta
   - All tests pass
   - No runtime issues
   - App functions identically

## Technical Considerations

### 1. Authentication

**Current Siesta Approach:**
- Configuration closure with header injection
- Automatic header application to all requests

**New Approach:**
- `AuthenticationProvider` protocol
- Explicit auth configuration per request
- Support for token refresh if needed

### 2. Response Transformation

**Current Siesta Approach:**
- Pipeline transformers
- Automatic JSON/XML parsing
- Type-safe content transformation

**New Approach:**
- `Codable` for JSON
- `XMLDocument` for XML (keep existing)
- Protocol-based transformation strategy

### 3. Error Handling

**Current Siesta Approach:**
- `Resource.latestError`
- Siesta error types
- Observer-based error notification

**New Approach:**
- Swift Error protocol
- Structured error types per service
- async/await error propagation

```swift
enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(Int)
    case decodingError(Error)
    case noData
    case requestFailed(Error)
}

enum TeamCityError: Error {
    case authenticationFailed
    case buildTypeNotFound
    case invalidXMLResponse
    case apiError(NetworkError)
}
```

### 4. Request Cancellation

**Current Siesta Approach:**
- `Request.cancel()`
- Automatic cleanup

**New Approach:**
- `Task` cancellation
- Check `Task.isCancelled`
- Cancellable async sequences

### 5. Observation Pattern

**Current Siesta Approach:**
- `Resource.addObserver()`
- Event-based updates
- Automatic observer cleanup

**New Approach:**
- Combine publishers (`@Published`)
- Async sequences
- Structured concurrency

### 6. Configuration Management

**Current Siesta Approach:**
- `Service.configure()` with pattern matching
- Per-resource configuration
- Configuration inheritance

**New Approach:**
- `NetworkConfiguration` struct
- Service-level configuration
- Endpoint-level overrides

## Risk Assessment

### High Risk Items

1. **Breaking API Integrations**
   - **Risk:** Subtle differences in request/response handling
   - **Mitigation:** Comprehensive testing, parallel implementation, gradual rollout

2. **Authentication Issues**
   - **Risk:** Auth flow differences break login
   - **Mitigation:** Extensive auth testing, fallback mechanisms

### Medium Risk Items

1. **Missing Edge Cases**
   - **Risk:** Siesta handles cases we don't know about
   - **Mitigation:** Code review, analyze Siesta source, extensive testing

2. **Race Conditions**
   - **Risk:** Async/await migration introduces timing issues
   - **Mitigation:** Use actors, proper synchronization, stress testing

3. **XML Parsing Changes**
   - **Risk:** Different XML handling breaks TeamCity
   - **Mitigation:** Keep existing XMLDocument approach, unit tests

### Low Risk Items

1. **Test Coverage Gaps**
   - **Risk:** Tests don't catch all regressions
   - **Mitigation:** Increase test coverage during migration

2. **Documentation Lag**
   - **Risk:** Code changes faster than docs
   - **Mitigation:** Update docs with each phase

## Testing Strategy

### Unit Tests

- Test each networking component in isolation
- Mock URLSession with URLProtocol
- Test authentication providers
- Test endpoint construction
- Test error handling

### Integration Tests

- Test complete request/response cycles
- Test with mock HTTP servers
- Test authentication flows
- Test concurrent requests
- Test error scenarios

### Manual Testing

- Test with real TeamCity instance
- Test with real Bitbucket Server
- Test all UI features that use services
- Test authentication prompts
- Test error messages
- Test performance

### Regression Testing

- Maintain existing test suite
- Ensure all tests pass throughout migration
- Add new tests for edge cases
- Test on multiple macOS versions

## Rollback Plan

### Rollback Triggers

- Critical bugs in production
- Performance degradation > 20%
- Authentication failures
- Data loss or corruption
- Showstopper bugs that can't be fixed quickly

### Rollback Procedure

1. **Feature Flag Approach (Phases 2-3)**
   - Switch feature flag back to Siesta
   - No code changes required
   - Can rollback per-service if needed

2. **Git Revert (Phase 4)**
   - Revert commits that removed Siesta
   - Re-add package dependency
   - Rebuild and test

3. **Communication**
   - Document rollback decision
   - Analyze root cause
   - Plan fixes before retry

## Success Metrics

### Technical Metrics

- ✅ Zero Siesta imports in codebase
- ✅ All existing tests pass
- ✅ No increase in crash rate
- ✅ Network performance within 5% of baseline
- ✅ Memory usage unchanged or reduced
- ✅ Build time unchanged or improved

### Functional Metrics

- ✅ All API integrations working
- ✅ Authentication flows functional
- ✅ Pull request features working
- ✅ Build status features working
- ✅ Error handling appropriate

### Quality Metrics

- ✅ Code review completed
- ✅ Test coverage ≥ existing coverage
- ✅ Documentation updated
- ✅ No new compiler warnings
- ✅ Static analysis clean

## Timeline

| Phase | Duration | Start | End | Status | Deliverables |
|-------|----------|-------|-----|--------|--------------|
| Phase 1: Foundation | 2 weeks | Week 1 | Week 2 | ✅ **COMPLETE** | New networking layer, tests |
| Phase 2: Service Migration | 2 weeks | Week 3 | Week 4 | 🔄 Next | TeamCity migrated |
| Phase 3: Complete Migration | 2 weeks | Week 5 | Week 6 | ⏸️ Pending | All services migrated |
| Phase 4: Remove Siesta | 1 week | Week 7 | Week 7 | ⏸️ Pending | Siesta removed, docs updated |
| **Total** | **7 weeks** | | | **On Track** | **Complete migration** |

**Progress:** Phase 1 completed February 12, 2026 - Ready for Phase 2

## Resources Required

### Development

- 1 senior iOS/macOS developer (full-time)
- Code review support
- Access to test TeamCity/Bitbucket instances

### Testing

- QA testing time (2-3 days per phase)
- Beta testing period (1 week after Phase 4)
- Production monitoring

### Infrastructure

- Test instances of TeamCity
- Test instances of Bitbucket Server
- CI/CD pipeline updates

## Post-Migration

### Monitoring

- Monitor crash reports for 2 weeks
- Track API request metrics
- Monitor authentication success rates
- Track user-reported issues

### Documentation

- Update architecture documentation
- Create "Networking Guide" for contributors
- Document lessons learned
- Update contribution guidelines

### Maintenance

- Address any issues that arise
- Optimize based on metrics
- Consider future enhancements:
  - Request retry logic
  - Better offline support
  - Request prioritization

## Alternative Approaches Considered

### 1. Keep Siesta
- **Pros:** No migration cost, proven solution
- **Cons:** External dependency, maintenance concerns, less control
- **Decision:** Rejected - reduces dependency management burden

### 2. Use Alamofire
- **Pros:** Popular, well-maintained, feature-rich
- **Cons:** Still external dependency, overkill for our needs
- **Decision:** Rejected - doesn't reduce dependencies

### 3. Gradual Migration with Adapter Pattern
- **Pros:** Very safe, can migrate slowly
- **Cons:** Complex, maintains both systems longer
- **Decision:** Considered but current plan with feature flags is sufficient

### 4. Complete Rewrite
- **Pros:** Clean slate, optimal design
- **Cons:** High risk, long timeline
- **Decision:** Rejected - evolutionary approach is safer

## Appendix

### A. File Inventory

Files to be created:
- `Xit/Services/Networking/NetworkService.swift`
- `Xit/Services/Networking/URLSessionNetworkService.swift`
- `Xit/Services/Networking/Endpoint.swift`
- `Xit/Services/Networking/NetworkConfiguration.swift`
- `Xit/Services/Networking/NetworkError.swift`
- `Xit/Services/Authentication/AuthenticationProvider.swift`
- `Xit/Services/Authentication/BasicAuthProvider.swift`
- `Xit/Services/HTTP/BaseHTTPService.swift`
- `Xit/Services/HTTP/TeamCityHTTPService.swift`
- `Xit/Services/HTTP/BitbucketHTTPService.swift`

Files to be modified:
- `Xit/Services/Services.swift`
- `Xit/Services/ServicesData.swift`
- `Xit/Services/BuildStatusCache.swift`
- `Xit/Services/PullRequestCache.swift`

Files to be removed:
- `Xit/Services/BasicAuthService.swift` (replaced)
- `Xit/Services/TeamCityAPI.swift` (replaced)
- `Xit/Services/BitbucketServerAPI.swift` (replaced)
- `Xit/Utils/Extensions/SiestaExtensions.swift`

### B. Key Dependencies

Current Siesta usage patterns:
```swift
// Resource creation
let resource = service.resource(path)

// Observation
resource.addObserver(owner: self) { resource, event in ... }

// Loading
resource.load()
resource.loadIfNeeded()

// Data access
resource.latestData
resource.latestError

// Configuration
service.configure { builder in
    builder.headers["Key"] = "Value"
}
```

Replacement patterns:
```swift
// Request creation
let endpoint = Endpoint(baseURL: baseURL, path: path, ...)

// Async/await
let data = try await networkService.request(endpoint)

// Data access (direct result)
let response: MyType = try await networkService.request(endpoint)

// Error handling
do {
    let data = try await networkService.request(endpoint)
} catch {
    // Handle error
}

// Configuration
let service = URLSessionNetworkService(
    configuration: NetworkConfiguration(
        headers: ["Key": "Value"],
        ...
    )
)
```

### C. Reference Documentation

- Apple URLSession: https://developer.apple.com/documentation/foundation/urlsession
- Swift Concurrency: https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html
- Codable: https://developer.apple.com/documentation/swift/codable
- Siesta Documentation: https://bustoutsolutions.github.io/siesta/
- Testing with URLProtocol: https://developer.apple.com/documentation/foundation/urlprotocol

---

**Document Version:** 1.0  
**Last Updated:** February 10, 2026  
**Author:** Development Team  
**Status:** Proposed
