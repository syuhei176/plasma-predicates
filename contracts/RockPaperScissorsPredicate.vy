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
def decodeState(
  stateBytes: bytes[256]
) -> (uint256, uint256):
  # assert self == extract32(stateBytes, 0, type=address)
  return (
    extract32(stateBytes, 32*1, type=uint256),  # blkNum
    extract32(stateBytes, 32*2, type=uint256)   # segment
  )

@public
@constant
def decodeGameState(
  stateBytes: bytes[256]
) -> (uint256, uint256, address, address, bytes32, bytes32):
  return (
    extract32(stateBytes, 32*1, type=uint256),  # blkNum
    extract32(stateBytes, 32*2, type=uint256),  # segment
    extract32(stateBytes, 32*3, type=address),  # player 1
    extract32(stateBytes, 32*4, type=address),  # player 2
    extract32(stateBytes, 32*5, type=bytes32),  # commit 1
    extract32(stateBytes, 32*6, type=bytes32)   # commit 2
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
  (blkNum, segment, player1, player2, commit1, commit2) = self.decodeGameState(_stateUpdate)
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
  challengeSegment: uint256
  challengeBlkNum: uint256
  (blkNum, exitSegment, player1, player2, commit1, commit2) = self.decodeGameState(_stateBytes)
  (challengeBlkNum, challengeSegment) = self.decodeState(_nextStateUpdate)
  assert VerifierUtil(self.verifierUtil).isContainSegment(exitSegment, challengeSegment)
  assert sha3(extract32(_transactionWitness, 0, type=bytes32)) == commit1
  assert sha3(extract32(_transactionWitness, 32, type=bytes32)) == commit2
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
  tokenId: uint256
  start: uint256
  end: uint256
  (blkNum, exitSegment, player1, player2, commit1, commit2) = self.decodeGameState(_stateBytes)
