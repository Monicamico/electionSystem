App = {
    web3Provider: null,
    contracts: {},
    account: '0x0',
    loading: false,
    contractInstance: null,
  
    init: async () => {
      await App.initWeb3()
      await App.initContracts()
      await App.render()
    },
  
    // https://medium.com/metamask/https-medium-com-metamask-breaking-change-injecting-web3-7722797916a8
    initWeb3: async () => {
      if (typeof web3 !== 'undefined') {
        App.web3Provider = web3.currentProvider
        web3 = new Web3(web3.currentProvider)
      } else {
        window.alert("Please connect to Metamask.")
      }
      // Modern dapp browsers...
      if (window.ethereum) {
        window.web3 = new Web3(ethereum)
        try {
          // Request account access if needed
          await ethereum.enable()
          // Acccounts now exposed
          web3.eth.sendTransaction({/* ... */})
        } catch (error) {
          // User denied account access...
        }
      }
      // Legacy dapp browsers...
      else if (window.web3) {
        App.web3Provider = web3.currentProvider
        window.web3 = new Web3(web3.currentProvider)
        // Acccounts always exposed
        web3.eth.sendTransaction({/* ... */})
      }
      // Non-dapp browsers...
      else {
        console.log('Non-Ethereum browser detected. You should consider trying MetaMask!')
      }
      web3.eth.defaultAccount=web3.eth.accounts[0] //https://ethereum.stackexchange.com/questions/1740/why-does-mist-throw-uncaught-invalid-address
    },
  
    initContracts: async () => {
      const contract = await $.getJSON('Mayor.json')
      App.contracts.Mayor = TruffleContract(contract)
      App.contracts.Mayor.setProvider(App.web3Provider)
    },
  
    render: async () => {
      // Prevent double render
      if (App.loading) {
        return
      }
  
      // Update app loading state
      App.setLoading(true)
  
      // Set the current blockchain account
      App.account = web3.eth.accounts[0]
      $('#account').html(App.account)
  
      // Load smart contract
      const contract = await App.contracts.Mayor.deployed()
      App.contractInstance = contract
      const escrow = await App.contractInstance.getEscrow();
      $('#escrow').html(escrow)
      const candidates = await App.contractInstance.getCandidates();
      $('#candidates').html(candidates)
      App.setLoading(false)
    },
  
    /*set: async () => {
      App.setLoading(true)
      const newValue = $('#newValue').val()
      await App.contractInstance.set(newValue)
      window.alert('Value updated! Refresh this page to see the new value (it might take a few seconds).')
    },*/
  
    setLoading: (boolean) => {
      App.loading = boolean
      const loader = $('#loader')
      const content = $('#content')
      if (boolean) {
        loader.show()
        content.hide()
      } else {
        loader.hide()
        content.show()
      }
    }
  }
  
  $(() => {
    $(window).load(() => {
      App.init()
    })
  })