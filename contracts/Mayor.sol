// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract Mayor {
    
    struct Refund {
        uint soul;
        address candidate_symbol;
    }

    struct ElectorsResult {
        address payable[] winners;
        address payable[] losers;
    }

    struct Vote {
        uint souls;
        uint number;
    }

    struct Conditions {
        uint32 quorum;
        uint32 envelopes_casted;
        uint32 envelopes_opened;
        uint256 candidates_deposit_soul;
        uint256 candidates_number;
        bool winnerChecked;
    }

    event NewMayor(address _candidate); 
    event Deposited(address _candidate);
    event Sayonara(address _escrow);
    event Tie(address _escrow);
    event EnvelopeCast(address _voter);
    event EnvelopeOpen(address _voter, uint _soul, address candidate_symbol);

    modifier canVote() {
        require(voting_condition.envelopes_casted < voting_condition.quorum, "Cannot vote now, voting quorum has been reached");
        require(voting_condition.candidates_deposit_soul == voting_condition.candidates_number, "Cannot vote now, all candidates must deposit some soul");
        _;   
    }
    
    modifier canOpen() {
        require(voting_condition.envelopes_casted == voting_condition.quorum,"Cannot open an envelope, voting quorum not reached yet");
        _;
    }
    
    modifier canCheckOutcome() {
        require(voting_condition.envelopes_opened == voting_condition.quorum, "Cannot  check the winner, need to open all the sent envelopes");
        _;
    }
    
    address payable[] public candidates;
    address payable public escrow;
    mapping(address => bytes32) public envelopes;
    mapping(address => uint) public deposit; //it represent the candidates' deposit
    mapping(address => bool) public envelopes_opened;
    Conditions public voting_condition;
    mapping(address => Vote) public votes; //map one candidate to votes received (souls, numbers)
    mapping(address => Refund) public souls;
    address payable[] public voters; //all electors that have voted
    address payable winner;
    ElectorsResult results; //two lists: electors that have voted for the winner and others, useful in no tie case

    constructor(address payable[] memory _candidates, address payable _escrow, uint32 _quorum) {
        candidates = _candidates;
        escrow = _escrow;
        voting_condition = Conditions({quorum: _quorum, 
                                    envelopes_casted: 0,
                                    candidates_deposit_soul: 0,
                                    envelopes_opened: 0,
                                    candidates_number: _candidates.length,
                                    winnerChecked: false });
        for (uint i =0; i < candidates.length; i++){
            deposit[candidates[i]] = 0; //initialize the deposit
            // initialize the votes structure
            votes[candidates[i]].souls = 0; 
            votes[candidates[i]].number = 0;
        }
    }

    /*-------------------------------- Functions to get the state of the contract --------------------------------*/

    function getEscrow() public view returns(address payable) {
        return escrow;
    }

    function getCandidates() public view returns(address payable[] memory){
        return candidates;
    }

    function seeWinner() public view returns(address payable){
        require(voting_condition.winnerChecked == true);
        return winner;
    }

    function hasDeposited(address account) public view returns(bool){
        if (deposit[account] > 0) 
            return true;
        return false;
    }

    function canCastEnvelope(address account) public view returns(bool){
        bool boolean = (voting_condition.candidates_deposit_soul == voting_condition.candidates_number)
                        && (voting_condition.envelopes_casted < voting_condition.quorum) 
                        && (envelopes[account] == 0x0);
        return boolean;
    }

    function canOpenEnvelope(address account) public view returns(bool){
        bool boolean = (voting_condition.envelopes_casted == voting_condition.quorum) 
                        && (envelopes[account] != 0x0) && (envelopes_opened[account] == false);
        return boolean;
    }

    function canSetWinner() public view returns(bool){
        bool boolean = (voting_condition.envelopes_opened == voting_condition.quorum) && (voting_condition.winnerChecked == false);
        return boolean;
    }

    function canSeeWinner() public view returns(bool){
        bool boolean = (voting_condition.winnerChecked == true);
        return boolean;
    }

    /*-------------------------------- Utility Functions --------------------------------*/

    // Insert soul into the deposit, can be called only by a candidate
    function deposit_soul() public payable {
        bool is_candidate = false;
        for (uint i =0; i < candidates.length; i++){
            if (candidates[i] == msg.sender)
                is_candidate = true;
        }
        //check if the msg.sender is a candidate
        require(is_candidate == true, "Account must be a Candidate");
        //check if the msg.sender has already deposited some soul
        require(deposit[msg.sender] == 0, "Candidates has already done deposit"); 
        voting_condition.candidates_deposit_soul++;
        deposit[msg.sender] = msg.value; //msg.value > 0, checked in app.js
        emit Deposited(msg.sender);
    }

    function cast_envelope(uint _sigil, address _candidate, uint _soul) canVote public {
        bool is_candidate = false;
        for (uint i =0; i < candidates.length; i++){
            if (candidates[i] == _candidate)
                is_candidate = true;
        }
        //check if the parameter _candidate is in the candidates list
        require(is_candidate == true, "Account voted must be a Candidate");
        //check if the soul is greater than 0
        require(_soul > 0, "Soul < 0");
        bytes32 _envelope = keccak256(abi.encode(_sigil,_candidate,_soul)); //compute the hash
        if(envelopes[msg.sender] == 0x0)
            voting_condition.envelopes_casted++; //sign as casted
        envelopes[msg.sender] = _envelope; //cast the envelope
        envelopes_opened[msg.sender] = false; //sign as not opened
        emit EnvelopeCast(msg.sender);
    }
    
    function open_envelope(uint _sigil, address _candidate_symbol) canOpen public payable {
        //check that the msg.sender has already casted an envelope
        require(envelopes[msg.sender] != 0x0, "The sender has not casted any votes");
	    //check that the envelope has not been already opened
        require(envelopes_opened[msg.sender] == false,"The envelope has been already opened");
        bool is_candidate = false;
        for (uint i =0; i < candidates.length; i++){
            if (candidates[i] == _candidate_symbol)
                is_candidate = true;
        }
        //check that the _candidate_symbol is a candidate's address
        require(is_candidate == true, "Account voted must be a Candidate");
        bytes32 _casted_envelope = envelopes[msg.sender]; //takes the envelope casted by the msg.sender
        bytes32 _sent_envelope = 0x0;
        uint _soul = msg.value; //take the soul sent by the voter
	    _sent_envelope = keccak256(abi.encode(_sigil,_candidate_symbol,_soul)); //compute the hash
        //check that the envelope is equal to the one casted
        require(_casted_envelope == _sent_envelope,"Sent envelope does not correspond to the one casted");
	    //mark the envelope as opened
        envelopes_opened[msg.sender] = true;
        voting_condition.envelopes_opened++; //increase the number of envelopes opened
        souls[msg.sender].soul = _soul; //set the voter’s soul sent
        souls[msg.sender].candidate_symbol =_candidate_symbol; //set the voter’s vote
        voters.push(payable(msg.sender)); //insert the voter into the voters list
	 
        votes[_candidate_symbol].souls = votes[_candidate_symbol].souls + _soul; //increase the souls associated to the candidate_symbol
        votes[_candidate_symbol].number++; //increase the number of votes associated to the candidate_symbol
        
	    //emit the envelope opened event
        emit EnvelopeOpen(msg.sender,_soul, _candidate_symbol);
    }

    //calculate the winner and return it
    function getWinner() canCheckOutcome private returns(address payable){
        uint max_souls = 0; // ok because all the soul are greater than 0
        for(uint i=0; i < candidates.length; i++){
            address payable cand = candidates[i]; 
            // if the candidate has the souls greater than the max, set the candidate as winner
            // and update the max
            if (votes[cand].souls > max_souls){
                max_souls = votes[cand].souls;
                winner = cand;
            }
            // if the souls are equal to the max (winner one), check if the number of votes are greater or not
            else if (votes[cand].souls == max_souls && max_souls != 0){
                if (votes[cand].number > votes[winner].number)
                    winner = cand;
                // if also the number of votes are equal to the winner ones there are a tie case
                // set the winner as the escrow
                else if (votes[cand].number == votes[winner].number){
                    winner = escrow;
                }   
            } 
        }
        return winner;
    } 

    // split the elector into two parts: who voted for the winner and the others
    function splitElectors(address payable winner_par) canCheckOutcome private {
        address payable voter;
        for (uint i=0; i < voters.length; i++) {
            voter = voters[i];
            // if the vote of the elector voter is for the winner
             if (souls[voter].candidate_symbol == winner_par){
                results.winners.push(payable(voter)); //insert the elector into the winner list
             } else {
                results.losers.push(payable(voter));
             }
        }
    }

    
    function mayor_or_sayonara() canCheckOutcome public {
        address payable voter;
        uint total_soul = 0;
        winner = getWinner(); //calculate the winner and get it
        voting_condition.winnerChecked = true; //set as already checked
        //if there is a tie case
        if (winner == escrow){
            for (uint i=0; i < candidates.length; i++) {
                address candidate = candidates[i];
                //take all the voter's souls and the candidate's deposit
                total_soul = total_soul + votes[candidate].souls + deposit[candidate];
                votes[candidate].souls = 0;
                deposit[candidate]=0;
            }
            //transfer the total soul to the escrow account
            escrow.transfer(total_soul); 
            total_soul = 0;
            emit Tie(escrow);

        //if there isn't a tie case
        } else {
            //split the electors 
            splitElectors(winner); 
            //take the soul that are into the winner's deposit
            uint deposit_winner = deposit[winner]; 
            //calculate how many souls an elector will receive
            uint single_win_el = deposit_winner / results.winners.length; 
            //empty the winner's deposit
            deposit[winner] = 0; 

            for (uint i=0; i < results.winners.length; i++) { 
                voter = results.winners[i];
                //increase the total souls that the winner will receive taking the elector's souls
                total_soul = total_soul + souls[voter].soul;
                souls[voter].soul = 0; //empty the elector's souls
                //transfer the part of the winner's deposit
                voter.transfer(single_win_el);
            }
            for (uint i=0; i < results.losers.length; i++){
                voter = results.losers[i];
                uint soul_voter = souls[voter].soul;
                souls[voter].soul = 0;
                //transfer the souls again to the elector that have lost
                voter.transfer(soul_voter);
            }
            for (uint i=0; i < candidates.length; i++) { //winner's deposit already empty
                //sum to the total soul the others candidates' deposit
                total_soul = total_soul + deposit[candidates[i]];
                deposit[candidates[i]] = 0;
            }
            //transfer the total souls to the winner
            winner.transfer(total_soul); 
            total_soul = 0;
            
            emit NewMayor(winner);
        }
    }
}
