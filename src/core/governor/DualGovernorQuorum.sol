// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/Checkpoints.sol";

import "src/interfaces/ISPOGGovernor.sol";

/// @title Governor contract to track quorum for both value and vote tokens
/// @notice Governor adjusted to track double quorums for SPOG proposals
/// @dev Based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/extensions/GovernorVotesQuorumFraction.sol
abstract contract DualGovernorQuorum is ISPOGGovernor {
    using Checkpoints for Checkpoints.Trace224;

    /// @notice The vote token of SPOG governance
    IVOTE public immutable override vote;

    /// @notice The value token of SPOG governance
    IVALUE public immutable override value;

    /// @custom:oz-retyped-from Checkpoints.History
    Checkpoints.Trace224 private _valueQuorumNumeratorHistory;
    Checkpoints.Trace224 private _voteQuorumNumeratorHistory;

    /// @notice Constructs a new governor instance with Double quorum logic
    /// @param name_ Governor name
    /// @param vote_ Vote token address
    /// @param value_ Value token address
    /// @param voteQuorumNumerator_ Vote quorum numerator
    /// @param valueQuorumNumerator_ Value quorum numerator
    constructor(
        string memory name_,
        address vote_,
        address value_,
        uint256 voteQuorumNumerator_,
        uint256 valueQuorumNumerator_
    ) Governor(name_) {
        // Sanity checks
        if (vote_ == address(0)) revert ZeroVoteAddress();
        if (value_ == address(0)) revert ZeroValueAddress();
        if (voteQuorumNumerator_ == 0) revert ZeroVoteQuorumNumerator();
        if (valueQuorumNumerator_ == 0) revert ZeroValueQuorumNumerator();

        // Set tokens and check that they are properly linked together
        vote = IVOTE(vote_);
        value = IVALUE(value_);
        if (vote.value() != value) revert VoteValueMistmatch();

        // Set initial vote and value quorums
        _updateVoteQuorumNumerator(voteQuorumNumerator_);
        _updateValueQuorumNumerator(valueQuorumNumerator_);
    }

    /// @notice Returns the latest vote quorum numerator
    function voteQuorumNumerator() public view virtual override returns (uint256) {
        return _voteQuorumNumeratorHistory.latest();
    }

    /// @notice Returns the latest value quorum numerator
    function valueQuorumNumerator() public view virtual override returns (uint256) {
        return _valueQuorumNumeratorHistory.latest();
    }

    /// @notice Returns the vote quorum numerator at the given timepoint
    function voteQuorumNumerator(uint256 timepoint) public view virtual override returns (uint256) {
        // If history is empty, fallback to old storage
        uint256 length = _voteQuorumNumeratorHistory._checkpoints.length;

        // Optimistic search, check the latest checkpoint
        Checkpoints.Checkpoint224 memory latest = _voteQuorumNumeratorHistory._checkpoints[length - 1];
        if (latest._key <= timepoint) {
            return latest._value;
        }

        // Otherwise, do the binary search
        // TODO: `upperLookupRecent` vs `upperLookup`, upgrade to use the latest OZ libs
        return _voteQuorumNumeratorHistory.upperLookup(SafeCast.toUint32(timepoint));
    }

    /// @notice Returns the value quorum numerator at the given timepoint
    function valueQuorumNumerator(uint256 timepoint) public view virtual override returns (uint256) {
        // If history is empty, fallback to old storage
        uint256 length = _valueQuorumNumeratorHistory._checkpoints.length;

        // Optimistic search, check the latest checkpoint
        Checkpoints.Checkpoint224 memory latest = _valueQuorumNumeratorHistory._checkpoints[length - 1];
        if (latest._key <= timepoint) {
            return latest._value;
        }

        // Otherwise, do the binary search
        // TODO: `upperLookupRecent` vs `upperLookup`, upgrade to use the latest OZ libs
        return _valueQuorumNumeratorHistory.upperLookup(SafeCast.toUint32(timepoint));
    }

    /// @notice Returns the quorum denominator
    function quorumDenominator() public view virtual override returns (uint256) {
        return 100;
    }

    /// @notice Returns the vote quorum at the given timepoint
    function voteQuorum(uint256 timepoint) public view virtual override returns (uint256) {
        return (vote.getPastTotalSupply(timepoint) * voteQuorumNumerator(timepoint)) / quorumDenominator();
    }

    /// @notice Returns the value quorum at the given timepoint
    function valueQuorum(uint256 timepoint) public view virtual override returns (uint256) {
        return (value.getPastTotalSupply(timepoint) * valueQuorumNumerator(timepoint)) / quorumDenominator();
    }

    /// @notice Returns the vote quorum at the given timepoint
    /// @dev Added to be compatible with standard OZ Governor interface
    function quorum(uint256 timepoint) public view virtual override returns (uint256) {
        return voteQuorum(timepoint);
    }

    /// @notice Updates the vote quorum numerator
    /// @param newVoteQuorumNumerator New vote quorum numerator
    function updateVoteQuorumNumerator(uint256 newVoteQuorumNumerator) external virtual override onlyGovernance {
        _updateVoteQuorumNumerator(newVoteQuorumNumerator);
    }

    /// @dev Updates the vote quorum numerator
    function _updateVoteQuorumNumerator(uint256 newVoteQuorumNumerator) internal virtual {
        if (newVoteQuorumNumerator > quorumDenominator()) revert InvalidVoteQuorumNumerator();

        uint256 oldVoteQuorumNumerator = voteQuorumNumerator();

        // Set new quorum for future proposals
        _voteQuorumNumeratorHistory.push(SafeCast.toUint32(block.number), SafeCast.toUint224(newVoteQuorumNumerator));

        emit VoteQuorumNumeratorUpdated(oldVoteQuorumNumerator, newVoteQuorumNumerator);
    }

    /// @notice Updates the value quorum numerator
    /// @param newValueQuorumNumerator New value quorum numerator
    function updateValueQuorumNumerator(uint256 newValueQuorumNumerator) external virtual override onlyGovernance {
        _updateValueQuorumNumerator(newValueQuorumNumerator);
    }

    /// @dev Updates the value quorum numerator
    function _updateValueQuorumNumerator(uint256 newValueQuorumNumerator) internal virtual {
        if (newValueQuorumNumerator > quorumDenominator()) revert InvalidValueQuorumNumerator();

        uint256 oldValueQuorumNumerator = voteQuorumNumerator();

        // Set new quorum for future proposals
        _valueQuorumNumeratorHistory.push(SafeCast.toUint32(block.number), SafeCast.toUint224(newValueQuorumNumerator));

        emit ValueQuorumNumeratorUpdated(oldValueQuorumNumerator, newValueQuorumNumerator);
    }

    /// @dev Returns min between vote votes for the account at the given timepoint and current votes
    function _getVoteVotes(address account, uint256 timepoint, bytes memory /*params*/ )
        internal
        view
        virtual
        returns (uint256)
    {
        return _min(vote.getPastVotes(account, timepoint), vote.getVotes(account));
    }

    /// @dev Returns value votes for the account at the given timepoint
    function _getValueVotes(address account, uint256 timepoint, bytes memory /*params*/ )
        internal
        view
        virtual
        returns (uint256)
    {
        return value.getPastVotes(account, timepoint);
    }

    /// @dev Returns vote votes for the account at the given timepoint
    /// @dev Added to be compatible with standard OZ Governor interface
    function _getVotes(address account, uint256 timepoint, bytes memory /*params*/ )
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return vote.getPastVotes(account, timepoint);
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
