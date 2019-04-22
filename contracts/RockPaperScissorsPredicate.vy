struct Game:
  participant1: address
  participant2: address
  commit1: bytes32
  commit2: bytes32
  segment1: uint256
  segment2: uint256
  tokenAddress1: address
  tokenAddress2: address
  amount1: uint256
  amount2: uint256
  withdrawableAt: uint256

#
# Library
#

contract VerifierUtil():
  def ecrecoverSig(
    _txHash: bytes32,
    _sig: bytes[260],
    index: int128
  ) -> address: constant
  def parseSegment(
    segment: uint256
  ) -> (uint256, uint256, uint256): constant
  def isContainSegment(
    segment: uint256,
    small: uint256
  ) -> (bool): constant

contract ERC20:
  def transferFrom(_from: address, _to: address, _value: uint256) -> bool: modifying
  def transfer(_to: address, _value: uint256) -> bool: modifying

verifierUtil: public(address)
channels: map(uint256, Game)

# @dev Constructor
@public
def __init__(_verifierUtil: address):
  self.verifierUtil = _verifierUtil

@public
@constant
def decodeOwnershipState(
  stateBytes: bytes[288]
) -> (uint256, uint256, address):
  # assert self == extract32(stateBytes, 0, type=address)
  return (
    extract32(stateBytes, 32*1, type=uint256),  # blkNum
    extract32(stateBytes, 32*2, type=uint256),  # segment
    extract32(stateBytes, 32*3, type=address)   # owner
  )

@public
@constant
def decodeGameState(
  stateBytes: bytes[288]
) -> (uint256, uint256, uint256, address, address, bytes32, bytes32, uint256):
  return (
    extract32(stateBytes, 32*1, type=uint256),  # blkNum
    extract32(stateBytes, 32*2, type=uint256),  # segment
    extract32(stateBytes, 32*3, type=uint256),  # chId
    extract32(stateBytes, 32*4, type=address),  # player 1
    extract32(stateBytes, 32*5, type=address),  # player 2
    extract32(stateBytes, 32*6, type=bytes32),  # commit 1
    extract32(stateBytes, 32*7, type=bytes32),  # commit 2
    extract32(stateBytes, 32*8, type=uint256)   # index
  )

@public
@constant
def canInitiateExit(
  _txHash: bytes32,
  _stateUpdate: bytes[288],
  _owner: address,
  _segment: uint256
) -> (bool):
  blkNum: uint256
  segment: uint256
  chId: uint256
  player1: address
  player2: address
  commit1: bytes32
  commit2: bytes32
  index: uint256
  (blkNum, segment, chId, player1, player2, commit1, commit2, index) = self.decodeGameState(_stateUpdate)
  if _owner != ZERO_ADDRESS:
    assert _owner == player1 or _owner == player2
  assert VerifierUtil(self.verifierUtil).isContainSegment(segment, _segment)
  return True

@public
@constant
def verifyDeprecation(
  _txHash: bytes32,
  _stateBytes: bytes[288],
  _nextStateUpdate: bytes[288],
  _transactionWitness: bytes[65],
  _timestamp: uint256
) -> (bool):
  blkNum: uint256
  exitSegment: uint256
  chId: uint256
  player1: address
  player2: address
  commit1: bytes32
  commit2: bytes32
  index: uint256
  challengeSegment: uint256
  challengeBlkNum: uint256
  challengeOwner: address
  (blkNum, exitSegment, chId, player1, player2, commit1, commit2, index) = self.decodeGameState(_stateBytes)
  (challengeBlkNum, challengeSegment, challengeOwner) = self.decodeOwnershipState(_nextStateUpdate)
  secret1: bytes32 = extract32(_transactionWitness, 0, type=bytes32)
  secret2: bytes32 = extract32(_transactionWitness, 32, type=bytes32)
  choice1: uint256 = convert(slice(secret1, start=0, len=1), uint256)  
  choice2: uint256 = convert(slice(secret2, start=0, len=1), uint256)  
  if choice1 == choice2:
    if index == 1:
      assert challengeOwner == player1
    elif index == 2:
      assert challengeOwner == player2
  else:
    # 0: rock, 1: paper, 2: scissor
    if (choice1 == 0 and choice2 == 1) or (choice1 == 1 and choice2 == 2) or (choice1 == 2 and choice2 == 0):
      # player 1 win
      assert challengeOwner == player1
    elif (choice1 == 0 and choice2 == 2) or (choice1 == 1 and choice2 == 0) or (choice1 == 2 and choice2 == 1):
      # player 2 win
      assert challengeOwner == player2
  assert VerifierUtil(self.verifierUtil).isContainSegment(exitSegment, challengeSegment)
  assert sha3(secret1) == commit1
  assert sha3(secret2) == commit2
  return True

@public
def finalizeExit(
  _stateBytes: bytes[288],
  _tokenAddress: address,
  _amount: uint256
):
  blkNum: uint256
  exitSegment: uint256
  chId: uint256
  player1: address
  player2: address
  commit1: bytes32
  commit2: bytes32
  index: uint256
  tokenId: uint256
  start: uint256
  end: uint256
  (blkNum, exitSegment, chId, player1, player2, commit1, commit2, index) = self.decodeGameState(_stateBytes)
  self.channels[chId] = Game({
    participant1: player1,
    participant2: player2,
    commit1: commit1,
    commit2: commit2,
    segment1: 0,
    segment2: 0,
    tokenAddress1: ZERO_ADDRESS,
    tokenAddress2: ZERO_ADDRESS,
    amount1: 0,
    amount2: 0,
    withdrawableAt: as_unitless_number(block.timestamp) + 60 * 60 * 24 * 3
  })
  if index == 1:
    assert self.channels[chId].amount1 == 0
    self.channels[chId].segment1 = exitSegment
    self.channels[chId].tokenAddress1 = _tokenAddress
    self.channels[chId].amount1 = _amount
  elif index == 2:
    assert self.channels[chId].amount2 == 0
    self.channels[chId].segment2 = exitSegment
    self.channels[chId].tokenAddress2 = _tokenAddress
    self.channels[chId].amount2 = _amount
  else:
    pass
