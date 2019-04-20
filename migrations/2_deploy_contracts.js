const VerifierUtil = artifacts.require("VerifierUtil");
const RockPaperScissorsPredicate = artifacts.require("RockPaperScissorsPredicate");

module.exports = function(deployer) {
  deployer.deploy(VerifierUtil).then(() => deployer.deploy(RockPaperScissorsPredicate, VerifierUtil.address))
}
