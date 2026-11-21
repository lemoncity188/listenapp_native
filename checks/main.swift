import Foundation
struct Vector: Decodable { let plain: String; let base64: String }
let vectors = try JSONDecoder().decode([Vector].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
for vector in vectors { let actual = try encrypt(vector.plain); precondition(actual == vector.base64, "Android AES format mismatch") }
precondition(boundedSeek(-5, duration: 30) == 0)
precondition(boundedSeek(35, duration: 30) == 30)
precondition(boundedSeek(35, duration: 0) == 35)
precondition(boundedSeek(.nan, duration: 30) == 0)
precondition(ABSegment(APos: 0, BPos: 1).valid)
precondition(!ABSegment(APos: 2, BPos: 1).valid)
precondition(!ABSegment(APos: -1, BPos: 1).valid)
precondition(!ABSegment(APos: 1, BPos: .infinity).valid)
print("PASS: native Swift crypto fixtures and playback boundary rules")
