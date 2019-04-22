const VerifierUtil = artifacts.require("VerifierUtil");
const RockPaperScissorsPredicate = artifacts.require("RockPaperScissorsPredicate");
const {
  StateUpdate,
  Segment
} = require('@layer2/core')
const { constants, utils } = require('ethers')

class GamePredicateUtil {

  static encode(hex) {
    return utils.hexlify(utils.concat(hex.map(h => utils.padZeros(utils.arrayify(h), 32))))
  }

  static create(
    segment,
    blkNum,
    predicate,
    id,
    player1,
    player2,
    commit1,
    commit2,
    index
  ) {
    return new StateUpdate(
      segment,
      blkNum,
      predicate,
      GamePredicateUtil.encode([id, player1, player2, commit1, commit2, index])
    )
  }

}

contract("RockPaperScissorsPredicate", (accounts) => {

  const account1Key = '0xc87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3'
  const account2Key = '0xae6ae8e5ccbfb04590405997ee2d52d2b330726137b875053c36d94e974d162f'
  const account1Address = utils.computeAddress(account1Key)
  const account2Address = utils.computeAddress(account2Key)
  const segment = Segment.ETH(utils.bigNumberify(0), utils.bigNumberify(100))
  const secret1 = '0x0001020304'
  const secret2 = '0x0104030201'
  const stateUpdate = GamePredicateUtil.create(
    segment,
    utils.bigNumberify(10),
    constants.AddressZero,
    utils.bigNumberify(1),
    account1Address,
    account2Address,
    utils.keccak256(secret1),
    utils.keccak256(secret2),
    constants.One)

  it("succeed to canInitiateExit", async () => {
    const verifierUtil = await VerifierUtil.new()
    const rockPaperScissorsPredicate = await RockPaperScissorsPredicate.new(verifierUtil.address)
    await rockPaperScissorsPredicate.canInitiateExit(
      stateUpdate.hash(),
      stateUpdate.encode(),
      account1Address,
      Segment.ETH(utils.bigNumberify(0), utils.bigNumberify(100)).toBigNumber(), {
        from: accounts[0]
      })
  })

})
