const { assert } = require("chai")
const _deploy_contracts = require("../migrations/1_initial_migration")

const Mayor = artifacts.require('Mayor.sol')

contract('Mayor', (accounts) => {
    it('Initializes contract', async() =>{
        const mayor = await Mayor.deployed()
    })
})