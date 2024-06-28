//
//  GameScene.swift
//  SpaceGame
//
//  Created by Dmytro Chumakov on 24.06.2024.
//

import SpriteKit
import GameplayKit
import CoreMotion

final class GameScene: SKScene {

    private var starfield: SKEmitterNode!
    private var player: SKSpriteNode!
    private var motionManager: CMMotionManager!

    private var xAcceleration: CGFloat = 0

    private var scoreLabel: SKLabelNode!
    private var score: Int = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }

    private var gameTimer: Timer!
    private var possibleAliens = ["alien", "alien2", "alien3"]

    private let alienCategory: UInt32 = 0x1 << 1
    private let photonTorpedoCategory: UInt32 = 0x1 << 0

    override func didMove(to view: SKView) {
        self.starfield = SKEmitterNode(fileNamed: "Starfield")
        starfield.position = CGPoint(x: self.frame.size.width / 2, y: self.frame.size.height)
        starfield.advanceSimulationTime(10)

        self.addChild(starfield)

        starfield.zPosition = -1

        self.player = SKSpriteNode(imageNamed: "shuttle")
        player.position = CGPoint(x: self.frame.size.width / 2, y: player.size.height / 2 + 20)

        self.addChild(player)

        self.physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        self.physicsWorld.contactDelegate = self

        self.scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel.position = CGPoint(x: self.frame.size.width / 2, y: self.frame.size.height - 50)
        scoreLabel.fontName = "AmericanTypewriter-Bold"
        scoreLabel.fontSize = 36
        scoreLabel.fontColor = UIColor.white
        score = 0

        self.addChild(scoreLabel)

        self.gameTimer = Timer.scheduledTimer(timeInterval: 0.75, target: self, selector: #selector(addAlien), userInfo: nil, repeats: true)

        self.motionManager = CMMotionManager()
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: OperationQueue.current!) { (data: CMAccelerometerData?, error: Error?) in
            if let accelerometerData = data {
                let acceleration = accelerometerData.acceleration
                self.xAcceleration = CGFloat(acceleration.x) * 0.75 + self.xAcceleration * 0.25
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        fireTorpedo()
    }

    override func didSimulatePhysics() {
        player.position.x += xAcceleration * 50

        if player.position.x < 0 {
            player.position = CGPoint(x: self.frame.size.width, y: player.position.y)
        } else if player.position.x > self.frame.size.width {
            player.position = CGPoint(x: 0, y: player.position.y)
        }
    }

}

// MARK: - SKPhysicsContactDelegate
extension GameScene: SKPhysicsContactDelegate {

    func didBegin(_ contact: SKPhysicsContact) {
        var firstBody: SKPhysicsBody
        var secondBody: SKPhysicsBody

        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }

        if (firstBody.categoryBitMask & photonTorpedoCategory) != 0 && (secondBody.categoryBitMask & alienCategory) != 0 {
            torpedoDidCollideWithAlien(torpedoNode: firstBody.node as! SKSpriteNode, alienNode: secondBody.node as! SKSpriteNode)
        }
    }

}

// MARK: - Actions
private extension GameScene {

    @objc func addAlien() {
        possibleAliens = GKRandomSource.sharedRandom().arrayByShufflingObjects(in: possibleAliens) as! [String]
        let allien = SKSpriteNode(imageNamed: possibleAliens[0])
        let randomAlienPosition = GKRandomDistribution(lowestValue: 0, highestValue: Int(self.frame.size.width))
        let position = CGFloat(randomAlienPosition.nextInt())

        allien.position = CGPoint(x: position, y: self.frame.size.height + allien.size.height)
        allien.physicsBody = SKPhysicsBody(rectangleOf: allien.size)
        allien.physicsBody?.isDynamic = true

        allien.physicsBody?.categoryBitMask = alienCategory
        allien.physicsBody?.contactTestBitMask = photonTorpedoCategory
        allien.physicsBody?.collisionBitMask = 0

        self.addChild(allien)

        let animationDuration: TimeInterval = 6
        var actionArray = [SKAction]()
        actionArray.append(SKAction.move(to: CGPoint(x: position, y: -allien.size.height), duration: animationDuration))
        actionArray.append(SKAction.removeFromParent())
        allien.run(SKAction.sequence(actionArray))
    }

    func fireTorpedo() {
        self.run(SKAction.playSoundFileNamed("torpedo.mp3", waitForCompletion: false))

        let torpedoNode = SKSpriteNode(imageNamed: "torpedo")
        torpedoNode.position = player.position
        torpedoNode.position.y += 5

        torpedoNode.physicsBody = SKPhysicsBody(circleOfRadius: torpedoNode.size.width / 2)
        torpedoNode.physicsBody?.isDynamic = true

        torpedoNode.physicsBody?.categoryBitMask = photonTorpedoCategory
        torpedoNode.physicsBody?.contactTestBitMask = alienCategory
        torpedoNode.physicsBody?.collisionBitMask = 0
        torpedoNode.physicsBody?.usesPreciseCollisionDetection = true

        self.addChild(torpedoNode)

        let animationDuration: TimeInterval = 0.3

        var actionArray = [SKAction]()
        actionArray.append(SKAction.move(to: CGPoint(x: player.position.x, y: self.frame.size.height + 10), duration: animationDuration))
        actionArray.append(SKAction.removeFromParent())
        torpedoNode.run(SKAction.sequence(actionArray))
    }

    func torpedoDidCollideWithAlien(torpedoNode: SKSpriteNode, alienNode: SKSpriteNode) {
        let explosion = SKEmitterNode(fileNamed: "Explosion")!
        explosion.position = alienNode.position
        self.addChild(explosion)

        self.run(SKAction.playSoundFileNamed("explosion.mp3", waitForCompletion: false))

        torpedoNode.removeFromParent()
        alienNode.removeFromParent()

        self.run(SKAction.wait(forDuration: 2)) {
            explosion.removeFromParent()
        }

        score += 5
    }

}
