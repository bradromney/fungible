import XCTest
@testable import FungibleDomain

final class MathTests: XCTestCase {
    private let eps = 1e-9

    func testVectorBasics() {
        let a = Vector3(1, 2, 2)
        XCTAssertEqual(a.length, 3, accuracy: eps)
        XCTAssertEqual(Vector3(0, 0, 0).distance(to: Vector3(3, 0, 4)), 5, accuracy: eps)
        XCTAssertEqual(a.normalized().length, 1, accuracy: eps)
    }

    func testIdentityQuaternionDoesNotRotate() {
        let v = Vector3(1, 2, 3)
        let r = Quaternion.identity.act(v)
        XCTAssertEqual(r.x, 1, accuracy: eps)
        XCTAssertEqual(r.y, 2, accuracy: eps)
        XCTAssertEqual(r.z, 3, accuracy: eps)
    }

    func test90DegreeZRotationMapsXToY() {
        // Rotation of +90° about Z: x-axis → y-axis.
        let half = Double.pi / 4
        let q = Quaternion(w: cos(half), x: 0, y: 0, z: sin(half)).normalized()
        let r = q.act(Vector3(1, 0, 0))
        XCTAssertEqual(r.x, 0, accuracy: 1e-12)
        XCTAssertEqual(r.y, 1, accuracy: 1e-12)
        XCTAssertEqual(r.z, 0, accuracy: 1e-12)
    }

    func testTransformInverseRoundTrips() {
        let half = Double.pi / 6
        let q = Quaternion(w: cos(half), x: 0, y: sin(half), z: 0).normalized()
        let t = Transform(rotation: q, translation: Vector3(5, -2, 1))
        let p = Vector3(3, 4, -1)
        let roundTrip = t.inverse().apply(to: t.apply(to: p))
        XCTAssertEqual(roundTrip.x, p.x, accuracy: 1e-9)
        XCTAssertEqual(roundTrip.y, p.y, accuracy: 1e-9)
        XCTAssertEqual(roundTrip.z, p.z, accuracy: 1e-9)
    }

    func testTransformCompositionMatchesSequentialApplication() {
        let a = Transform(rotation: .identity, translation: Vector3(1, 0, 0))
        let b = Transform(rotation: .identity, translation: Vector3(0, 2, 0))
        let composed = a.composed(with: b)
        let p = Vector3(0, 0, 0)
        // a ∘ b applied to p == a.apply(b.apply(p))
        let viaComposed = composed.apply(to: p)
        let viaSequential = a.apply(to: b.apply(to: p))
        XCTAssertEqual(viaComposed, viaSequential)
        XCTAssertEqual(viaComposed.x, 1, accuracy: eps)
        XCTAssertEqual(viaComposed.y, 2, accuracy: eps)
    }
}
