# from https://github.com/cryptoeconomicslab/plasma-chamber/tree/master/packages/contracts/contracts/library

MASK8BYTES: constant(uint256) = 2**64 - 1

# @dev from https://github.com/LayerXcom/plasma-mvp-vyper
@public
@constant
def ecrecoverSig(_txHash: bytes32, _sig: bytes[260], index: int128) -> address:
  if len(_sig) % 65 != 0:
    return ZERO_ADDRESS
  # ref. https://gist.github.com/axic/5b33912c6f61ae6fd96d6c4a47afde6d
  # The signature format is a compact form of:
  # {bytes32 r}{bytes32 s}{uint8 v}
  r: uint256 = extract32(_sig, 0 + 65 * index, type=uint256)
  s: uint256 = extract32(_sig, 32+ 65 * index, type=uint256)
  v: int128 = convert(slice(_sig, start=64 + 65 * index, len=1), int128)
  # Version of signature should be 27 or 28, but 0 and 1 are also possible versions.
  # geth uses [0, 1] and some clients have followed. This might change, see:
  # https://github.com/ethereum/go-ethereum/issues/2053
  if v < 27:
    v += 27
  if v in [27, 28]:
    return ecrecover(_txHash, convert(v, uint256), r, s)
  return ZERO_ADDRESS

@public
@constant
def parseSegment(
  segment: uint256
) -> (uint256, uint256, uint256):
  tokenId: uint256 = bitwise_and(shift(segment, - 16 * 8), MASK8BYTES)
  start: uint256 = bitwise_and(shift(segment, - 8 * 8), MASK8BYTES)
  end: uint256 = bitwise_and(segment, MASK8BYTES)
  return (tokenId, start, end)

@public
@constant
def encodeSegment(
  tokenId: uint256,
  start: uint256,
  end: uint256
) -> uint256:
  return tokenId * (2 ** 128) + start * (2 ** 64) + end

@public
@constant
def isContainSegment(
  segment: uint256,
  small: uint256
) -> (bool):
  tokenId1: uint256
  start1: uint256
  end1: uint256
  tokenId2: uint256
  start2: uint256
  end2: uint256
  (tokenId1, start1, end1) = self.parseSegment(segment)
  (tokenId2, start2, end2) = self.parseSegment(small)
  assert tokenId1 == tokenId2 and start1 <= start2 and end2 <= end1
  return True

@public
@constant
def hasInterSection(
  segment1: uint256,
  segment2: uint256
) -> (uint256, uint256, uint256):
  tokenId1: uint256
  start1: uint256
  end1: uint256
  tokenId2: uint256
  start2: uint256
  end2: uint256
  (tokenId1, start1, end1) = self.parseSegment(segment1)
  (tokenId2, start2, end2) = self.parseSegment(segment2)
  assert tokenId1 == tokenId2 and start1 < end2 and start2 < end1
  return (tokenId1, start1, end1)
