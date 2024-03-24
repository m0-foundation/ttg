import "../ERC20Helper.spec";
using PowerToken as voteToken;

methods {
    function execute(address[], uint256[], bytes[], bytes32) external returns (uint256);
    function propose(address[], uint256[], bytes[], string) external returns (uint256);
    function state(uint256) external returns (IGovernor.ProposalState);
    function clock() external returns (uint48);

    function cashToken() external returns (address) envfree;
    function proposalFee() external returns (uint256) envfree;
    function getProposal(uint256) external returns (uint48,uint48,IGovernor.ProposalState,uint256,uint256,address);
    function hasVoted(uint256 proposalId, address voter) external returns (bool) envfree;

    function vault() external returns (address) envfree;
    function numberOfProposalsAt(uint256 epoch) external returns (uint256) envfree;
    function numberOfProposalsVotedOnAt(address voter, uint256 epoch) external returns (uint256) envfree;

    // ERC20 summaries:
    function ERC20Helper.transfer(address token, address to, uint256 amount) internal returns (bool) with (env e) => transferCVL(token, e.msg.sender, to, amount);
    function ERC20Helper.transferFrom(address token, address from, address to, uint256 amount) internal returns (bool) with (env e) => transferFromCVL(token, e.msg.sender, from, to, amount);
    
    /// Misc.
    function _.lastDeploy() external => PER_CALLEE_CONSTANT;
    function _.addToList(bytes32 list, address account) external => NONDET;
    function _.removeFromList(bytes32 list, address account) external => NONDET;
    function _.setKey(bytes32 key, bytes32 value) external => NONDET;

    /// ERC712Extended
    function ERC712Extended._getDomainSeparator() internal returns (bytes32) => NONDET;
    function ERC712Extended._getDigest(bytes32) internal returns (bytes32) => NONDET;

    /// Math munging
    function math.mulDivDown(uint256 x, uint256 y, uint256 z) internal returns (uint256) => mulDivDownCVL(x,y,z);

    /// IZeroToken
    /// We check that minting is account-independent in the ZeroToken spec.
    function _.mint(address,uint256) external => NONDET;
    
    // In entry for isValidSignature(bytes32, bytes), the 2nd argument is a reference type with non-storage location specifier memory, which are not part of external (contract or library) method signatures
    function SignatureChecker.isValidERC1271Signature(address signer,bytes32,bytes memory) internal returns (bool) => ValidERC1271CVL(signer);
}

definition MAX_TIMESTAMP() returns uint256 = 17514144000; // In the year 2525...
definition ValidTimeStamp(env e) returns bool = e.block.timestamp <= MAX_TIMESTAMP() && e.block.timestamp > 0;
definition MAX_VOTES() returns uint256 = max_uint128;

definition isRegistrarMethod(method f) returns bool = 
    f.selector == sig:addToList(bytes32,address).selector || 
    f.selector == sig:removeFromAndAddToList(bytes32,address,address).selector ||
    f.selector == sig:removeFromList(bytes32,address).selector ||
    f.selector == sig:setKey(bytes32,bytes32).selector;

definition isExecuteMethod(method f) returns bool = 
    f.selector == sig:execute(address[],uint256[],bytes[],bytes32).selector;
    
/// IGovernor states:
definition PENDING() returns IGovernor.ProposalState = IGovernor.ProposalState.Pending;
definition ACTIVE() returns IGovernor.ProposalState = IGovernor.ProposalState.Active;
definition CANCELED() returns IGovernor.ProposalState = IGovernor.ProposalState.Canceled;
definition DEFEATED() returns IGovernor.ProposalState = IGovernor.ProposalState.Defeated;
definition SUCCEEDED() returns IGovernor.ProposalState = IGovernor.ProposalState.Succeeded;
definition QUEUED() returns IGovernor.ProposalState = IGovernor.ProposalState.Queued;
definition EXPIRED() returns IGovernor.ProposalState = IGovernor.ProposalState.Expired;
definition EXECUTED() returns IGovernor.ProposalState = IGovernor.ProposalState.Executed;

function ValidERC1271CVL(address signer) returns bool {
    /// The signer is the callee for the staticcall, hence it returns zero.
    if(signer == 0) return false;
    bool success;
    return success;
}

function getProposalVoteStart(env e, uint256 ID) returns uint16 {
    uint48 voteStart;
    voteStart,_,_,_,_,_ = getProposal(e, ID);
    return assert_uint16(voteStart);
}

function getProposalNay(env e, uint256 ID) returns uint256 {
    uint256 nays;
    _,_,_,nays,_,_ = getProposal(e, ID);
    return nays;
}

function getProposalYea(env e, uint256 ID) returns uint256 {
    uint256 yeas;
    _,_,_,_,yeas,_ = getProposal(e, ID);
    return yeas;
}

function mulDivDownCVL(uint256 x, uint256 y, uint256 z) returns uint256 {
    uint256 res;
    require z != 0;
    uint256 xy = require_uint256(x * y);
    uint256 fz = require_uint256(res * z);

    require xy >= fz;
    require fz + z > to_mathint(xy);
    return res; 
}

// Start mirror of proposals[].voteStart

persistent ghost mapping(uint256 => uint16) voteStartPerProposal {
    init_state axiom forall uint256 proposalID. voteStartPerProposal[proposalID] == 0;
}

hook Sload uint16 voteStartEpoch _proposals[KEY uint256 ID].voteStart {
    require voteStartPerProposal[ID] == voteStartEpoch;
}

hook Sstore _proposals[KEY uint256 ID].voteStart uint16 voteStartEpoch {
    voteStartPerProposal[ID] = voteStartEpoch;
}

// End mirror of proposals[].voteStart
