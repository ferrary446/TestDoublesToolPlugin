# TestDoublesToolPlugin

A Swift Package Manager plugin that automatically generates test doubles (spies, mocks, and struct extensions) for your iOS projects based on simple annotations in your code.

## Features

- **Spies**: Track method calls and their parameters
- **Mocks**: Provide controlled responses and error simulation
- **Struct Extensions**: Generate factory methods for easy test data creation
- **Automatic Generation**: Files are generated during build time
- **Clean Structure**: Generated files are organized in your test target

## Installation

Add this package as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-repo/TestDoublesToolPlugin", from: "1.0.0")
]
```

Then add the plugin to your target:

```swift
.target(
    name: "YourTarget",
    plugins: [
        .plugin(name: "TestDoublesToolPlugin", package: "TestDoublesToolPlugin")
    ]
)
```

## Usage

### Spy Generation

Add the `// TestDoubles:spy` annotation above any protocol to generate a spy:

**Input:**
```swift
// TestDoubles:spy
protocol SaveWorkoutUseCase {
    func callAsFunction(
        source: SourceType,
        workout: WorkoutInformation
    ) async throws
}
```

**Generated Output:**
```swift
@testable import PeakTrack

final class SaveWorkoutUseCaseSpy: SaveWorkoutUseCase {
    struct Call {
        let source: SourceType
        let workout: WorkoutInformation
    }

    private(set) var calls = [Call]()
    private let errorToThrow: (() -> Error)?

    init(errorToThrow: (() -> Error)? = nil) {
        self.errorToThrow = errorToThrow
    }

    func callAsFunction(
        source: SourceType,
        workout: WorkoutInformation
    ) async throws {
        calls.append(Call(source: source, workout: workout))

        if let errorToThrow {
            throw errorToThrow()
        }
    }
}
```

### Mock Generation

Add the `// TestDoubles:mock` annotation above any protocol to generate a mock:

**Input:**
```swift
// TestDoubles:mock
protocol DataRepository {
    func fetchData() async throws -> Data
}
```

**Generated Output:**
```swift
@testable import PeakTrack

final class DataRepositoryMock: DataRepository {
    var fetchDataReturnValue: Data!
    var shouldThrowError = false
    var errorToThrow: Error = NSError(domain: "TestError", code: 1)

    func fetchData() async throws -> Data {
        if shouldThrowError {
            throw errorToThrow
        }

        return fetchDataReturnValue
    }
}
```

### Struct Extension Generation

Add the `// TestDoubles:struct` annotation above any struct to generate a factory extension:

**Input:**
```swift
import Foundation

// TestDoubles:struct
struct WorkoutInformation: Hashable {
    let id: UUID
    let name: String
    let place: String
    let duration: String
}
```

**Generated Output:**
```swift
import Foundation
@testable import PeakTrack

extension WorkoutInformation {
    static func makeMock(
        id: UUID = UUID(),
        name: String = "name",
        place: String = "place",
        duration: String = "duration"
    ) -> Self {
        WorkoutInformation(
            id: id,
            name: name,
            place: place,
            duration: duration
        )
    }
}
```

## File Structure

The plugin automatically organizes generated files following this structure:

```
YourProject/
├── MainTarget/
│   └── Data/
│       └── Repository.swift        // Original file with annotation
└── TestTarget/
    └── Data/
        └── RepositorySpy.swift     // Generated spy
        └── RepositoryMock.swift    // Generated mock
        └── WorkoutInformation+Mock.swift // Generated struct extension
```

## Usage in Tests

### Using Spies
```swift
import Testing
@testable import YourApp

@Suite("Save Workout Tests")
struct SaveWorkoutTests {
    
    @Test("Should save workout with correct parameters")
    func testSaveWorkout() async throws {
        // Given
        let spy = SaveWorkoutUseCaseSpy()
        let workout = WorkoutInformation.makeMock()
        
        // When
        try await spy(.automatic, workout)
        
        // Then
        #expect(spy.calls.count == 1)
        #expect(spy.calls.first?.source == .automatic)
        #expect(spy.calls.first?.workout == workout)
    }
}
```

### Using Mocks
```swift
@Test("Should handle repository errors")
func testRepositoryError() async {
    // Given
    let mock = DataRepositoryMock()
    mock.shouldThrowError = true
    mock.errorToThrow = NetworkError.connectionFailed
    
    // When/Then
    await #expect(throws: NetworkError.connectionFailed) {
        try await mock.fetchData()
    }
}
```

### Using Struct Factories
```swift
@Test("Should create workout with custom data")
func testCustomWorkout() {
    // Given
    let workout = WorkoutInformation.makeMock(
        name: "Morning Run",
        place: "Central Park"
    )
    
    // Then
    #expect(workout.name == "Morning Run")
    #expect(workout.place == "Central Park")
    #expect(workout.id != nil) // Uses default UUID()
}
```

## Supported Swift Features

- ✅ Async/await methods
- ✅ Throwing methods
- ✅ Methods with return values
- ✅ Methods with multiple parameters
- ✅ Optional types
- ✅ Generic types (basic support)
- ✅ Custom types
- ✅ Standard Swift types (String, Int, UUID, etc.)

## Requirements

- Swift 6.2+
- iOS 13.0+
- macOS 10.15+

## License

MIT License - see LICENSE file for details.