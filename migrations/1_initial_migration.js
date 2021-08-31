const Migrations = artifacts.require("Migrations");
const Mayor = artifacts.require("./Mayor.sol");

module.exports = async function (deployer) {
  deployer.deploy(Migrations);
  var account_list = []
  account_list = await web3.eth.getAccounts()
  deployer.deploy(Mayor,[account_list[2]],account_list[4],1);
};
