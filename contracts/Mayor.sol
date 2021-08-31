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
        require(voting_condition.winnerChecked == false);
        _;
    }
    
    address payable[] public candidates;
    address payable public escrow;
    mapping(address => bytes32) public envelopes;
    mapping(address => uint) public deposit;
    mapping(address => bool) public envelopes_opened;
    Conditions public voting_condition;
    mapping(address => Vote) public votes;
    bool canCall = true;
    mapping(address => Refund) public souls;
    address payable[] public voters;
    address payable winner;
    ElectorsResult results;

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
            deposit[candidates[i]] = 0;
        }
    }

    function getEscrow() public view returns(address payable) {
        return escrow;
    }

    function getCandidates() public view returns(address payable[] memory){
        return candidates;
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

    function canSeeWinner() public view returns(bool){
        bool boolean = (voting_condition.envelopes_opened == voting_condition.quorum);
        return boolean;
    }

    function deposit_soul() public payable {
        bool is_candidate = false;
        for (uint i =0; i < candidates.length; i++){
            if (candidates[i] == msg.sender)
                is_candidate = true;
        }
        require(is_candidate == true, "Account must be a Candidate");
        require(deposit[msg.sender] == 0, "Candidates has already done deposit");
        voting_condition.candidates_deposit_soul++;
        deposit[msg.sender] = msg.value;
    }

    function cast_envelope(uint _sigil, address _candidate, uint _soul) canVote public {
        require(_soul > 0, "Soul < 0");
        bytes32 _envelope = keccak256(abi.encode(_sigil,_candidate,_soul));
        if(envelopes[msg.sender] == 0x0)
            voting_condition.envelopes_casted++;
        envelopes[msg.sender] = _envelope;
        envelopes_opened[msg.sender] = false;
        emit EnvelopeCast(msg.sender);
    }
    
    function open_envelope(uint _sigil, address _candidate_symbol) canOpen public payable {
        require(envelopes[msg.sender] != 0x0, "The sender has not casted any votes");
	    //check that the envelope has not been already opened
        require(envelopes_opened[msg.sender] == false,"The envelope has been already opened");
        
        bytes32 _casted_envelope = envelopes[msg.sender];
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
	 
        votes[_candidate_symbol].souls = votes[_candidate_symbol].souls + _soul;
        votes[_candidate_symbol].number++;
        
	    //emit the envelope opened event
        emit EnvelopeOpen(msg.sender,_soul, _candidate_symbol);
    }

    function getWinner() canCheckOutcome private returns(address payable){
        uint max_souls = 0;
        for(uint i=0; i < candidates.length; i++){
            if (votes[candidates[i]].souls == max_souls && max_souls != 0){
                if (votes[candidates[i]].number > votes[winner].number)
                    winner = candidates[i];
                else if (votes[candidates[i]].number == votes[winner].number){
                    winner = escrow;
                    return escrow; //tie case
                }   
            } 
            if (votes[candidates[i]].souls > max_souls){
                max_souls = votes[candidates[i]].souls;
                winner = candidates[i];
            }
            
        }
        return winner;
    } 

    function seeWinner() public view returns(address payable){
        return winner;
    }

    function splitElectors(address payable winner_par) canCheckOutcome private {
        address payable voter;
        for (uint i=0; i < voters.length; i++) {
            voter = voters[i];
             if (souls[voter].candidate_symbol == winner_par){
                results.winners.push(payable(voter));
             } else {
                 results.losers.push(payable(voter));
             }
        }
    }

    function mayor_or_sayonara() canCheckOutcome public {
        require(voting_condition.winnerChecked == false);
        address payable voter;
        uint total_soul = 0;
        winner = getWinner();
        if (winner == escrow){
            for (uint i=0; i < candidates.length; i++) {
                address candidate = candidates[i];
                total_soul = total_soul + votes[candidate].souls + deposit[candidate];
                votes[candidate].souls = 0;
                deposit[candidate]=0;
            }
            escrow.transfer(total_soul); 
            total_soul = 0;
            voting_condition.winnerChecked = true;
            emit Tie(escrow);
        } else {
            splitElectors(winner);
            uint deposit_winner = deposit[winner];
            uint single_win_el = deposit_winner / results.winners.length;
            deposit[winner] = 0;
            for (uint i=0; i < results.winners.length; i++) { 
                voter = results.winners[i];
                total_soul = total_soul + souls[voter].soul;
                souls[voter].soul = 0;
                voter.transfer(single_win_el);
            }
            for (uint i=0; i < results.losers.length; i++){
                voter = results.losers[i];
                uint soul_voter = souls[voter].soul;
                souls[voter].soul = 0;
                voter.transfer(soul_voter);
            }
            for (uint i=0; i < candidates.length; i++) {
                total_soul = total_soul + deposit[candidates[i]];
                deposit[candidates[i]] = 0;
            }
            winner.transfer(total_soul); 
            total_soul = 0;
            voting_condition.winnerChecked = true;
            emit NewMayor(winner);
        }
    }
}
