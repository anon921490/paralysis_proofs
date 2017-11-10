pragma solidity ^0.4.0;

contract ParalysisProof {
    uint256 required_sigs;
    uint256 delta;
    uint256 mu;
    address[] keyholders;
    // Paralysis claims and confirmed paralyzed users
    struct ParalysisClaim {
        uint256 expiry;
        bool responded;
    }
    mapping(address=>ParalysisClaim) paralysis_claims;
    mapping(address=>bool) paralyzed;
    event NewAccusation(address accused, uint256 respond_by);    
    // Spend proposals and their signatures / approvals
    struct SpendProposal {
        address to;
        uint256 amount;
        bool filled;
    }
    SpendProposal[] proposals;
    mapping (uint => mapping (address => bool)) proposal_sigs;
    
    function ParalysisProof(uint256 _mu, uint256 _delta, address[] _keyholders) public {
        mu = _mu;
        delta = _delta;
        keyholders = _keyholders;
    }
    
    function() payable {} // allow money in
    
    function is_keyholder(address holder) internal constant returns(bool) {
        for (uint256 i = 0; i < keyholders.length; i++) {
            if (keyholders[i] == holder)
                return !paralyzed[holder];
        }
        return false;
    }
    
    function prune_paralyzed_keyholders() internal {
        // if any keyholders are paralyzed, remove them
        uint256 nparalyzed = 0;
        for (uint256 i = 0; i < keyholders.length; i++) {
            if (!paralyzed[keyholders[i]]) {
                uint256 expiry = paralysis_claims[keyholders[i]].expiry;
                if (expiry < now && expiry > 0) {
                    if (!paralysis_claims[keyholders[i]].responded) {
                        // active claim, unresponded.  set paralyzed
                        paralyzed[keyholders[i]] = true;
                        nparalyzed++;                        
                    }
                }
            }
        }
        required_sigs = ((mu) * (keyholders.length - nparalyzed)) / 1000;
    }
    
    function createSpendProposal(address to, uint256 amount) public {
        // Get rid of any paralyzed keyholders
        prune_paralyzed_keyholders();

        require(is_keyholder(msg.sender));
        uint256 proposal_id = proposals.length;
        proposals[proposal_id] = SpendProposal(to, amount, false);
        proposal_sigs[proposal_id][msg.sender] = true; 
    }
    
    function spend(uint256 proposal_id) public {
        // Get rid of any paralyzed keyholders
        prune_paralyzed_keyholders();
        
        require(is_keyholder(msg.sender));
        require(proposal_id < proposals.length);
        
        // add sender's signature to approval
        proposal_sigs[proposal_id][msg.sender] = true; 

        // if enough proposers approved, send money
        uint num_signatures = 0;
        for (uint256 i = 0; i < keyholders.length; i++) {
            if (!paralyzed[keyholders[i]]) {
                if (proposal_sigs[proposal_id][keyholders[i]]) {
                    num_signatures++;
                }
            }
        }
        
        if ((num_signatures) >= required_sigs) {
            if (!proposals[proposal_id].filled) {
                proposals[proposal_id].filled = true;
                proposals[proposal_id].to.transfer(proposals[proposal_id].amount);
            }
        }
    }
    
    function remove(address accused) public {
        // Get rid of any paralyzed keyholders (prevent paralyzed requester)
        prune_paralyzed_keyholders();
        // both requester and accused must be keyholders
        require(is_keyholder(msg.sender));
        require(is_keyholder(accused));
        
        // There shouldn't be any outstanding claims against accused
        require(!(paralysis_claims[accused].expiry > now));
        
        // Create and insert an Paralysis Claim
        paralysis_claims[accused] = ParalysisClaim(now+delta, false);
        NewAccusation(accused, now + delta); // Notify the accused
    }
    
    function respond() public {
        require(paralysis_claims[msg.sender].expiry > now);
        paralysis_claims[msg.sender].responded = true;
    }
    
}
