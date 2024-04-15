import "../ERC20Helper.spec";

methods {
    function isVotingEpoch(uint16 epoch) external returns (bool) envfree;
    function clock() external returns (uint48);
    function votingDelay() external returns (uint256);
    function pastBalanceOf(address,uint256) external returns (uint256);
    function participationInflation() external returns (uint16) envfree;
    function bootstrapEpoch() external returns (uint16) envfree;
    function ONE() external returns (uint16) envfree;
    function getBalancesLength(address account) external returns (uint256) envfree;
    function getDelegateessLength(address account) external returns (uint256) envfree;
    function getVotingPowersLength(address account) external returns (uint256) envfree;
    function getLastSync(address account, uint16 epoch) external returns (uint16);
    function getParticipationsLength(address account) external returns (uint256) envfree;
    function balances(address account, uint256 index) external returns (EpochBasedVoteToken.AmountSnap memory) envfree;
    function delegatees(address account, uint256 index) external returns (EpochBasedVoteToken.AccountSnap memory) envfree;
    function votingPowers(address account, uint256 index) external returns (EpochBasedVoteToken.AmountSnap memory) envfree;
    function totalSupplies(uint256 index) external returns (EpochBasedVoteToken.AmountSnap memory) envfree;
    function participations(address account, uint256 index) external returns (EpochBasedInflationaryVoteToken.VoidSnap memory) envfree;
    function hasParticipatedAt(address delegatee_, uint256 epoch_) external returns (bool) envfree;
    //function EpochBasedInflationaryVoteToken._getUnrealizedInflation(address,uint16) internal returns (uint240) => NONDET;
    function EpochBasedInflationaryVoteToken._getInflation(uint240 amount) internal returns (uint240) => inflationAbstract(amount);
    function getUnrealizedInflation(address account, uint16 lastEpoch) external returns (uint240);
    function PowerToken._getBootstrapBalance(address account, uint16 epoch) internal returns (uint240) => bootstrapBalanceMock(account, epoch);
    function PowerTokenHarness._delegateeHookCVL(address account) internal => delegateeHookCVL(account);

    // ERC20 summaries:
    function ERC20Helper.transfer(address token, address to, uint256 amount) internal returns (bool) with (env e) => transferCVL(token, e.msg.sender, to, amount);
    function ERC20Helper.transferFrom(address token, address from, address to, uint256 amount) internal returns (bool) with (env e) => transferFromCVL(token, e.msg.sender, from, to, amount);

    /// ERC712Extended
    function ERC712Extended._getDomainSeparator() internal returns (bytes32) => NONDET;
    function ERC712Extended._getDigest(bytes32 internalDigest) internal returns (bytes32) => ERC712Digest(internalDigest);

    function _.lastDeploy() external => PER_CALLEE_CONSTANT;
}

definition MAX_TIMESTAMP() returns uint256 = 17514144000; // In the year 2525...

definition max(mathint a, mathint b) returns mathint = a > b ? a : b;

function PostBootstrap(env e) returns bool {
    return to_mathint(clock(e)) > to_mathint(bootstrapEpoch());
}

ghost uint256 delegateeCounter {init_state axiom delegateeCounter == 0;}
ghost delegateesList(uint256) returns address;

function delegateeHookCVL(address account) {
    require delegateesList(delegateeCounter) == account;
    delegateeCounter = require_uint256(delegateeCounter + 1);
}

persistent ghost ERC712Digest(bytes32) returns bytes32;
persistent ghost bootstrapBalanceMock(address,uint16) returns uint240;

/// Over-approximation for:
/// return uint240((uint256(amount_) * participationInflation) / ONE);
/// participationInflation is immutable and <= ONE() (actually is ONE() / 10) so this is valid.
persistent ghost inflationAbstract(uint240) returns uint240 {
    axiom forall uint240 amount. inflationAbstract(amount) <= amount;
    axiom forall uint240 amount1. forall uint240 amount2.
        amount1 < amount2 => inflationAbstract(amount1) <= inflationAbstract(amount2);
}

ghost mapping(address => mapping(uint256 => uint16)) participationsEpochs {
    init_state axiom forall address user. forall uint256 index. participationsEpochs[user][index] == 0;
}

// Mirroring _participations start //

hook Sload uint16 _startingEpoch _participations[KEY address account][INDEX uint256 i].startingEpoch {
    require participationsEpochs[account][i] == _startingEpoch;
}

hook Sstore _participations[KEY address account][INDEX uint256 i].startingEpoch uint16 _startingEpoch {
    participationsEpochs[account][i] = _startingEpoch;
}

hook Sstore _participations[KEY address account].(offset 0) uint256 length (uint256 length_old) {
    require length_old <= MAX_LENGTH();
}
// Mirroring _participations end //
