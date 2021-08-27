pragma solidity ^0.4.24;

contract Mayor {
    
    struct Refund {
        uint soul;
        bool doblon;
    }

    struct Conditions {
        uint32 quorum;
        uint32 envelopes_casted;
        uint32 envelopes_opened;
    }

    event NewMayor(address _candidate); //cambiare, non c'è piu un solo candidato
    event Sayonara(address _escrow); //in caso di non vittoria
    event Tie(address _candidate, address _escrow); //da cambiare
    event EnvelopeCast(address _voter);
    event EnvelopeOpen(address _voter, uint _soul, bool _doblon);
    
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
    
    address payable public candidate;
    address payable public escrow;
    mapping(address => bytes32) public envelopes;
    mapping(address => bool) public envelopes_opened;
    Conditions public voting_condition;
    uint public naySoul;
    uint public yaySoul;
    bool canCall = true;
    mapping(address => Refund) public souls;
    address payable[] public voters;

    constructor(address payable _candidate, address payable _escrow, uint32 _quorum) {
        candidate = _candidate;
        escrow = _escrow;
        voting_condition = Conditions({quorum: _quorum, envelopes_casted: 0,
        envelopes_opened: 0});
    }

    function cast_envelope(bytes32 _envelope) canVote public {
        if(envelopes[msg.sender] == 0x0)
            voting_condition.envelopes_casted++;
        envelopes[msg.sender] = _envelope;
        emit EnvelopeCast(msg.sender);
    }
    
    function open_envelope(uint _sigil, bool _doblon) canOpen public payable {

        require(envelopes[msg.sender] != 0x0, "The sender has not casted any votes");
	    //check that the envelope has not been already opened
        require(envelopes_opened[msg.sender] == false,"The envelope has been already opened");
        
        bytes32 _casted_envelope = envelopes[msg.sender];
        bytes32 _sent_envelope = 0x0;
         uint _soul = msg.value; //take the soul sent by the voter
	    _sent_envelope = compute_envelope(_sigil,_doblon,_soul); //compute the hash
        //check that the envelope is equal to the one casted
        require(_casted_envelope == _sent_envelope,"Sent envelope does not correspond to the one casted");
	    //mark the envelope as opened
        envelopes_opened[msg.sender] = true;
        voting_condition.envelopes_opened++; //increase the number of envelopes opened
        souls[msg.sender].soul = _soul; //set the voter’s soul sent
        souls[msg.sender].doblon =_doblon; //set the voter’s vote
        voters.push(payable(msg.sender)); //insert the voter into the voters list
	    //increase the yaysoul or naysoul
        if (_doblon) 
            yaySoul = yaySoul + _soul; 
        else 
            naySoul = naySoul + _soul;
	  //emit the envelope opened event
        emit EnvelopeOpen(msg.sender,_soul, _doblon);
    }

    function compute_envelope(uint _sigil, bool _doblon, uint _soul) public pure returns(bytes32) {
            require(_soul > 0, "Soul has to be greater than zero"); //soul must be > 0
            return keccak256(abi.encode(_sigil, _doblon, _soul));
    }

    function mayor_or_sayonara() canCheckOutcome public {
        address payable voter;
        uint soul_voter = 0;
        uint soul_winner = 0;
        require(canCall == true, "Cannot call the function multiple times"); 
        canCall = false;
        if (yaySoul > naySoul) { //yay wins
            for (uint i=0; i < voters.length; i++) { 
                voter = voters[i]; //take the voter
                if (souls[voter].doblon == false) { //if the voter’s vote didn’t win
                    soul_voter = souls[voter].soul;
                    souls[voter].soul = 0;
                    voter.transfer(soul_voter); //this is a security issue
                }
            }
            soul_winner = yaySoul;
            yaySoul = 0; naySoul=0;
            candidate.transfer(soul_winner); //this is a security issue
            emit NewMayor(candidate);

        } else if (naySoul > yaySoul) { // nay wins
            for (uint i=0; i < voters.length; i++){
                voter = voters[i];
                if (souls[voter].doblon == true){
                    soul_voter = souls[voter].soul;
                    souls[voter].soul = 0;
                    voter.transfer(soul_voter); //this is a security issue
                }
            }
            soul_winner = naySoul;
            yaySoul = 0; naySoul=0;
            escrow.transfer(soul_winner); //this is a security issue
            emit Sayonara(escrow);

        } else { //tie case: in this case all voters will be refunded
            for (uint i=0; i < voters.length; i++){
                voter = voters[i];
                soul_voter = souls[voter].soul;
                souls[voter].soul = 0;
                voter.transfer(soul_voter); //this is a security issue
            }
            yaySoul = 0; naySoul=0;
            emit Tie(candidate, escrow);
   	    }
    }
}
