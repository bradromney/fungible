import XCTest
import FungibleDomain
@testable import FungibleRegistration

final class RigidAlignmentTests: XCTestCase {
    // A spread-out, non-degenerate source cloud.
    private let source: [Vector3] = [
        Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 2, 0),
        Vector3(0, 0, 3), Vector3(1, 2, 3), Vector3(-1, 1, 2),
    ]

    private func assertRecovers(_ truth: Transform, accuracy: Double = 1e-4) {
        let target = source.map { truth.apply(to: $0) }
        let fit = RigidAlignment.align(source: source, target: target)
        let t = XCTUnwrap_(fit)
        // Compare by how well the fit maps source onto target (sign-robust).
        for i in source.indices {
            let got = t.apply(to: source[i])
            XCTAssertEqual(got.x, target[i].x, accuracy: accuracy)
            XCTAssertEqual(got.y, target[i].y, accuracy: accuracy)
            XCTAssertEqual(got.z, target[i].z, accuracy: accuracy)
        }
    }

    private func XCTUnwrap_(_ t: Transform?) -> Transform {
        guard let t else { XCTFail("alignment returned nil"); return .identity }
        return t
    }

    func testRecoversPureTranslation() {
        assertRecovers(Transform(translation: Vector3(5, -2, 7)))
    }

    func testRecoversRotationAboutY() {
        let half = Double.pi / 6 // 60° rotation, half-angle 30°
        let q = Quaternion(w: cos(half), x: 0, y: sin(half), z: 0).normalized()
        assertRecovers(Transform(rotation: q, translation: .zero))
    }

    func testRecoversRotationPlusTranslation() {
        let half = Double.pi / 5
        let q = Quaternion(w: cos(half), x: sin(half) * 0.3, y: sin(half) * 0.8, z: sin(half) * 0.5).normalized()
        assertRecovers(Transform(rotation: q, translation: Vector3(-3, 4, 1)))
    }

    func testIdentityForCoincidentClouds() {
        let fit = XCTUnwrap_(RigidAlignment.align(source: source, target: source))
        for p in source {
            let got = fit.apply(to: p)
            XCTAssertEqual(got.distance(to: p), 0, accuracy: 1e-6)
        }
    }

    func testRejectsMismatchedOrTinyInput() {
        XCTAssertNil(RigidAlignment.align(source: source, target: Array(source.dropLast())))
        XCTAssertNil(RigidAlignment.align(source: [Vector3(0, 0, 0)], target: [Vector3(1, 1, 1)]))
    }
}
