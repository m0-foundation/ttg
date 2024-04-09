methods {
    function clock() external returns (uint48);
    function _.getPastVotes(address account, uint256 timepoint) external with (env e) => pastVotes(e, account, timepoint) expect uint256;
    function _.pastTotalSupply(uint256 timepoint) external with (env e) => pastTotalSupply(e, timepoint) expect uint256;
    function PowerToken._getBootstrapBalance(address account, uint16 epoch) internal returns (uint240) => bootstrapBalanceMock(account, epoch);
    
    /*
    Ignoring the 'markParticipation' action relies on the invariant that the past votes and total supply are immutable.
    We also have to assume they shouldn't revert unexpectedly.
    */
    function PowerToken.markParticipation(address delegatee_) external with (env e) => markParticipationForAt(delegatee_, e.block.timestamp);
}

persistent ghost mapping(address => mapping(uint256 => bool)) _participatedAt;

function markParticipationForAt(address account, uint256 timestamp) {
    _participatedAt[account][timestamp] = true;
}

definition max16(uint16 a, uint16 b) returns uint16 = a >=b ? a : b;

/*
A CVL mock for the vote token (power token) of the standard governor.
We over-approximate the past votes and total supply by static arbitrary functions.
The values are justifiably static if we rely on the invariants that the past votes and total supply are immutable.
*/
persistent ghost uint16 latestPastEpoch;

persistent ghost bootstrapBalanceMock(address,uint16) returns uint240;

function pastVotes(env e, address account, uint256 timepoint) returns uint256 {
    /// We make sure that the access is always in past epochs by verifying the rule `pastEpochIsNeverCurrentEpoch`
    latestPastEpoch = max16(assert_uint16(timepoint), latestPastEpoch); 
    ///assert assert_uint256(clock(e)) > timepoint;
    return _pastVotes(account, timepoint);
}

function pastTotalSupply(env e, uint256 timepoint) returns uint256 {
    /// We make sure that the access is always in past epochs by verifying the rule `pastEpochIsNeverCurrentEpoch`
    latestPastEpoch = max16(assert_uint16(timepoint), latestPastEpoch); 
    ///assert assert_uint256(clock(e)) > timepoint;
    return _pastTotalSupply(timepoint);
}

/// The past values are immutable, so the 'persistent' attribute is justified.
persistent ghost _pastTotalSupply(uint256) returns uint256;
persistent ghost _pastVotes(address, uint256) returns uint256;
