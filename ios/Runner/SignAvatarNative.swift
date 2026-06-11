import Flutter
import SceneKit
import UIKit

// MARK: - Method channel bridge

final class SignAvatarController {
  static let shared = SignAvatarController()
  private weak var activeView: SignAvatarSceneView?

  func attach(_ view: SignAvatarSceneView) {
    activeView = view
  }

  func detach(_ view: SignAvatarSceneView) {
    if activeView === view {
      activeView = nil
    }
  }

  func playSign(_ signTokenId: String) {
    DispatchQueue.main.async { [weak self] in
      self?.activeView?.playSign(signTokenId)
    }
  }

  func setIdle() {
    DispatchQueue.main.async { [weak self] in
      self?.activeView?.setIdle()
    }
  }
}

final class SignAvatarMethodHandler: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.adesso.signbridge/sign_avatar",
      binaryMessenger: registrar.messenger()
    )
    let instance = SignAvatarMethodHandler()
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.register(
      SignAvatarViewFactory(messenger: registrar.messenger()),
      withId: "com.adesso.signbridge/sign_avatar_view"
    )
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "playSign":
      let args = call.arguments as? [String: Any]
      let signTokenId = args?["signTokenId"] as? String ?? "thinking"
      SignAvatarController.shared.playSign(signTokenId)
      result(nil)
    case "setIdle":
      SignAvatarController.shared.setIdle()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

// MARK: - Platform view

final class SignAvatarViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let params = args as? [String: Any]
    let signTokenId = params?["signTokenId"] as? String ?? "thinking"
    return SignAvatarPlatformView(frame: frame, signTokenId: signTokenId)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class SignAvatarPlatformView: NSObject, FlutterPlatformView {
  private let sceneView: SignAvatarSceneView

  init(frame: CGRect, signTokenId: String) {
    sceneView = SignAvatarSceneView(frame: frame)
    super.init()
    SignAvatarController.shared.attach(sceneView)
    if signTokenId == "thinking" {
      sceneView.setIdle()
    } else {
      sceneView.playSign(signTokenId)
    }
  }

  func view() -> UIView {
    sceneView
  }

  deinit {
    SignAvatarController.shared.detach(sceneView)
  }
}

// MARK: - SceneKit avatar

final class SignAvatarSceneView: SCNView {
  private let character = SignAvatarCharacter()

  override init(frame: CGRect, options: [String: Any]? = nil) {
    super.init(frame: frame, options: options)
    backgroundColor = UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1)
    allowsCameraControl = false
    autoenablesDefaultLighting = true
    antialiasingMode = .multisampling4X
    scene = character.scene
    pointOfView = character.cameraNode
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func playSign(_ signTokenId: String) {
    character.animate(signTokenId: signTokenId)
  }

  func setIdle() {
    character.animate(signTokenId: "thinking")
  }
}

final class SignAvatarCharacter {
  let scene = SCNScene()
  let cameraNode = SCNNode()
  private let leftUpper = SCNNode()
  private let rightUpper = SCNNode()
  private let leftLower = SCNNode()
  private let rightLower = SCNNode()

  init() {
    scene.rootNode.position = SCNVector3(0, -0.35, 0)

    let body = capsule(color: UIColor(red: 0, green: 0.43, blue: 0.78, alpha: 1), height: 0.9, radius: 0.18)
    body.position = SCNVector3(0, 0.55, 0)
    scene.rootNode.addChildNode(body)

    let head = sphere(color: UIColor(red: 1, green: 0.85, blue: 0.72, alpha: 1), radius: 0.16)
    head.position = SCNVector3(0, 1.15, 0)
    scene.rootNode.addChildNode(head)

    configureArm(upper: leftUpper, lower: leftLower, side: -1)
    configureArm(upper: rightUpper, lower: rightLower, side: 1)

    cameraNode.camera = SCNCamera()
    cameraNode.position = SCNVector3(0, 0.9, 2.4)
    cameraNode.look(at: SCNVector3(0, 0.7, 0))
    scene.rootNode.addChildNode(cameraNode)

    animate(signTokenId: "thinking")
  }

  private func configureArm(upper: SCNNode, lower: SCNNode, side: Float) {
    let upperGeo = capsule(color: UIColor(red: 1, green: 0.85, blue: 0.72, alpha: 1), height: 0.42, radius: 0.05)
    upper.geometry = upperGeo.geometry
    upper.position = SCNVector3(0.22 * side, 0.78, 0)
    upper.eulerAngles.z = Float.pi / 2 * side

    lower.geometry = capsule(color: UIColor(red: 1, green: 0.85, blue: 0.72, alpha: 1), height: 0.38, radius: 0.045).geometry
    lower.position = SCNVector3(0.22 * side, 0, 0)
    lower.eulerAngles.z = Float.pi / 2 * side
    upper.addChildNode(lower)

    scene.rootNode.addChildNode(upper)
  }

  func animate(signTokenId: String) {
    let pose = SignPoseLibrary.pose(signTokenId: signTokenId)
    SCNTransaction.begin()
    SCNTransaction.animationDuration = 0.42
    leftUpper.eulerAngles = SCNVector3(0, 0, pose.leftUpper)
    rightUpper.eulerAngles = SCNVector3(0, 0, pose.rightUpper)
    leftLower.eulerAngles = SCNVector3(0, 0, pose.leftLower)
    rightLower.eulerAngles = SCNVector3(0, 0, pose.rightLower)
    SCNTransaction.commit()
  }

  private func capsule(color: UIColor, height: CGFloat, radius: CGFloat) -> SCNNode {
    let node = SCNNode()
    node.geometry = SCNCapsule(capRadius: radius, height: height)
    node.geometry?.firstMaterial?.diffuse.contents = color
    return node
  }

  private func sphere(color: UIColor, radius: CGFloat) -> SCNNode {
    let node = SCNNode()
    node.geometry = SCNSphere(radius: radius)
    node.geometry?.firstMaterial?.diffuse.contents = color
    return node
  }
}

private struct SignPose {
  let leftUpper: Float
  let rightUpper: Float
  let leftLower: Float
  let rightLower: Float
}

private enum SignPoseLibrary {
  static func pose(signTokenId: String) -> SignPose {
    switch signTokenId {
    case "hello":
      return SignPose(leftUpper: -0.6, rightUpper: -1.8, leftLower: -0.35, rightLower: -0.7)
    case "how":
      return SignPose(leftUpper: -1.1, rightUpper: -1.1, leftLower: -0.6, rightLower: -0.6)
    case "you":
      return SignPose(leftUpper: -0.2, rightUpper: -1.4, leftLower: -0.25, rightLower: -0.15)
    case "today":
      return SignPose(leftUpper: -1.5, rightUpper: -0.5, leftLower: -0.9, rightLower: -0.2)
    case "thank_you":
      return SignPose(leftUpper: -0.9, rightUpper: -0.9, leftLower: -0.45, rightLower: -0.45)
    case "please":
      return SignPose(leftUpper: -1.3, rightUpper: -0.55, leftLower: -0.65, rightLower: -0.15)
    case "help":
      return SignPose(leftUpper: -1.7, rightUpper: -0.25, leftLower: -1.0, rightLower: -0.05)
    case "yes":
      return SignPose(leftUpper: -0.35, rightUpper: -1.75, leftLower: -0.15, rightLower: -0.5)
    case "no":
      return SignPose(leftUpper: -1.75, rightUpper: -1.75, leftLower: -0.95, rightLower: -0.95)
    default:
      return SignPose(leftUpper: -0.3, rightUpper: 0.3, leftLower: -0.4, rightLower: 0.4)
    }
  }
}
