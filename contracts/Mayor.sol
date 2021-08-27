pragma solidity ^0.8.7;

contract Mayor {
    
    struct Refund {
        uint soul;
        address candidate_symbol;
    }

    struct Vote {
        uint souls;
        uint number;
    }

    struct Conditions {
        uint32 quorum;
        uint32 envelopes_casted;
        uint32 envelopes_opened;
    }

    event NewMayor(address _candidate); 
    event Sayonara(address _escrow);
    event Tie(address _escrow);
    event EnvelopeCast(address _voter);
    event EnvelopeOpen(address _voter, uint _soul, address candidate_symbol);
    
    modifier canVote() {
        require(voting_condition.envelopes_casted < voting_condition.quorum, "Cannot vote now, voting quorum has been reached");
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
    mapping(address => bool) public envelopes_opened;
    Conditions public voting_condition;
    mapping(address => Vote) public votes;
    bool canCall = true;
    mapping(address => Refund) public souls;
    address payable[] public voters;
    uint32 value = 32;

    constructor(address payable[] memory _candidates, address payable _escrow, uint32 _quorum) {
        candidates = _candidates;
        escrow = _escrow;
        voting_condition = Conditions({quorum: _quorum, envelopes_casted: 0,
        envelopes_opened: 0});
    }

    function getEscrow() public view returns(address payable) {
        return escrow;
    }

    function getCandidates() public view returns(address payable[] memory){
        return candidates;
    }

    function cast_envelope(bytes32 _envelope) canVote public {
        if(envelopes[msg.sender] == 0x0)
            voting_condition.envelopes_casted++;
        envelopes[msg.sender] = _envelope;
        emit EnvelopeCast(msg.sender);
    }
    
    function open_envelope(uint _sigil, address _candidate_symbol) canOpen public payable {
        require(envelopes[msg.sender] != 0x0, "The sender has not casted any votes");
	    //check that the envelope has not been already opened
        require(envelopes_opened[msg.sender] == false,"The envelope has been already opened");
        
        bytes32 _casted_envelope = envelopes[msg.sender];
        bytes32 _sent_envelope = 0x0;
        uint _soul = msg.value; //take the soul sent by the voter
	    _sent_envelope = compute_envelope(_sigil,_candidate_symbol,_soul); //compute the hash
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

    function compute_envelope(uint _sigil, address _candidate, uint _soul) public pure returns(bytes32) {
            require(_soul > 0, "Soul has to be greater than zero"); //soul must be > 0
            return keccak256(abi.encode(_sigil, _candidate, _soul));
    }

    function getWinner() canCheckOutcome private view returns(address payable){
        uint max_souls = 0;
        address payable winner;
        for(uint i=0; i < candidates.length; i++){
            if (votes[candidates[i]].souls > max_souls){
                max_souls = votes[candidates[i]].souls;
                winner = candidates[i];
            }
            if (votes[candidates[i]].souls == max_souls && max_souls != 0){
                if (votes[candidates[i]].number > votes[winner].number)
                    winner = candidates[i];
                else if (votes[candidates[i]].number == votes[winner].number)
                    return escrow; //tie case
            } 
        }
        return winner;
    } 

    function mayor_or_sayonara() canCheckOutcome public {
        address payable voter;
        uint total_soul = 0;
        address payable winner = getWinner();
        if (winner == escrow){
            for (uint i=0; i < candidates.length; i++) {
                address candidate = candidates[i];
                total_soul = total_soul + votes[candidate].souls;
                votes[candidate].souls = 0;
            }
            escrow.transfer(total_soul); 
            total_soul = 0;
            emit Tie(escrow);
        } else {
            for (uint i=0; i < voters.length; i++) {
                voter = voters[i];
                if (souls[voter].candidate_symbol != winner){
                    uint soul_voter = souls[voter].soul;
                    souls[voter].soul = 0;
                    voter.transfer(soul_voter);
                } else {
                    total_soul = total_soul + souls[voter].soul;
                }
            }
            winner.transfer(total_soul); 
            total_soul = 0;
            emit NewMayor(winner);
        }
    }
}
