methods {
    function clock() external returns (uint48);
    function pastBalanceOf(address,uint256) external returns (uint256);
    function pastDelegates(address,uint256) external returns (address);
    function getBalancesLength(address account) external returns (uint256) envfree;
    function getDelegateessLength(address account) external returns (uint256) envfree;
    function getVotingPowersLength(address account) external returns (uint256) envfree;
    function balances(address account, uint256 index) external returns (EpochBasedVoteToken.AmountSnap memory) envfree;
    function delegatees(address account, uint256 index) external returns (EpochBasedVoteToken.AccountSnap memory) envfree;
    function votingPowers(address account, uint256 index) external returns (EpochBasedVoteToken.AmountSnap memory) envfree;
    function totalSupplies(uint256 index) external returns (EpochBasedVoteToken.AmountSnap memory) envfree;
    function unsafeAccessVotingPowers(address account, uint256 index) external returns (EpochBasedVoteToken.AmountSnap memory) envfree;
    function unsafeAccessDelegatees(address account, uint256 index) external returns (EpochBasedVoteToken.AccountSnap memory) envfree;

    /// ERC712Extended
    function ERC712Extended._getDomainSeparator() internal returns (bytes32) => NONDET;

    function _.lastDeploy() external => PER_CALLEE_CONSTANT;
}

definition MAX_TIMESTAMP() returns uint256 = 17514144000; // In the year 2525...

ghost uint256 counter {init_state axiom counter == 0;}
ghost delegateesList(uint256) returns address;

function delegateeHookCVL(address account) {
    require delegateesList(counter) == account;
    counter = require_uint256(counter + 1);
}

invariant EpochsAreNotInTheFuture_extended(env e, uint16 currentEpoch)
    true;

invariant BootstrapEpochIsInThePast(env e)
    true; 
