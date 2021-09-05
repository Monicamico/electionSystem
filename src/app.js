App = {
    web3Provider: null,
    contracts: {},
    account: '0x0',
    loading: false,
    candidate: false, // true if the App.account is a candidate, have to deposit some souls (initial phase)
    canCast: false, // true if the App.account can cast the envelope (first phase)
    canOpen: false, // true if the App.account can open the envelope (second phase)
    canSetWinner: false, // true if the winner can be calculated
    deposited: true, // true if the App.account is a candidate that have already deposited some souls
    contractInstance: null,
    quorum: 0,
    escrow: '0x0',
    candidates_list: [],
  
    init: async () => {
      await App.initWeb3()
      await App.initContracts()
      await App.render()
    },
  
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
      const contract = await $.getJSON('Mayor.json') // get the contract JSON
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

      // Load escrow and candidates and show them in the HTML
      App.escrow = await App.contractInstance.getEscrow();
      $('#escrow').html(App.escrow)
      App.candidates_list = await App.contractInstance.getCandidates();
      var List = $('#candidates_list');
      $.each(App.candidates_list, function(val, text) {
          List.append(
            $('<p></p>').val(val).html(text)
          );
      });

      // check if the App.account is a candidate
      if (App.candidates_list.includes(App.account)) {
        // check if the candidate has already deposit
        const deposited_var = await App.contractInstance.hasDeposited(App.account);
        // set deposited or not, this also shows or hides the HTML section for the deposit
        App.setDeposited(deposited_var) 
      } else {
        // set as not a candidate
        App.setCandidate(false)
      }

      // check if is the first phase and the account can cast the envelope:
      // account has not already casted and the quorum is not reached yet
      App.canCast = await App.contractInstance.canCastEnvelope(App.account); 

      // check if is the second phase and the account can open the envelope:
      // account has already casted and the quorum is reached yet
      App.canOpen = await App.contractInstance.canOpenEnvelope(App.account);

      // check if is the third phase, the winner could be calculated
      App.canSetWinner = await App.contractInstance.canSetWinner();

      // check if the result can be shown, the winner has already be setted
      App.canSeeWinner = await App.contractInstance.canSeeWinner();
      if (App.canSeeWinner){
        App.setDeposited(true) // this because the candidate's deposit is empty because of the eth transfer but we need to hide the section deposit

        const winner = await App.contractInstance.seeWinner() // take the winner
        $('#winner_candidate').html(winner) // pass the value to the HTML
      }

      App.setOpen(App.canOpen) // show or hide the Open HTML section
      App.setCast(App.canCast) // show or hide the cast HTML section 
      App.setWinner(App.canSetWinner) // show or hide the set winner HTML section 
      App.showResults(App.canSeeWinner); // show or hide Result HTML section 

      App.setLoading(false)
    },
  
    // call the cast_envelope into the smart contract
    cast_envelope: async () => {
      App.setLoading(true)
      const sigil = $('#sigil').val()
      const candidate = $('#candidate').val()
      const soul = $('#soul1').val()
      if (soul == 0){
        window.alert('Soul must be greater than 0.')
      } else {
        // check if the candidate voted is into the candidates list
        if (App.candidates_list.includes(candidate)) {
          const soul_eth = web3.toWei(soul) // convert the eth in Wei
          //call the contract's function
          const envelope = await App.contractInstance.cast_envelope(sigil, candidate, soul_eth)
          App.setCast(false) //disabilita cast
          App.setLoading(false)
          window.alert('Envelope casted.')
        } else {
          App.setLoading(false)
          window.alert(candidate + ' is not a Candidate!')
        }
     }
    },

    // deposit some souls, called by a candidate
    deposit_soul: async () => {
      App.setLoading(true)
      const soul = $('#soul').val(); 
      const soul_eth = web3.toWei(soul) // convert the eth in Wei 
      if (soul == 0){
        window.alert('Soul must be greater than 0.')
      } else {
        // transfer the eths and call the deposit_soul in the smart contract
        const deposited = await App.contractInstance.deposit_soul.sendTransaction({value: soul_eth})
        App.setDeposited(true) // set deposited as true, hide the deposit HTML section 
        App.setLoading(false)
        window.alert('Souls deposited successfully.')
      }
    },

    open_envelope: async () => {
      App.setLoading(true)
      const sigil = $('#sigil_open').val()
      const candidate = $('#candidate_open').val()
      const soul = $('#soul_open').val()
      // check if is a candidate
      if (App.candidates_list.includes(candidate)) {
        const soul_eth = web3.toWei(soul)
        // send the eths and call the open_envelope in the smart contract
        const op = await App.contractInstance.open_envelope.sendTransaction(sigil,candidate, {value: soul_eth});
        App.setOpen(false) //disabilito open
        App.setLoading(false)
        window.alert('Envelope opened.')
      } else {
        App.setLoading(false)
        window.alert(candidate + ' is not a Candidate!')
      }
    },

    mayor_or_sayonara: async () => {
      App.setLoading(true)
      await App.contractInstance.mayor_or_sayonara() // calls the mayor_or_sayonara function in the smart contract
      window.alert('Winner setted.')
      App.showResults(true); //shows the winner
      App.setWinner(false); // hide the set winner section
      App.setLoading(false)
    },


    /* Functions to show or hide sections */

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