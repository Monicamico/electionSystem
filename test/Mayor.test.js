const { assert } = require("chai")
const _deploy_contracts = require("../migrations/2_deploy_contracts")

const Mayor = artifacts.require('Mayor.sol')

contract('Mayor', (accounts) => {
    it('Initializes with the correct value', async() =>{
        const mayor = await Mayor.deployed()
        const value = await mayor.get()
        assert.equal(value, 'myValue')
        await mayor.set("c")
        const value_new = await mayor.get()
        assert.equal(value_new, "c")
    })
})