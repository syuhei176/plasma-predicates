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

# @dev Constructor
@public
def __init__(_verifierUtil: address):
  self.verifierUtil = _verifierUtil

@public
@constant
def decodeOwnershipState(
  stateBytes: bytes[256]
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
  stateBytes: bytes[256]
) -> (uint256, uint256, address, address, bytes32, bytes32, uint256):
  return (
    extract32(stateBytes, 32*1, type=uint256),  # blkNum
    extract32(stateBytes, 32*2, type=uint256),  # segment
    extract32(stateBytes, 32*3, type=address),  # player 1
    extract32(stateBytes, 32*4, type=address),  # player 2
    extract32(stateBytes, 32*5, type=bytes32),  # commit 1
    extract32(stateBytes, 32*6, type=bytes32),  # commit 2
    extract32(stateBytes, 32*7, type=uint256)   # index
  )

@public
@constant
def canInitiateExit(
  _txHash: bytes32,
  _stateUpdate: bytes[256],
  _owner: address,
  _segment: uint256
) -> (bool):
  blkNum: uint256
  segment: uint256
  player1: address
  player2: address
  commit1: bytes32
  commit2: bytes32
  index: uint256
  (blkNum, segment, player1, player2, commit1, commit2, index) = self.decodeGameState(_stateUpdate)
  if _owner != ZERO_ADDRESS:
    assert _owner == player1 or _owner == player2
  assert VerifierUtil(self.verifierUtil).isContainSegment(segment, _segment)
  return True

@public
@constant
def verifyDeprecation(
  _txHash: bytes32,
  _stateBytes: bytes[256],
  _nextStateUpdate: bytes[256],
  _transactionWitness: bytes[65],
  _timestamp: uint256
) -> (bool):
  blkNum: uint256
  exitSegment: uint256
  player1: address
  player2: address
  commit1: bytes32
  commit2: bytes32
  index: uint256
  challengeSegment: uint256
  challengeBlkNum: uint256
  challengeOwner: address
  (blkNum, exitSegment, player1, player2, commit1, commit2, index) = self.decodeGameState(_stateBytes)
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
  _stateBytes: bytes[256],
  _tokenAddress: address,
  _amount: uint256
):
  blkNum: uint256
  exitSegment: uint256
  player1: address
  player2: address
  commit1: bytes32
  commit2: bytes32
  index: uint256
  tokenId: uint256
  start: uint256
  end: uint256
  (blkNum, exitSegment, player1, player2, commit1, commit2, index) = self.decodeGameState(_stateBytes)
