const Mountain = artifacts.require("Mountain");

module.exports = function (deployer, network, accounts) {
  deployer.deploy(Mountain, [accounts[6], accounts[7],accounts[8], accounts[9]]);
};
