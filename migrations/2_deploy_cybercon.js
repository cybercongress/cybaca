var Cybercon = artifacts.require("Cybercon");


module.exports = async function(deployer, network, accounts) {
  deployer.deploy(Cybercon, { from: accounts[0]} );
};
