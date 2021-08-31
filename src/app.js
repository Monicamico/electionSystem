
App = {
    web3Provider: null,
    contracts: {},
    account: '0x0',
    loading: false,
    candidate: false,
    canCast: false,
    canOpen: false,
    canSetWinner: false,
    deposited: true,
    contractInstance: null,
    quorum: 0,
    escrow: '0x0',
    candidates_list: [],
  
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
  
    render: async() => {

      // Prevent double render
      if (App.loading) {
        return
      }

      App.setLoading(true)

      // Load smart contract
      const contract = await App.contracts.Mayor.deployed()
      App.contractInstance = contract

      // Set the current blockchain account
      App.account = web3.eth.accounts[0]
      $('#account').html(App.account) 

      // Load escrow and candidates
      App.escrow = await App.contractInstance.getEscrow();
      $('#escrow').html(App.escrow)
      App.candidates_list = await App.contractInstance.getCandidates();
      var mySelect1 = $('#candidates_list');
      $.each(App.candidates_list, function(val, text) {
          mySelect1.append(
            $('<p></p>').val(val).html(text)
          );
      });

      if (App.candidates_list.includes(App.account)) {
        var deposited_var = await App.contractInstance.hasDeposited(App.account);
        App.setDeposited(deposited_var)
      } else {
        App.setCandidate(false)
      }

      App.canCast = await App.contractInstance.canCastEnvelope(App.account);
      App.canOpen = await App.contractInstance.canOpenEnvelope(App.account);
      App.canSetWinner = await App.contractInstance.canSetWinner();
      App.canSeeWinner = await App.contractInstance.canSeeWinner();
      if (App.canSeeWinner){
        const winner = await App.contractInstance.seeWinner()
        $('#winner_candidate').html(winner)
      }
      App.setOpen(App.canOpen)
      App.setCast(App.canCast)
      App.setWinner(App.canSetWinner)
      App.showResults(App.canSeeWinner);
      App.setLoading(false)
    },
  
    cast_envelope: async () => {
      App.setLoading(true)
      const sigil = $('#sigil').val()
      const candidate = $('#candidate').val()
      const soul = $('#soul1').val()
      const envelope = await App.contractInstance.cast_envelope(sigil, candidate, soul)
      App.setCast(false) //disabilito cast
      App.setLoading(false)
      window.alert('Envelope casted.')
    },

    deposit_soul: async () => {
      App.setLoading(true)
      const soul = $('#soul').val()
      const deposited = await App.contractInstance.deposit_soul.sendTransaction({value: soul})
      App.setDeposited(true)
      App.setLoading(false)
      window.alert('Souls deposited successfully.')
    },

    open_envelope: async () => {
      App.setLoading(true)
      const sigil = $('#sigil_open').val()
      const candidate = $('#candidate_open').val()
      const soul = $('#soul_open').val()
      await App.contractInstance.open_envelope.sendTransaction(sigil,candidate, {value: soul})
      App.setOpen(false) //disabilito open
      App.setLoading(false)
      window.alert('Envelope opened.')
    },

    mayor_or_sayonara: async () => {
      App.setLoading(true)
      await App.contractInstance.mayor_or_sayonara()
      window.alert('Winner setted.')
      App.showResults(true);
      App.setWinner(false);
      App.setLoading(false)
    },

    setCandidate: (boolean) => {
      App.candidate = boolean
      const content = $('#is_candidate')
      if (boolean) {
        content.show()
      } else {
        content.hide()
      }
    },

    setDeposited: (boolean) => {
      App.deposited = boolean
      const content = $('#is_candidate')
      if (boolean) {
        content.hide()
      } else {
        content.show()
      }
    },

    setCast: (boolean) => {
      App.canCast = boolean
      const content = $('#cast')
      if (boolean) {
        content.show()
      } else {
        content.hide()
      }
    },

    setOpen: (boolean) => {
      App.canOpen = boolean
      const content = $('#open')
      if (boolean) {
        content.show()
      } else {
        content.hide()
      }
    },

    setWinner: (boolean) => {
      App.canSetWinner = boolean
      const content = $('#winner')
      if (boolean) {
        content.show()
      } else {
        content.hide()
      }
    },

    showResults: (boolean) => {
      App.canSeeWinner = boolean
      const content2 = $('#results')
      if (boolean) {
        content2.show()
      } else {
        content2.hide()
      }
    },
  
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