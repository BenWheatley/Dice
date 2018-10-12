//
//  ViewController.swift
//  Dice
//
//  Created by Ben Wheatley on 2018/09/27.
//  Copyright © 2018 Ben Wheatley. All rights reserved.
//

import UIKit

private let reuseIdentifier = "DiceCell"

class DiceCollectionViewController: UICollectionViewController {

	static var dice = [0,3,4,2,5,1]
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
	}
	
	override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return DiceCollectionViewCell.dice.count
	}
	
	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! DiceCollectionViewCell
		cell.indexPath = indexPath
		cell.roll = DiceCollectionViewController.dice[indexPath.row]
		return cell
	}
	
	override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
		if (event?.subtype == UIEvent.EventSubtype.motionShake) {
			for i in 0..<DiceCollectionViewController.dice.count {
				DiceCollectionViewController.dice[i] = Int(arc4random_uniform(UInt32(DiceCollectionViewCell.dice.count)))
			}
			for cell in self.collectionView!.visibleCells {
				guard let dice = cell as? DiceCollectionViewCell else {
					continue
				}
				dice.recursiveDiceAnimation(ultimateTarget: dice.roll)
			}
		}
	}
}

class DiceCollectionViewCell: UICollectionViewCell {
	static let dice = [#imageLiteral(resourceName: "1"), #imageLiteral(resourceName: "2"), #imageLiteral(resourceName: "3"), #imageLiteral(resourceName: "4"), #imageLiteral(resourceName: "5"), #imageLiteral(resourceName: "6")]
	
	var roll = 0 {
		didSet {
			diceButton.setImage(DiceCollectionViewCell.dice[roll], for: UIControl.State.normal)
			if let row = indexPath?.row {
				DiceCollectionViewController.dice[row] = roll
			}
		}
	}
	var indexPath:IndexPath? = nil
	
	@IBOutlet weak var diceButton: UIButton!
	
	@IBAction func reroll(_ sender: Any) {
		let r = Int(arc4random_uniform(UInt32(DiceCollectionViewCell.dice.count)))
		
		recursiveDiceAnimation(ultimateTarget: r)
	}
	
	func recursiveDiceAnimation(ultimateTarget: Int, stepsRemaining:Int = Constants.rollingAnimationSteps) {
		UIView.animate(
			withDuration: Constants.finalRollAnimationTime / pow(Constants.ithRollAnimationDecayConstant, 1.0+Double(stepsRemaining)),
			delay: 0.0,
			options: .curveLinear,
			animations: {
				print("this roll = \(self.roll), stepsRemaining = \(stepsRemaining)")
				self.roll = stepsRemaining==0 ?
					ultimateTarget :
					Int(arc4random_uniform(UInt32(DiceCollectionViewCell.dice.count)))
				let angle = CGFloat.pi
				self.diceButton.transform = self.diceButton.transform.rotated(by: angle)
			},
			completion: { finished in
				if finished {
					if (stepsRemaining>0) {
						self.recursiveDiceAnimation(ultimateTarget: ultimateTarget,
													stepsRemaining: stepsRemaining-1)
					}
				}
		})
	}
	
	struct Constants {
		static let rollingAnimationSteps = 5
		static let finalRollAnimationTime: TimeInterval = 0.6
		static let ithRollAnimationDecayConstant = 1.3
	}
}
