var Mayor = artifacts.require("./Mayor.sol");

module.exports = function(deployer) {
    deployer.deploy(Mayor,["0x833700c76bf68274849A6bC4977Ce588e7B874Ec","0x39b0E6CA16cebFF0A2A89832287Cb590D48cF0A3"],"0xc23C007aCF301E600b65ED97fA8E7A3b3A8517FE",5);
};